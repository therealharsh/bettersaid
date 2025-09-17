import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { z } from "https://deno.land/x/zod@v3.16.1/mod.ts"
import { encode } from "https://deno.land/std@0.168.0/encoding/base64.ts"

const SaveRoomSchema = z.object({
  publicCode: z.string().min(1)
})

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
    const { publicCode } = SaveRoomSchema.parse(body)

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

    // Extend TTL by 24 hours
    const newExpiration = new Date()
    newExpiration.setHours(newExpiration.getHours() + 24)

    const { error: updateError } = await supabase
      .from('chats')
      .update({
        saved: true,
        ttl_expires_at: newExpiration.toISOString()
      })
      .eq('id', chat.id)

    if (updateError) {
      throw new Error('Failed to save room')
    }

    return new Response(
      JSON.stringify({ 
        saved: true,
        ttlExpiresAt: newExpiration.toISOString()
      }),
      { status: 200, headers: { ...corsHeaders(), 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Save room error:', error)
    
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
