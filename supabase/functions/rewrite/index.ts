import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { z } from "https://deno.land/x/zod@v3.16.1/mod.ts"
import { encode } from "https://deno.land/std@0.168.0/encoding/base64.ts"

/**
 * Rewrite Function - Azure OpenAI Integration
 * 
 * Required Environment Variables:
 * - AZURE_OPENAI_ENDPOINT: Your Azure OpenAI endpoint URL (e.g., https://your-resource.openai.azure.com/)
 * - AZURE_OPENAI_API_KEY: Your Azure OpenAI API key
 * - AZURE_OPENAI_DEPLOYMENT: Your deployed model name (optional, defaults to 'gpt-4')
 * - PROJECT_URL: Supabase project URL (existing)
 * - SERVICE_ROLE_KEY: Supabase service role key (existing)
 * 
 * The function uses GPT-4 to intelligently rewrite user messages in three communication styles:
 * - CALM: Empathetic, collaborative, and emotionally safe
 * - DIRECT: Clear, straightforward, and respectfully assertive  
 * - BRIEF: Concise and efficient while maintaining politeness
 */

// Types
const RewriteSchema = z.object({
  publicCode: z.string().min(1),
  sessionId: z.string().uuid(),
  goal: z.string().min(10).max(200),
  draft: z.string().min(1).max(2000)
})

interface RewriteResult {
  style: 'calm' | 'direct' | 'brief'
  text: string
}

interface RewriteResponse {
  rewrites: RewriteResult[]
  notes?: string
}

interface ContentSafetyResult {
  blocked: boolean
  categories: Record<string, boolean>
  severity: 'low' | 'medium' | 'high'
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
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  }
}

function extractBearerToken(authHeader: string | null): string | null {
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return null
  }
  return authHeader.substring(7)
}

// Content Safety (Mock implementation - replace with Azure Content Safety)
async function moderateContent(text: string): Promise<ContentSafetyResult> {
  // This is a mock implementation
  // In production, this would call Azure Content Safety API
  
  const lowerText = text.toLowerCase()
  const categories = {
    violence: lowerText.includes('kill') || lowerText.includes('hurt') || lowerText.includes('attack'),
    hate: lowerText.includes('hate') || lowerText.includes('stupid') || lowerText.includes('idiot'),
    self_harm: lowerText.includes('suicide') || lowerText.includes('kill myself'),
    sexual: false // Not implemented in mock
  }
  
  const blocked = Object.values(categories).some(Boolean)
  const severity = blocked ? 'medium' : 'low'
  
  return { blocked, categories, severity }
}

// AI Rewrite using Azure OpenAI
async function generateRewrites(goal: string, draft: string): Promise<RewriteResponse> {
  const azureOpenAIEndpoint = Deno.env.get('AZURE_OPENAI_ENDPOINT')
  const azureOpenAIApiKey = Deno.env.get('AZURE_OPENAI_API_KEY')
  const azureOpenAIDeployment = Deno.env.get('AZURE_OPENAI_DEPLOYMENT') || 'gpt-4'
  
  console.log('🔧 [Azure OpenAI] Checking configuration...')
  console.log('🔧 [Azure OpenAI] Endpoint configured:', !!azureOpenAIEndpoint)
  console.log('🔧 [Azure OpenAI] API Key configured:', !!azureOpenAIApiKey)
  console.log('🔧 [Azure OpenAI] Deployment:', azureOpenAIDeployment)
  
  if (!azureOpenAIEndpoint || !azureOpenAIApiKey) {
    console.error('❌ [Azure OpenAI] Configuration missing - falling back to simple rewrite')
    
    // Fallback to a simple rewrite if Azure OpenAI is not configured
    const cleanedDraft = draft.trim()
    const fallbackRewrites: RewriteResult[] = [
      {
        style: 'calm',
        text: `I wanted to share something with you: ${cleanedDraft}. How do you see this situation?`
      },
      {
        style: 'direct',
        text: cleanedDraft
      },
      {
        style: 'brief',
        text: cleanedDraft.length > 100 ? cleanedDraft.substring(0, 97) + '...' : cleanedDraft
      }
    ]

    return {
      rewrites: fallbackRewrites,
      notes: 'Azure OpenAI not configured. Basic rewrites provided. Please configure AZURE_OPENAI_ENDPOINT and AZURE_OPENAI_API_KEY environment variables.'
    }
  }

  // Construct the system prompt for optimal communication rewriting
  const systemPrompt = `You are an expert communication coach specializing in helping people express themselves more effectively in conversations. Your role is to rewrite messages to improve clarity, reduce conflict potential, and promote understanding.

TASK: Rewrite the user's draft message in three distinct communication styles while preserving the core intent and authenticity.

STYLES REQUIRED:
1. CALM: Emphasizes empathy, collaboration, and emotional safety. Uses "I" statements, acknowledges others' perspectives, and invites dialogue. Tone is gentle but clear.
2. DIRECT: Clear, straightforward, and assertive without being aggressive. Gets to the point quickly while remaining respectful. Professional but warm.
3. BRIEF: Concise and efficient communication. Removes unnecessary words while maintaining politeness and clarity. Ideal for quick exchanges.

GUIDELINES:
- Preserve the speaker's authentic voice and core message
- Remove inflammatory language while keeping emotional truth
- Use inclusive language that builds rather than burns bridges
- Maintain appropriate formality level for the context
- Each rewrite should feel natural, not robotic
- Avoid corporate speak or overly clinical language
- Focus on solutions and forward movement when possible

CONTEXT AWARENESS:
- Consider the communication goal provided by the user
- Adapt tone based on relationship dynamics implied in the message
- Balance honesty with kindness
- Prioritize understanding over being "right"

OUTPUT FORMAT: You must respond with a valid JSON object only. Do not include any markdown formatting, code blocks, or explanatory text. Return exactly this structure:
{
  "rewrites": [
    {"style": "calm", "text": "rewritten message"},
    {"style": "direct", "text": "rewritten message"}, 
    {"style": "brief", "text": "rewritten message"}
  ],
  "analysis": "Brief analysis of the original message's tone and intent"
}`

  const userPrompt = `COMMUNICATION GOAL: ${goal}

ORIGINAL DRAFT: ${draft}

Please rewrite this message in the three required styles (calm, direct, brief). Focus on maintaining the speaker's authentic voice while improving the message's effectiveness for healthy communication.`

  try {
    // Make request to Azure OpenAI
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
            { role: 'user', content: userPrompt }
          ],
          max_tokens: 1000,
          temperature: 0.7,
          top_p: 0.9,
          frequency_penalty: 0.1,
          presence_penalty: 0.1,
          response_format: { type: "json_object" }
        }),
      }
    )

    if (!response.ok) {
      const errorText = await response.text()
      console.error('Azure OpenAI API Error:', response.status, errorText)
      throw new Error(`Azure OpenAI API error: ${response.status}`)
    }

    const data = await response.json()
    const aiResponse = data.choices?.[0]?.message?.content

    if (!aiResponse) {
      throw new Error('No response from Azure OpenAI')
    }

    // Parse the JSON response
    let parsedResponse
    try {
      parsedResponse = JSON.parse(aiResponse)
    } catch (parseError) {
      console.error('Failed to parse Azure OpenAI response:', aiResponse)
      throw new Error('Invalid response format from AI')
    }

    // Validate response structure
    if (!parsedResponse.rewrites || !Array.isArray(parsedResponse.rewrites) || parsedResponse.rewrites.length !== 3) {
      throw new Error('Invalid response structure from AI')
    }

    // Ensure all required styles are present
    const requiredStyles = ['calm', 'direct', 'brief']
    const responseStyles = parsedResponse.rewrites.map((r: any) => r.style)
    if (!requiredStyles.every(style => responseStyles.includes(style))) {
      throw new Error('Missing required communication styles in AI response')
    }

    // Map to expected format
    const rewrites: RewriteResult[] = parsedResponse.rewrites.map((rewrite: any) => ({
      style: rewrite.style as 'calm' | 'direct' | 'brief',
      text: rewrite.text
    }))

    // Log success for debugging
    console.log('✅ [Azure OpenAI] Successfully generated', rewrites.length, 'rewrites')

    return {
      rewrites,
      notes: parsedResponse.analysis || 'AI-generated communication suggestions. Please review before sending.'
    }

  } catch (error) {
    console.error('Azure OpenAI Error:', error)
    
    // Fallback to a simple rewrite if AI fails
    console.log('🔄 [Fallback] Using simplified rewrite due to AI error')
    
    const cleanedDraft = draft.trim()
    const fallbackRewrites: RewriteResult[] = [
      {
        style: 'calm',
        text: `I wanted to share something with you: ${cleanedDraft}. How do you see this situation?`
      },
      {
        style: 'direct',
        text: cleanedDraft
      },
      {
        style: 'brief',
        text: cleanedDraft.length > 100 ? cleanedDraft.substring(0, 97) + '...' : cleanedDraft
      }
    ]

    return {
      rewrites: fallbackRewrites,
      notes: 'AI service temporarily unavailable. Basic rewrites provided.'
    }
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

  const startTime = Date.now()

  try {
    // Parse and validate request body
    const body = await req.json()
    const { publicCode, sessionId, goal, draft } = RewriteSchema.parse(body)

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

    // Verify session exists
    const { data: participant } = await supabase
      .from('participants')
      .select('*')
      .eq('chat_id', chat.id)
      .eq('session_id', sessionId)
      .single()

    if (!participant) {
      return new Response(
        JSON.stringify({ error: 'Invalid session' }),
        { 
          status: 403,
          headers: { ...corsHeaders(), 'Content-Type': 'application/json' }
        }
      )
    }

    // Moderate input content
    const inputModeration = await moderateContent(draft)
    
    if (inputModeration.blocked) {
      // Log moderation block
      await supabase
        .from('moderation_logs')
        .insert({
          public_code: publicCode,
          endpoint: 'rewrite',
          blocked: true,
          categories: inputModeration.categories,
          severity: inputModeration.severity,
          created_at: new Date().toISOString()
        })

      return new Response(
        JSON.stringify({ 
          blocked: true,
          resources: [
            'National Suicide Prevention Lifeline: 988',
            'Crisis Text Line: Text HOME to 741741',
            'International Association for Suicide Prevention: https://www.iasp.info/resources/Crisis_Centres/'
          ]
        }),
        { 
          status: 400,
          headers: { ...corsHeaders(), 'Content-Type': 'application/json' }
        }
      )
    }

    // Generate AI rewrites
    console.log('🚀 [Rewrite] Starting AI rewrite generation...')
    const rewriteResponse = await generateRewrites(goal, draft)
    console.log('✅ [Rewrite] AI rewrite generation completed')

    // Moderate each rewrite
    const moderatedRewrites: RewriteResult[] = []
    for (const rewrite of rewriteResponse.rewrites) {
      const outputModeration = await moderateContent(rewrite.text)
      
      if (!outputModeration.blocked) {
        moderatedRewrites.push(rewrite)
      }
    }

    // If all rewrites were blocked, return error
    if (moderatedRewrites.length === 0) {
      return new Response(
        JSON.stringify({ 
          blocked: true,
          resources: ['Unable to generate safe alternatives. Please rephrase your message.']
        }),
        { 
          status: 400,
          headers: { ...corsHeaders(), 'Content-Type': 'application/json' }
        }
      )
    }

    // Note: Rewrites are generated but NOT stored in the database
    // They are returned to the client for preview only
    // The user must explicitly choose to send a rewrite via the send-draft endpoint

    // Log successful rewrite (no PII)
    const latency = Date.now() - startTime
    await supabase
      .from('moderation_logs')
      .insert({
        public_code: publicCode,
        endpoint: 'rewrite',
        blocked: false,
        categories: inputModeration.categories,
        severity: inputModeration.severity,
        token_count: draft.length, // Rough approximation
        latency_ms: latency,
        model_used: 'azure-openai',
        created_at: new Date().toISOString()
      })

    const response: RewriteResponse = {
      rewrites: moderatedRewrites,
      notes: rewriteResponse.notes
    }

    return new Response(
      JSON.stringify(response),
      { 
        status: 200,
        headers: { ...corsHeaders(), 'Content-Type': 'application/json' }
      }
    )

  } catch (error) {
    console.error('❌ [Rewrite] Caught error:', error)
    console.error('❌ [Rewrite] Error type:', typeof error)
    console.error('❌ [Rewrite] Error constructor:', error?.constructor?.name)
    
    if (error instanceof z.ZodError) {
      console.error('❌ [Rewrite] Zod validation error:', error.errors)
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

    // Log the error details for debugging
    if (error instanceof Error) {
      console.error('❌ [Rewrite] Error message:', error.message)
      console.error('❌ [Rewrite] Error stack:', error.stack)
    }

    return new Response(
      JSON.stringify({ 
        error: 'Internal server error',
        details: error instanceof Error ? error.message : 'Unknown error'
      }),
      { 
        status: 500,
        headers: { ...corsHeaders(), 'Content-Type': 'application/json' }
      }
    )
  }
})
