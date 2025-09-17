import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { z } from "https://deno.land/x/zod@v3.16.1/mod.ts"
import { encode } from "https://deno.land/std@0.168.0/encoding/base64.ts"

// Types
const JoinRoomSchema = z.object({
  publicCode: z.string().min(1),
  displayName: z.string().min(2).max(20)
})

interface JoinRoomResponse {
  sessionId: string
  goal: string
  ttlExpiresAt: string
}

// Utilities
async function hashSecret(secret: string): Promise<string> {
  const encoder = new TextEncoder()
  const data = encoder.encode(secret)
  const hashBuffer = await crypto.subtle.digest('SHA-256', data)
  const hashArray = new Uint8Array(hashBuffer)
  return encode(hashArray)
}

function generateSessionId(): string {
  return crypto.randomUUID()
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

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders() })
  }

  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      { 
        status: 405, 
        headers: { ...corsHeaders(), 'Content-Type': 'application/json' }
      }
    )
  }

  try {
    // Parse and validate request body
    const body = await req.json()
    const { publicCode, displayName } = JoinRoomSchema.parse(body)

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

    // Hash the provided secret
    const secretHash = await hashSecret(secret)

    // Find the room and verify secret
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

    // Verify secret matches
    if (chat.secret_hash !== secretHash) {
      return new Response(
        JSON.stringify({ error: 'Invalid room secret' }),
        { 
          status: 403,
          headers: { ...corsHeaders(), 'Content-Type': 'application/json' }
        }
      )
    }

    // Check if observers are allowed (for future use)
    const settings = chat.settings || {}
    const allowObservers = settings.allow_observers || false

    // Generate session ID
    const sessionId = generateSessionId()

    // Check if participant already exists with this session
    const { data: existingParticipant } = await supabase
      .from('participants')
      .select('*')
      .eq('chat_id', chat.id)
      .eq('session_id', sessionId)
      .single()

    if (!existingParticipant) {
      // Add participant to room
      const { error: participantError } = await supabase
        .from('participants')
        .insert({
          chat_id: chat.id,
          session_id: sessionId,
          display_name: displayName
        })

      if (participantError) {
        console.error('Failed to add participant:', participantError)
        throw new Error('Failed to join room')
      }
    }

    // Log join event (no PII)
    await supabase
      .from('moderation_logs')
      .insert({
        public_code: publicCode,
        endpoint: 'join-room',
        blocked: false,
        categories: { joined: true },
        created_at: new Date().toISOString()
      })

    const response: JoinRoomResponse = {
      sessionId,
      goal: chat.goal,
      ttlExpiresAt: chat.ttl_expires_at
    }

    return new Response(
      JSON.stringify(response),
      { 
        status: 200,
        headers: { ...corsHeaders(), 'Content-Type': 'application/json' }
      }
    )

  } catch (error) {
    console.error('Join room error:', error)
    
    if (error instanceof z.ZodError) {
      return new Response(
        JSON.stringify({ 
          error: 'Invalid request data',
          details: error.errors
        }),
        { 
          status: 400,
          headers: { ...corsHeaders(), 'Content-Type': 'application/json' }
        }
      )
    }

    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { 
        status: 500,
        headers: { ...corsHeaders(), 'Content-Type': 'application/json' }
      }
    )
  }
})
