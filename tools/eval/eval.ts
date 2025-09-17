#!/usr/bin/env -S deno run --allow-all

import { readFileSync, writeFileSync } from "https://deno.land/std@0.168.0/fs/mod.ts"

interface ConflictSample {
  id: string
  goal: string
  original_draft: string
  context: string
  toxicity_level: 'low' | 'medium' | 'high'
  categories: string[]
}

interface RewriteResult {
  style: 'calm' | 'direct' | 'brief'
  text: string
}

interface EvaluationMetrics {
  toxicity_reduction: number // 0-1 scale
  goal_alignment: number // 0-1 scale  
  clarity: number // 0-1 scale
  fact_retention: number // 0-1 scale
  overall_score: number
}

interface EvaluationResult {
  sample_id: string
  original_draft: string
  goal: string
  rewrites: RewriteResult[]
  metrics: EvaluationMetrics
  notes: string[]
}

// Mock AI rewrite function (same as in Edge Function)
function generateMockRewrites(goal: string, draft: string): RewriteResult[] {
  const baseRewrite = draft
    .replace(/you're/gi, 'you are')
    .replace(/can't/gi, 'cannot')
    .replace(/won't/gi, 'will not')
    .replace(/stupid|dumb|idiot/gi, 'mistaken')
    .replace(/hate/gi, 'dislike')
    .replace(/never/gi, 'rarely')
    .replace(/always/gi, 'often')
  
  return [
    {
      style: 'calm',
      text: `I understand we have different perspectives on this. ${baseRewrite} Could we work together to find a solution that addresses ${goal.toLowerCase()}?`
    },
    {
      style: 'direct', 
      text: `${baseRewrite} Let's focus on ${goal.toLowerCase()} and find a way forward.`
    },
    {
      style: 'brief',
      text: `${baseRewrite} How can we resolve ${goal.toLowerCase()}?`
    }
  ]
}

// Evaluation functions
function evaluateToxicityReduction(original: string, rewrite: string): number {
  const toxicWords = ['stupid', 'idiot', 'hate', 'never', 'always', 'lazy', 'selfish', 'ridiculous']
  const personalAttacks = ['you are', 'you\'re', 'you never', 'you always']
  
  const originalToxic = toxicWords.filter(word => 
    original.toLowerCase().includes(word)
  ).length
  
  const originalAttacks = personalAttacks.filter(phrase =>
    original.toLowerCase().includes(phrase)
  ).length
  
  const rewriteToxic = toxicWords.filter(word =>
    rewrite.toLowerCase().includes(word)
  ).length
  
  const rewriteAttacks = personalAttacks.filter(phrase =>
    rewrite.toLowerCase().includes(phrase)
  ).length
  
  const originalScore = originalToxic + originalAttacks
  const rewriteScore = rewriteToxic + rewriteAttacks
  
  if (originalScore === 0) return 1.0 // Already non-toxic
  
  const reduction = Math.max(0, (originalScore - rewriteScore) / originalScore)
  return Math.min(1.0, reduction)
}

function evaluateGoalAlignment(goal: string, rewrite: string): number {
  const goalWords = goal.toLowerCase().split(' ')
  const rewriteWords = rewrite.toLowerCase().split(' ')
  
  // Check if rewrite mentions the goal or related concepts
  const goalMentioned = goalWords.some(word => 
    rewriteWords.includes(word) || rewrite.toLowerCase().includes(word)
  )
  
  // Check for solution-oriented language
  const solutionWords = ['resolve', 'solution', 'work together', 'find a way', 'address', 'discuss']
  const hasSolutionLanguage = solutionWords.some(phrase =>
    rewrite.toLowerCase().includes(phrase)
  )
  
  let score = 0.5 // Base score
  if (goalMentioned) score += 0.3
  if (hasSolutionLanguage) score += 0.2
  
  return Math.min(1.0, score)
}

function evaluateClarity(rewrite: string): number {
  // Simple heuristics for clarity
  const sentences = rewrite.split(/[.!?]+/).filter(s => s.trim().length > 0)
  const avgSentenceLength = rewrite.length / sentences.length
  
  // Prefer moderate sentence length (not too short, not too long)
  let lengthScore = 1.0
  if (avgSentenceLength < 20) lengthScore = 0.7 // Too short
  if (avgSentenceLength > 100) lengthScore = 0.6 // Too long
  
  // Check for clear structure
  const hasStructure = rewrite.includes('?') || rewrite.includes('.') || rewrite.includes(',')
  const structureScore = hasStructure ? 1.0 : 0.8
  
  return (lengthScore + structureScore) / 2
}

function evaluateFactRetention(original: string, rewrite: string): number {
  // Extract potential facts (numbers, specific terms, proper nouns)
  const factPattern = /\b(?:\d+|[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\b/g
  
  const originalFacts = original.match(factPattern) || []
  const rewriteFacts = rewrite.match(factPattern) || []
  
  if (originalFacts.length === 0) return 1.0 // No facts to retain
  
  const retainedFacts = originalFacts.filter(fact =>
    rewriteFacts.some(rf => rf.toLowerCase() === fact.toLowerCase())
  )
  
  return retainedFacts.length / originalFacts.length
}

function evaluateRewrite(sample: ConflictSample, rewrite: RewriteResult): EvaluationMetrics {
  const toxicity_reduction = evaluateToxicityReduction(sample.original_draft, rewrite.text)
  const goal_alignment = evaluateGoalAlignment(sample.goal, rewrite.text)
  const clarity = evaluateClarity(rewrite.text)
  const fact_retention = evaluateFactRetention(sample.original_draft, rewrite.text)
  
  const overall_score = (toxicity_reduction * 0.4 + goal_alignment * 0.3 + clarity * 0.2 + fact_retention * 0.1)
  
  return {
    toxicity_reduction,
    goal_alignment,
    clarity,
    fact_retention,
    overall_score
  }
}

function generateNotes(sample: ConflictSample, rewrites: RewriteResult[], metrics: EvaluationMetrics): string[] {
  const notes: string[] = []
  
  if (metrics.toxicity_reduction < 0.5) {
    notes.push('Low toxicity reduction - rewrite may still contain inflammatory language')
  }
  
  if (metrics.goal_alignment < 0.6) {
    notes.push('Poor goal alignment - rewrite does not clearly address the stated goal')
  }
  
  if (metrics.clarity < 0.7) {
    notes.push('Clarity issues - rewrite may be unclear or poorly structured')
  }
  
  if (metrics.fact_retention < 0.8) {
    notes.push('Fact retention issues - important details may have been lost')
  }
  
  if (metrics.overall_score > 0.8) {
    notes.push('Excellent rewrite quality across all metrics')
  } else if (metrics.overall_score > 0.6) {
    notes.push('Good rewrite quality with room for improvement')
  } else {
    notes.push('Poor rewrite quality - significant improvements needed')
  }
  
  return notes
}

async function runEvaluation(): Promise<void> {
  console.log('🔍 Starting BetterSaid Evaluation...\n')
  
  // Load conflict samples
  const samplesText = await Deno.readTextFile('./seed_conflict_samples.json')
  const samples: ConflictSample[] = JSON.parse(samplesText)
  
  const results: EvaluationResult[] = []
  
  for (const sample of samples) {
    console.log(`📝 Evaluating sample: ${sample.id}`)
    console.log(`   Goal: ${sample.goal}`)
    console.log(`   Toxicity: ${sample.toxicity_level}`)
    
    // Generate rewrites
    const rewrites = generateMockRewrites(sample.goal, sample.original_draft)
    
    // Evaluate each rewrite and take the best one
    let bestMetrics: EvaluationMetrics | null = null
    let bestRewrite: RewriteResult | null = null
    
    for (const rewrite of rewrites) {
      const metrics = evaluateRewrite(sample, rewrite)
      if (!bestMetrics || metrics.overall_score > bestMetrics.overall_score) {
        bestMetrics = metrics
        bestRewrite = rewrite
      }
    }
    
    if (bestMetrics && bestRewrite) {
      const notes = generateNotes(sample, rewrites, bestMetrics)
      
      results.push({
        sample_id: sample.id,
        original_draft: sample.original_draft,
        goal: sample.goal,
        rewrites,
        metrics: bestMetrics,
        notes
      })
      
      console.log(`   ✅ Overall Score: ${(bestMetrics.overall_score * 100).toFixed(1)}%`)
      console.log(`   📊 Toxicity Reduction: ${(bestMetrics.toxicity_reduction * 100).toFixed(1)}%`)
      console.log(`   🎯 Goal Alignment: ${(bestMetrics.goal_alignment * 100).toFixed(1)}%`)
      console.log('')
    }
  }
  
  // Calculate aggregate metrics
  const avgMetrics = {
    toxicity_reduction: results.reduce((sum, r) => sum + r.metrics.toxicity_reduction, 0) / results.length,
    goal_alignment: results.reduce((sum, r) => sum + r.metrics.goal_alignment, 0) / results.length,
    clarity: results.reduce((sum, r) => sum + r.metrics.clarity, 0) / results.length,
    fact_retention: results.reduce((sum, r) => sum + r.metrics.fact_retention, 0) / results.length,
    overall_score: results.reduce((sum, r) => sum + r.metrics.overall_score, 0) / results.length
  }
  
  // Generate CSV report
  const csvHeader = 'sample_id,toxicity_level,toxicity_reduction,goal_alignment,clarity,fact_retention,overall_score,notes\n'
  const csvRows = results.map(r => {
    const sample = samples.find(s => s.id === r.sample_id)!
    return [
      r.sample_id,
      sample.toxicity_level,
      (r.metrics.toxicity_reduction * 100).toFixed(1),
      (r.metrics.goal_alignment * 100).toFixed(1),
      (r.metrics.clarity * 100).toFixed(1),
      (r.metrics.fact_retention * 100).toFixed(1),
      (r.metrics.overall_score * 100).toFixed(1),
      `"${r.notes.join('; ')}"`
    ].join(',')
  }).join('\n')
  
  const csvContent = csvHeader + csvRows
  await Deno.writeTextFile('./evaluation_results.csv', csvContent)
  
  // Generate detailed JSON report
  await Deno.writeTextFile('./evaluation_results.json', JSON.stringify(results, null, 2))
  
  // Print summary
  console.log('📊 EVALUATION SUMMARY')
  console.log('=' .repeat(50))
  console.log(`Samples Evaluated: ${results.length}`)
  console.log(`Average Toxicity Reduction: ${(avgMetrics.toxicity_reduction * 100).toFixed(1)}%`)
  console.log(`Average Goal Alignment: ${(avgMetrics.goal_alignment * 100).toFixed(1)}%`)
  console.log(`Average Clarity: ${(avgMetrics.clarity * 100).toFixed(1)}%`)
  console.log(`Average Fact Retention: ${(avgMetrics.fact_retention * 100).toFixed(1)}%`)
  console.log(`Average Overall Score: ${(avgMetrics.overall_score * 100).toFixed(1)}%`)
  console.log('')
  console.log('📁 Reports generated:')
  console.log('   - evaluation_results.csv (summary)')
  console.log('   - evaluation_results.json (detailed)')
  console.log('')
  console.log('✅ Evaluation complete!')
}

// Run evaluation if this script is executed directly
if (import.meta.main) {
  try {
    await runEvaluation()
  } catch (error) {
    console.error('❌ Evaluation failed:', error)
    Deno.exit(1)
  }
}
