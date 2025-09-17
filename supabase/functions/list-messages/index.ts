import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { z } from "https://deno.land/x/zod@v3.16.1/mod.ts"
import { encode } from "https://deno.land/std@0.168.0/encoding/base64.ts"

// Types
interface MessageWithRewrites {
  id: string
  chat_id: string
  author_session: string | null
  role: string
  content: string
  created_at: string
  rewrites?: Array<{
    style: string
    text: string
  }>
}

interface ListMessagesResponse {
  messages: MessageWithRewrites[]
}

// Utilities
async function hashSecret(secret: string): Promise<string> {
  const encoder = new TextEncoder()
  const data = encoder.encode(secret)
  const hashBuffer = await crypto.subtle.digest('SHA-256', data)
  const hashArray = new Uint8Array(hashBuffer)
  return encode(hashArray)
}

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-room-secret',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
  }
}

function extractBearerToken(authHeader: string | null): string | null {
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return null
  }
  return authHeader.substring(7)
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders() })
  }

  if (req.method !== 'GET') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      { 
        status: 405, 
        headers: { ...corsHeaders(), 'Content-Type': 'application/json' }
      }
    )
  }

  try {
    // Parse query parameters
    const url = new URL(req.url)
    const publicCode = url.searchParams.get('publicCode')
    const sinceParam = url.searchParams.get('since')
    
    if (!publicCode) {
      return new Response(
        JSON.stringify({ error: 'Missing publicCode parameter' }),
        { 
          status: 400,
          headers: { ...corsHeaders(), 'Content-Type': 'application/json' }
        }
      )
    }

    // Parse since timestamp if provided
    let since: Date | null = null
    if (sinceParam) {
      try {
        since = new Date(sinceParam)
        if (isNaN(since.getTime())) {
          throw new Error('Invalid date')
        }
      } catch {
        return new Response(
          JSON.stringify({ error: 'Invalid since parameter. Must be ISO 8601 date.' }),
          { 
            status: 400,
            headers: { ...corsHeaders(), 'Content-Type': 'application/json' }
          }
        )
      }
    }

    // Extract and validate secret from custom header or Authorization header
    let secret = req.headers.get('x-room-secret')
    
    if (!secret) {
      // Fallback to Authorization header
      const authHeader = req.headers.get('authorization')
      secret = extractBearerToken(authHeader)
    }
    
    if (!secret) {
      return new Response(
        JSON.stringify({ error: 'Missing room secret in x-room-secret header or authorization header' }),
        { 
          status: 401,
          headers: { ...corsHeaders(), 'Content-Type': 'application/json' }
        }
      )
    }

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('PROJECT_URL')!
    const supabaseServiceKey = Deno.env.get('SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Hash the provided secret and verify room access
    const secretHash = await hashSecret(secret)
    const { data: chat, error: chatError } = await supabase
      .from('chats')
      .select('*')
      .eq('public_code', publicCode)
      .single()

    if (chatError || !chat) {
      return new Response(
        JSON.stringify({ error: 'Room not found' }),
        { 
          status: 404,
          headers: { ...corsHeaders(), 'Content-Type': 'application/json' }
        }
      )
    }

    if (chat.secret_hash !== secretHash) {
      return new Response(
        JSON.stringify({ error: 'Invalid room secret' }),
        { 
          status: 403,
          headers: { ...corsHeaders(), 'Content-Type': 'application/json' }
        }
      )
    }

    // Check if room has expired
    const now = new Date()
    const expiresAt = new Date(chat.ttl_expires_at)
    if (now > expiresAt && !chat.saved) {
      return new Response(
        JSON.stringify({ error: 'Room has expired' }),
        { 
          status: 410,
          headers: { ...corsHeaders(), 'Content-Type': 'application/json' }
        }
      )
    }

    // Build messages query
    let messagesQuery = supabase
      .from('messages')
      .select('*')
      .eq('chat_id', chat.id)
      .order('created_at', { ascending: true })

    // Add since filter if provided
    if (since) {
      messagesQuery = messagesQuery.gt('created_at', since.toISOString())
    }

    // Execute messages query
    const { data: messages, error: messagesError } = await messagesQuery

    if (messagesError) {
      console.error('Failed to fetch messages:', messagesError)
      throw new Error('Failed to fetch messages')
    }

    // Fetch rewrites for all messages
    const messageIds = messages.map(m => m.id)
    let rewrites: any[] = []
    
    if (messageIds.length > 0) {
      const { data: rewritesData, error: rewritesError } = await supabase
        .from('rewrites')
        .select('message_id, style, content')
        .in('message_id', messageIds)

      if (rewritesError) {
        console.error('Failed to fetch rewrites:', rewritesError)
        // Continue without rewrites rather than failing
      } else {
        rewrites = rewritesData || []
      }
    }

    // Group rewrites by message ID
    const rewritesByMessage = rewrites.reduce((acc, rewrite) => {
      if (!acc[rewrite.message_id]) {
        acc[rewrite.message_id] = []
      }
      acc[rewrite.message_id].push({
        style: rewrite.style,
        text: rewrite.content
      })
      return acc
    }, {} as Record<string, Array<{ style: string; text: string }>>)

    // Combine messages with their rewrites
    const messagesWithRewrites: MessageWithRewrites[] = messages.map(message => ({
      id: message.id,
      chat_id: message.chat_id,
      author_session: message.author_session,
      role: message.role,
      content: message.content,
      created_at: message.created_at,
      rewrites: rewritesByMessage[message.id] || undefined
    }))

    // Log successful fetch (no PII)
    await supabase
      .from('moderation_logs')
      .insert({
        public_code: publicCode,
        endpoint: 'list-messages',
        blocked: false,
        categories: { fetched: true },
        created_at: new Date().toISOString()
      })

    const response: ListMessagesResponse = {
      messages: messagesWithRewrites
    }

    return new Response(
      JSON.stringify(response),
      { 
        status: 200,
        headers: { ...corsHeaders(), 'Content-Type': 'application/json' }
      }
    )

  } catch (error) {
    console.error('List messages error:', error)

    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { 
        status: 500,
        headers: { ...corsHeaders(), 'Content-Type': 'application/json' }
      }
    )
  }
})
