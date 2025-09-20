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
  contextSummary?: string
}

interface ConversationMessage {
  id: string
  author_session: string | null
  role: string
  content: string
  created_at: string
}

interface ConversationContext {
  messages: ConversationMessage[]
  summary: string
  participantCount: number
  currentUserSession: string
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

// Conversation Context Retrieval
async function getConversationContext(
  supabase: any,
  chatId: string,
  currentSessionId: string
): Promise<ConversationContext> {
  // Fetch recent conversation history (last 20 messages)
  const { data: messages, error: messagesError } = await supabase
    .from('messages')
    .select('id, author_session, role, content, created_at')
    .eq('chat_id', chatId)
    .order('created_at', { ascending: false })
    .limit(20)

  if (messagesError) {
    console.error('Failed to fetch conversation history:', messagesError)
    return {
      messages: [],
      summary: 'Unable to retrieve conversation history.',
      participantCount: 0,
      currentUserSession: currentSessionId
    }
  }

  // Reverse to get chronological order
  const chronologicalMessages = (messages || []).reverse()

  // Get participant count
  const { data: participants } = await supabase
    .from('participants')
    .select('session_id')
    .eq('chat_id', chatId)

  const participantCount = participants?.length || 0

  // Generate conversation summary
  const summary = generateConversationSummary(chronologicalMessages, currentSessionId, participantCount)

  return {
    messages: chronologicalMessages,
    summary,
    participantCount,
    currentUserSession: currentSessionId
  }
}

// Generate a concise summary of the conversation context
function generateConversationSummary(
  messages: ConversationMessage[],
  currentSessionId: string,
  participantCount: number
): string {
  if (messages.length === 0) {
    return 'This is the start of a new conversation.'
  }

  const userMessages = messages.filter(m => m.role === 'user')
  const recentMessages = messages.slice(-10) // Last 10 messages for context

  // Identify conversation patterns
  const hasMultipleParticipants = participantCount > 1
  const currentUserMessages = userMessages.filter(m => m.author_session === currentSessionId)
  const otherUserMessages = userMessages.filter(m => m.author_session !== currentSessionId)

  let summary = `Conversation with ${participantCount} participant${participantCount > 1 ? 's' : ''}. `

  if (currentUserMessages.length > 0) {
    summary += `You have sent ${currentUserMessages.length} message${currentUserMessages.length > 1 ? 's' : ''}. `
  }

  if (otherUserMessages.length > 0) {
    summary += `Other participant${otherUserMessages.length > 1 ? 's have' : ' has'} sent ${otherUserMessages.length} message${otherUserMessages.length > 1 ? 's' : ''}. `
  }

  // Analyze recent message tone and content
  if (recentMessages.length > 0) {
    const recentUserMessages = recentMessages.filter(m => m.role === 'user')
    if (recentUserMessages.length > 0) {
      const lastMessage = recentUserMessages[recentUserMessages.length - 1]
      const isFromCurrentUser = lastMessage.author_session === currentSessionId
      summary += `Most recent message was from ${isFromCurrentUser ? 'you' : 'the other participant'}. `
    }
  }

  return summary.trim()
}

// Enhanced Content Safety with Two-Tier Moderation
interface ModerationResult {
  hardBlock: boolean // True for violence, self-harm, illegal content
  softFlag: boolean  // True for harsh/disrespectful language
  categories: Record<string, boolean>
  severity: 'low' | 'medium' | 'high'
  reason?: string
}

async function moderateContent(text: string): Promise<ModerationResult> {
  // This is a mock implementation
  // In production, this would call Azure Content Safety API
  
  const lowerText = text.toLowerCase()
  
  // STRICT FILTER - Hard blocks that show crisis resources
  const strictCategories = {
    violence: lowerText.includes('kill you') || lowerText.includes('hurt you') || 
              lowerText.includes('attack you') || lowerText.includes('weapon') ||
              lowerText.includes('murder') || lowerText.includes('assault'),
    self_harm: lowerText.includes('suicide') || lowerText.includes('kill myself') ||
               lowerText.includes('end my life') || lowerText.includes('hurt myself'),
    illegal: lowerText.includes('drug deal') || lowerText.includes('illegal') ||
             lowerText.includes('weapon') || lowerText.includes('bomb')
  }
  
  // LENIENT FILTER - Soft flags for harsh language that can be rewritten
  const softCategories = {
    harsh_language: lowerText.includes('hate') || lowerText.includes('stupid') || 
                   lowerText.includes('idiot') || lowerText.includes('damn') ||
                   lowerText.includes('pissed') || lowerText.includes('annoying'),
    disrespectful: lowerText.includes('disrespect') || lowerText.includes('rude') ||
                  lowerText.includes('inconsiderate') || lowerText.includes('selfish'),
    frustrated: lowerText.includes('frustrated') || lowerText.includes('angry') ||
               lowerText.includes('mad') || lowerText.includes('upset')
  }
  
  const hardBlock = Object.values(strictCategories).some(Boolean)
  const softFlag = Object.values(softCategories).some(Boolean)
  
  let severity: 'low' | 'medium' | 'high' = 'low'
  let reason = ''
  
  if (hardBlock) {
    severity = 'high'
    if (strictCategories.violence) reason = 'Contains violent content'
    else if (strictCategories.self_harm) reason = 'Contains self-harm content'
    else if (strictCategories.illegal) reason = 'Contains illegal content'
  } else if (softFlag) {
    severity = 'medium'
    if (softCategories.harsh_language) reason = 'Contains harsh language'
    else if (softCategories.disrespectful) reason = 'May come across as disrespectful'
    else if (softCategories.frustrated) reason = 'Expresses strong frustration'
  }
  
  return {
    hardBlock,
    softFlag,
    categories: { ...strictCategories, ...softCategories },
    severity,
    reason
  }
}

// Legacy interface for backward compatibility
async function moderateContentLegacy(text: string): Promise<ContentSafetyResult> {
  const result = await moderateContent(text)
  return {
    blocked: result.hardBlock,
    categories: result.categories,
    severity: result.severity
  }
}

// AI Rewrite using Azure OpenAI with Conversation Context
async function generateRewrites(
  goal: string, 
  draft: string, 
  context?: ConversationContext, 
  moderationFlag?: { softFlag: boolean; reason?: string }
): Promise<RewriteResponse> {
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

  // Build conversation context section for the prompt
  let contextSection = ''
  if (context && context.messages.length > 0) {
    contextSection = `
CONVERSATION CONTEXT:
${context.summary}

RECENT CONVERSATION HISTORY:
${context.messages.slice(-8).map(msg => {
  const isCurrentUser = msg.author_session === context.currentUserSession
  const sender = msg.role === 'user' ? (isCurrentUser ? 'You' : 'Other participant') : 'System'
  return `${sender}: ${msg.content}`
}).join('\n')}

CONTEXT CONSIDERATIONS:
- Reference relevant points from the conversation history when appropriate
- Build on previous exchanges rather than ignoring them
- Address any unresolved issues or concerns that have been raised
- Maintain consistency with the established communication tone
- Consider how your message fits into the ongoing dialogue
`
  }

  // Construct the system prompt for optimal communication rewriting
  const systemPrompt = `You are a communication coach helping people express themselves more effectively. Your role is to rewrite messages to improve clarity and reduce conflict while preserving authenticity.

TASK: Rewrite the user's draft message in three distinct communication styles while keeping their authentic voice and core intent.

STYLES REQUIRED:
1. CALM: Uses "I" statements, acknowledges feelings, gentle but clear. Focuses on understanding and emotional safety.
2. DIRECT: Clear, straightforward, gets to the point. Respectful but assertive. Professional tone.
3. BRIEF: Concise and efficient. Removes unnecessary words while staying polite and clear.

CRITICAL GUIDELINES:
- Preserve the speaker's authentic voice and specific message
- Keep emotional truth - don't sanitize genuine feelings
- Sound natural and conversational, NOT robotic or corporate
- Avoid repetitive phrases like "let's work together" or "find a way forward"
- Don't add collaborative language unless it was in the original
- Match the relationship context (casual vs formal, personal vs professional)
- Each rewrite should feel like something the person would actually say
- Vary your language - don't repeat the same phrases across rewrites

CONTEXT AWARENESS:
- Consider the communication goal and relationship dynamics
- Use conversation history to make rewrites contextually relevant
- Balance honesty with appropriate tone for the situation
- Don't force positivity onto negative emotions - help express them constructively
${contextSection ? '- Reference conversation context naturally when relevant, don\'t force connections' : ''}
${moderationFlag?.softFlag ? `- SAFETY NOTE: The original message was flagged as potentially ${moderationFlag.reason?.toLowerCase()}. Help express the core message more constructively while preserving the authentic emotion.` : ''}

${contextSection}

OUTPUT FORMAT: You must respond with a valid JSON object only. Do not include any markdown formatting, code blocks, or explanatory text. Return exactly this structure:
{
  "rewrites": [
    {"style": "calm", "text": "rewritten message"},
    {"style": "direct", "text": "rewritten message"}, 
    {"style": "brief", "text": "rewritten message"}
  ],
  "analysis": "Brief analysis of the original message's tone and intent${contextSection ? ', considering conversation context' : ''}. Under 200 characters."
}`

  const userPrompt = `COMMUNICATION GOAL: ${goal}

ORIGINAL DRAFT: ${draft}

Rewrite this message in three styles (calm, direct, brief). Keep the authentic voice and core message, but help it land better with the recipient. Make each version sound natural and conversational - avoid formulaic or repetitive language.`

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

    // NEW SAFETY FLOW: Check for hard blocks first, but let soft flags through to AI
    console.log('🛡️ [Safety] Running content moderation...')
    const inputModeration = await moderateContent(draft)
    
    // HARD BLOCK: Violence, self-harm, illegal content → immediate block with crisis resources
    if (inputModeration.hardBlock) {
      console.log('🚫 [Safety] Hard block triggered:', inputModeration.reason)
      
      // Log the hard block
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
          reason: inputModeration.reason,
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

    // SOFT FLAG: Harsh/disrespectful language → tag but continue to AI rewriting
    if (inputModeration.softFlag) {
      console.log('⚠️ [Safety] Soft flag detected:', inputModeration.reason, '- proceeding with rewrite')
    }

    // Retrieve conversation context for enhanced AI rewrites
    console.log('🔍 [Context] Retrieving conversation history...')
    const conversationContext = await getConversationContext(supabase, chat.id, sessionId)
    console.log('✅ [Context] Retrieved', conversationContext.messages.length, 'messages for context')

    // Generate AI rewrites with conversation context (including flagged content)
    console.log('🚀 [Rewrite] Starting AI rewrite generation with context...')
    const moderationContext = inputModeration.softFlag ? { 
      softFlag: true, 
      reason: inputModeration.reason 
    } : undefined
    const rewriteResponse = await generateRewrites(goal, draft, conversationContext, moderationContext)
    console.log('✅ [Rewrite] AI rewrite generation completed')

    // Only moderate AI-generated rewrites for hard blocks (not soft flags)
    const safeRewrites: RewriteResult[] = []
    for (const rewrite of rewriteResponse.rewrites) {
      const outputModeration = await moderateContent(rewrite.text)
      
      // Only filter out hard blocks from AI rewrites
      if (!outputModeration.hardBlock) {
        safeRewrites.push(rewrite)
      } else {
        console.log('🚫 [Safety] AI rewrite contained hard block, filtered out:', rewrite.style)
      }
    }

    // If all AI rewrites were hard blocked (very unlikely), return error
    if (safeRewrites.length === 0) {
      console.log('❌ [Safety] All AI rewrites were hard blocked')
      return new Response(
        JSON.stringify({ 
          blocked: true,
          reason: 'Unable to generate safe alternatives',
          resources: ['Please rephrase your message and try again.']
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

    // Enhance the response with safety information for soft flags
    let enhancedNotes = rewriteResponse.notes || 'AI-generated communication suggestions. Please review before sending.'
    
    if (inputModeration.softFlag) {
      enhancedNotes = `⚠️ ${inputModeration.reason}. Here are healthier ways to express your message:\n\n${enhancedNotes}`
    }

    const response: RewriteResponse = {
      rewrites: safeRewrites,
      notes: enhancedNotes,
      contextSummary: conversationContext.messages.length > 0 ? conversationContext.summary : undefined
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
