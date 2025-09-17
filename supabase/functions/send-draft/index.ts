import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { z } from "https://deno.land/x/zod@v3.16.1/mod.ts"
import { encode } from "https://deno.land/std@0.168.0/encoding/base64.ts"

// Types
const SendDraftSchema = z.object({
  publicCode: z.string().min(1),
  sessionId: z.string().uuid(),
  draft: z.string().min(1).max(2000)
})

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
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  }
}

function extractBearerToken(authHeader: string | null): string | null {
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return null
  }
  return authHeader.substring(7)
}

// Mock content moderation
async function moderateContent(text: string): Promise<{ blocked: boolean; categories: Record<string, boolean> }> {
  const lowerText = text.toLowerCase()
  const categories = {
    violence: lowerText.includes('kill') || lowerText.includes('hurt') || lowerText.includes('attack'),
    hate: lowerText.includes('hate') || lowerText.includes('stupid') || lowerText.includes('idiot'),
    self_harm: lowerText.includes('suicide') || lowerText.includes('kill myself'),
    sexual: false
  }
  
  const blocked = Object.values(categories).some(Boolean)
  return { blocked, categories }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders() })
  }

  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      { status: 405, headers: { ...corsHeaders(), 'Content-Type': 'application/json' } }
    )
  }

  try {
    const body = await req.json()
    const { publicCode, sessionId, draft } = SendDraftSchema.parse(body)

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
        { status: 401, headers: { ...corsHeaders(), 'Content-Type': 'application/json' } }
      )
    }

    const supabaseUrl = Deno.env.get('PROJECT_URL')!
    const supabaseServiceKey = Deno.env.get('SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    const secretHash = await hashSecret(secret)
    const { data: chat, error: chatError } = await supabase
      .from('chats')
      .select('*')
      .eq('public_code', publicCode)
      .single()

    if (chatError || !chat || chat.secret_hash !== secretHash) {
      return new Response(
        JSON.stringify({ error: 'Room not found or invalid secret' }),
        { status: 404, headers: { ...corsHeaders(), 'Content-Type': 'application/json' } }
      )
    }

    // Check expiration
    const now = new Date()
    const expiresAt = new Date(chat.ttl_expires_at)
    if (now > expiresAt && !chat.saved) {
      return new Response(
        JSON.stringify({ error: 'Room has expired' }),
        { status: 410, headers: { ...corsHeaders(), 'Content-Type': 'application/json' } }
      )
    }

    // Verify session
    const { data: participant } = await supabase
      .from('participants')
      .select('*')
      .eq('chat_id', chat.id)
      .eq('session_id', sessionId)
      .single()

    if (!participant) {
      return new Response(
        JSON.stringify({ error: 'Invalid session' }),
        { status: 403, headers: { ...corsHeaders(), 'Content-Type': 'application/json' } }
      )
    }

    // Moderate content
    const moderation = await moderateContent(draft)
    if (moderation.blocked) {
      await supabase
        .from('moderation_logs')
        .insert({
          public_code: publicCode,
          endpoint: 'send-draft',
          blocked: true,
          categories: moderation.categories,
          created_at: new Date().toISOString()
        })

      return new Response(
        JSON.stringify({ 
          blocked: true,
          resources: ['National Suicide Prevention Lifeline: 988']
        }),
        { status: 400, headers: { ...corsHeaders(), 'Content-Type': 'application/json' } }
      )
    }

    // Store message
    const { error: messageError } = await supabase
      .from('messages')
      .insert({
        chat_id: chat.id,
        author_session: sessionId,
        role: 'user',
        content: draft
      })

    if (messageError) {
      throw new Error('Failed to store message')
    }

    return new Response(
      JSON.stringify({ success: true }),
      { status: 200, headers: { ...corsHeaders(), 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Send draft error:', error)
    
    if (error instanceof z.ZodError) {
      return new Response(
        JSON.stringify({ error: 'Invalid request data', details: error.errors }),
        { status: 400, headers: { ...corsHeaders(), 'Content-Type': 'application/json' } }
      )
    }

    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders(), 'Content-Type': 'application/json' } }
    )
  }
})
