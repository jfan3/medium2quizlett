import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    )

    const { sourceId, sourceType, content, userId } = await req.json()

    // The article should already exist - fetch it instead of creating a new one
    const { data: article, error: articleError } = await supabaseClient
      .from('articles')
      .select('*')
      .eq('id', sourceId)
      .single()

    if (articleError) {
      throw new Error(`Article not found: ${articleError.message}`)
    }

    // Use the article's actual content for flashcard generation
    const contentForCards = article.content || content

    // Generate quiz cards using Claude
    const quizCards = await generateQuizCards(contentForCards, article.id, userId)

    // Insert quiz cards
    const { error: quizError } = await supabaseClient
      .from('flashcards')
      .insert(quizCards)

    if (quizError) throw quizError

    // Update article processing status to completed
    await supabaseClient
      .from('articles')
      .update({ processing_status: 'completed' })
      .eq('id', sourceId)

    return new Response(
      JSON.stringify({ 
        success: true, 
        articleId: article.id,
        quizCardCount: quizCards.length 
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      },
    )

  } catch (error) {
    console.error('Processing error:', error)
    
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      },
    )
  }
})

async function processURL(url: string) {
  try {
    const response = await fetch(url)
    const html = await response.text()
    
    // Simple HTML to text extraction (you might want to use a more sophisticated parser)
    const content = html
      .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '')
      .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '')
      .replace(/<[^>]*>/g, '')
      .replace(/\s+/g, ' ')
      .trim()

    const title = html.match(/<title[^>]*>([^<]+)<\/title>/i)?.[1] || 'Web Article'
    
    return {
      content,
      title,
      summary: content.substring(0, 300) + '...'
    }
  } catch (error) {
    throw new Error(`Failed to process URL: ${error.message}`)
  }
}

async function processPDF(pdfUrl: string) {
  // For now, return placeholder - you'd integrate with a PDF parsing service
  return "PDF content processing not implemented yet. Please use text input instead."
}

async function extractTopics(content: string): Promise<string[]> {
  const claudeKey = Deno.env.get('CLAUDE_API_KEY')
  if (!claudeKey) return []

  try {
    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': claudeKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        model: 'claude-3-haiku-20240307',
        max_tokens: 100,
        temperature: 0.3,
        messages: [{
          role: 'user',
          content: `Extract 3-5 key technical topics from this content. Return only a JSON array of topic names: ${content.substring(0, 1000)}`
        }]
      }),
    })

    const data = await response.json()
    const topicsStr = data.content[0]?.text || '[]'
    return JSON.parse(topicsStr)
  } catch (error) {
    console.error('Topic extraction failed:', error)
    return []
  }
}

async function assessDifficulty(content: string): Promise<string> {
  const claudeKey = Deno.env.get('CLAUDE_API_KEY') 
  if (!claudeKey) return 'medium'

  try {
    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': claudeKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        model: 'claude-3-haiku-20240307',
        max_tokens: 10,
        temperature: 0,
        messages: [{
          role: 'user',
          content: `Assess the technical difficulty of this content. Return only one word: "beginner", "intermediate", or "advanced": ${content.substring(0, 500)}`
        }]
      }),
    })

    const data = await response.json()
    const difficulty = data.content[0]?.text?.toLowerCase()?.trim() || 'medium'
    return ['beginner', 'intermediate', 'advanced'].includes(difficulty) ? difficulty : 'medium'
  } catch (error) {
    console.error('Difficulty assessment failed:', error)
    return 'medium'
  }
}

async function generateQuizCards(content: string, articleId: string, userId?: string) {
  const claudeKey = Deno.env.get('CLAUDE_API_KEY')
  if (!claudeKey) {
    // Return sample quiz cards if no Claude key
    return [{
      user_id: userId || '00000000-0000-0000-0000-000000000001',
      article_id: articleId,
      question: "What is the main topic of this article?",
      answer: "Technical content",
      card_type: "flashcard",
      difficulty: "medium",
      card_order: 1
    }]
  }

  try {
    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': claudeKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        model: 'claude-3-haiku-20240307',
        max_tokens: 2000,
        temperature: 0.7,
        messages: [{
          role: 'user',
          content: `You are an expert educator creating high-quality study cards from technical content. 

Create 8-12 diverse, engaging quiz cards that test deep understanding. Each card should:
- Ask specific, meaningful questions about key concepts, methods, applications, or implications
- Provide detailed, educational answers that teach the concept clearly
- Focus on "why" and "how" questions, not just "what"
- Include practical applications when relevant

Return ONLY a valid JSON array. Each card must have:
- question: Specific, thought-provoking question
- answer: Comprehensive answer (2-4 sentences) that teaches the concept
- card_type: "flashcard" 
- difficulty: "easy", "medium", or "hard"
- source_paragraph: Brief relevant excerpt from content

Content to process: ${content.substring(0, 4000)}

Example format:
[{"question": "How does the Transformer architecture achieve parallelization compared to RNNs?", "answer": "The Transformer uses self-attention mechanisms that allow all positions to be processed simultaneously, unlike RNNs which must process sequences step-by-step. This parallelization significantly reduces training time and enables better utilization of modern GPU architectures.", "card_type": "flashcard", "difficulty": "medium", "source_paragraph": "The Transformer allows for significantly more parallelization..."}]`
        }]
      }),
    })

    if (!response.ok) {
      const errorText = await response.text()
      console.error('Claude API error:', response.status, errorText)
      throw new Error(`Claude API error: ${response.status} - ${errorText}`)
    }

    const data = await response.json()
    let cardsStr = data.content[0]?.text || '[]'
    
    // Clean up the response text to handle multiple JSON objects or extra text
    try {
      // Remove any markdown formatting
      cardsStr = cardsStr.replace(/```json\n?/g, '').replace(/```\n?/g, '')
      
      // Find the first valid JSON array by looking for [ and the last ]
      const firstBracket = cardsStr.indexOf('[')
      const lastBracket = cardsStr.lastIndexOf(']')
      
      if (firstBracket !== -1 && lastBracket !== -1 && lastBracket > firstBracket) {
        cardsStr = cardsStr.substring(firstBracket, lastBracket + 1)
      }
      
      cardsStr = cardsStr.trim()
    } catch (cleanupError) {
      console.error('Error cleaning response:', cleanupError)
    }
    
    const cards = JSON.parse(cardsStr)

    return cards.map((card: any, index: number) => ({
      user_id: userId || '00000000-0000-0000-0000-000000000001',
      article_id: articleId,
      question: card.question,
      answer: card.answer,
      choices: card.choices,
      card_type: card.card_type || 'flashcard',
      difficulty: card.difficulty || 'medium',
      source_paragraph: card.source_paragraph || null,
      card_order: index + 1
    }))
  } catch (error) {
    console.error('Quiz card generation failed:', error)
    
    // Generate better fallback quiz cards based on content analysis
    const words = content.split(/\s+/)
    const sentences = content.split(/[.!?]+/).filter(s => s.trim().length > 20)
    
    const fallbackCards = []
    
    // Extract key topics from the beginning of the content
    const firstParagraph = sentences.slice(0, 3).join('. ')
    const title = content.split('\n').find(line => line.trim().length > 10 && line.trim().length < 100) || 'This Content'
    
    fallbackCards.push({
      user_id: userId || '00000000-0000-0000-0000-000000000001',
      article_id: articleId,
      question: `What is the main topic discussed in "${title}"?`,
      answer: firstParagraph.substring(0, 200) + (firstParagraph.length > 200 ? '...' : ''),
      card_type: "flashcard",
      difficulty: "easy",
      card_order: 1
    })
    
    // If content is long enough, create more cards
    if (sentences.length > 5) {
      const midContent = sentences.slice(3, 6).join('. ')
      fallbackCards.push({
        user_id: userId || '00000000-0000-0000-0000-000000000001',
        article_id: articleId,
        question: "What are the key concepts or methods described?",
        answer: midContent.substring(0, 200) + (midContent.length > 200 ? '...' : ''),
        card_type: "flashcard", 
        difficulty: "medium",
        card_order: 2
      })
    }
    
    return fallbackCards
  }
}