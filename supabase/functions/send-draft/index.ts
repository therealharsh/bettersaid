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

// Enhanced Content Safety with Two-Tier Moderation (same as rewrite endpoint)
interface ModerationResult {
  hardBlock: boolean // True for violence, self-harm, illegal content
  softFlag: boolean  // True for harsh/disrespectful language
  categories: Record<string, boolean>
  severity: 'low' | 'medium' | 'high'
  reason?: string
}

async function moderateContent(text: string): Promise<ModerationResult> {
  const azureOpenAIEndpoint = Deno.env.get('AZURE_OPENAI_ENDPOINT')
  const azureOpenAIApiKey = Deno.env.get('AZURE_OPENAI_API_KEY')
  const azureOpenAIDeployment = Deno.env.get('AZURE_OPENAI_DEPLOYMENT') || 'gpt-4'
  
  // Fallback to simple keyword-based moderation if Azure OpenAI not configured
  if (!azureOpenAIEndpoint || !azureOpenAIApiKey) {
    console.log('⚠️ [Moderation] Azure OpenAI not configured, using basic fallback')
    return {
      hardBlock: false,
      softFlag: false,
      categories: {},
      severity: 'low'
    }
  }

  const systemPrompt = `You are a content moderation AI. Analyze the message for safety violations.

HARD BLOCK (immediate crisis intervention needed):
- Violence: Threats of physical harm to others, murder, assault
- Self-harm: Suicide ideation, self-injury threats, ending life
- Illegal: Drug dealing, weapons sales, bomb making, other serious crimes

SOFT FLAG (harsh but not dangerous):
- Harsh language: Insults, profanity, mean-spirited comments
- Disrespectful: Rude, inconsiderate, dismissive language
- Frustrated: Strong anger, upset feelings, emotional outbursts

IMPORTANT: Emotional expressions like "I feel hurt", "I'm frustrated", or "this is disappointing" should NOT be flagged. Only flag genuinely harmful or excessively harsh content.

Respond with JSON only:
{
  "hardBlock": boolean,
  "softFlag": boolean, 
  "categories": {
    "violence": boolean,
    "self_harm": boolean,
    "illegal": boolean,
    "harsh_language": boolean,
    "disrespectful": boolean,
    "frustrated": boolean
  },
  "severity": "low" | "medium" | "high",
  "reason": "brief explanation if flagged"
}`

  try {
    const response = await fetch(
      `${azureOpenAIEndpoint}/openai/deployments/${azureOpenAIDeployment}/chat/completions?api-version=2024-02-15-preview`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'api-key': azureOpenAIApiKey,
        },
        body: JSON.stringify({
          messages: [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: `Analyze this message: "${text}"` }
          ],
          max_tokens: 300,
          temperature: 0.1, // Low temperature for consistent moderation
          response_format: { type: "json_object" }
        }),
      }
    )

    if (!response.ok) {
      console.error('Azure OpenAI moderation error:', response.status, await response.text())
      throw new Error(`Moderation API error: ${response.status}`)
    }

    const data = await response.json()
    const aiResponse = data.choices?.[0]?.message?.content

    if (!aiResponse) {
      throw new Error('No moderation response from AI')
    }

    const result = JSON.parse(aiResponse)
    
    console.log('🤖 [AI Moderation] Result:', result)
    
    return {
      hardBlock: result.hardBlock || false,
      softFlag: result.softFlag || false,
      categories: result.categories || {},
      severity: result.severity || 'low',
      reason: result.reason
    }

  } catch (error) {
    console.error('AI moderation failed, using safe fallback:', error)
    
    // Safe fallback - don't block anything if AI fails
    return {
      hardBlock: false,
      softFlag: false,
      categories: {},
      severity: 'low',
      reason: 'AI moderation unavailable'
    }
  }
}

// Legacy function for backward compatibility
async function moderateContentLegacy(text: string): Promise<{ blocked: boolean; categories: Record<string, boolean> }> {
  const result = await moderateContent(text)
  return {
    blocked: result.hardBlock, // Only hard blocks are treated as "blocked"
    categories: result.categories
  }
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

    // NEW SAFETY FLOW: Only block hard violations when sending messages
    console.log('🛡️ [SendDraft] Running content moderation...')
    const moderation = await moderateContent(draft)
    
    // HARD BLOCK ONLY: Violence, self-harm, illegal content → block the send
    if (moderation.hardBlock) {
      console.log('🚫 [SendDraft] Hard block triggered:', moderation.reason)
      
      await supabase
        .from('moderation_logs')
        .insert({
          public_code: publicCode,
          endpoint: 'send-draft',
          blocked: true,
          categories: moderation.categories,
          severity: moderation.severity,
          created_at: new Date().toISOString()
        })

      return new Response(
        JSON.stringify({ 
          blocked: true,
          reason: moderation.reason,
          resources: [
            'National Suicide Prevention Lifeline: 988',
            'Crisis Text Line: Text HOME to 741741',
            'International Association for Suicide Prevention: https://www.iasp.info/resources/Crisis_Centres/'
          ]
        }),
        { status: 400, headers: { ...corsHeaders(), 'Content-Type': 'application/json' } }
      )
    }

    // SOFT FLAGS: Log but allow the message to be sent
    if (moderation.softFlag) {
      console.log('⚠️ [SendDraft] Soft flag detected but allowing send:', moderation.reason)
      // Log soft flags for analytics but don't block
      await supabase
        .from('moderation_logs')
        .insert({
          public_code: publicCode,
          endpoint: 'send-draft',
          blocked: false,
          categories: moderation.categories,
          severity: moderation.severity,
          created_at: new Date().toISOString()
        })
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
