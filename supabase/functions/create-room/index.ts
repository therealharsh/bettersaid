import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { z } from "https://deno.land/x/zod@v3.16.1/mod.ts"
import { encode } from "https://deno.land/std@0.168.0/encoding/base64.ts"

// Types
const CreateRoomSchema = z.object({
  goal: z.string().min(10).max(200),
  ttlHours: z.number().min(1).max(48).default(12),
  allowObservers: z.boolean().default(false)
})

interface CreateRoomResponse {
  publicCode: string
  shareUrl: string
  ttlExpiresAt: string
}

// Utilities
function generatePublicCode(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
  let result = ''
  for (let i = 0; i < 3; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length))
  }
  result += '-'
  for (let i = 0; i < 2; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length))
  }
  result += chars.charAt(Math.floor(Math.random() * chars.length))
  return result
}

function generateSecret(): string {
  const array = new Uint8Array(32) // 256 bits
  crypto.getRandomValues(array)
  return encode(array).replace(/[+/=]/g, (match) => {
    switch (match) {
      case '+': return '-'
      case '/': return '_'
      case '=': return ''
      default: return match
    }
  })
}

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
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  }
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
    const { goal, ttlHours, allowObservers } = CreateRoomSchema.parse(body)

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('PROJECT_URL')!
    const supabaseServiceKey = Deno.env.get('SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Generate unique public code (retry if collision)
    let publicCode: string
    let attempts = 0
    const maxAttempts = 10

    do {
      publicCode = generatePublicCode()
      const { data: existing } = await supabase
        .from('chats')
        .select('id')
        .eq('public_code', publicCode)
        .single()
      
      if (!existing) break
      attempts++
    } while (attempts < maxAttempts)

    if (attempts >= maxAttempts) {
      throw new Error('Failed to generate unique room code')
    }

    // Generate secret and hash it
    const secret = generateSecret()
    const secretHash = await hashSecret(secret)

    // Calculate TTL expiration
    const ttlExpiresAt = new Date()
    ttlExpiresAt.setHours(ttlExpiresAt.getHours() + ttlHours)

    // Create room in database
    const { data: chat, error: chatError } = await supabase
      .from('chats')
      .insert({
        public_code: publicCode,
        secret_hash: secretHash,
        goal,
        ttl_expires_at: ttlExpiresAt.toISOString(),
        settings: {
          allow_observers: allowObservers,
          ttl_hours: ttlHours
        }
      })
      .select()
      .single()

    if (chatError) {
      console.error('Database error:', chatError)
      throw new Error('Failed to create room')
    }

    // Log creation (no PII)
    await supabase
      .from('moderation_logs')
      .insert({
        public_code: publicCode,
        endpoint: 'create-room',
        blocked: false,
        categories: { created: true },
        created_at: new Date().toISOString()
      })

    // Build share URL
    const baseUrl = Deno.env.get('FRONTEND_URL') || 'http://localhost:5000'
    const shareUrl = `${baseUrl}/c/${publicCode}?secret=${secret}`

    const response: CreateRoomResponse = {
      publicCode,
      shareUrl,
      ttlExpiresAt: ttlExpiresAt.toISOString()
    }

    return new Response(
      JSON.stringify(response),
      { 
        status: 200,
        headers: { ...corsHeaders(), 'Content-Type': 'application/json' }
      }
    )

  } catch (error) {
    console.error('Create room error:', error)
    
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
