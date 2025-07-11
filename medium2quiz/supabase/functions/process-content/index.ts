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

    const { sourceId, sourceType, content } = await req.json()

    // Update processing status
    await supabaseClient
      .from('user_sources')
      .update({ processing_status: 'processing' })
      .eq('id', sourceId)

    let processedContent = ''
    let title = ''
    let summary = ''

    // Process different content types
    switch (sourceType) {
      case 'url':
        const urlResult = await processURL(content)
        processedContent = urlResult.content
        title = urlResult.title
        summary = urlResult.summary
        break
      case 'pdf':
        processedContent = await processPDF(content)
        title = 'PDF Document'
        break
      case 'text':
        processedContent = content
        title = 'Custom Text'
        break
      case 'chatgpt':
        processedContent = content
        title = 'ChatGPT Response'
        break
    }

    // Generate article record
    const { data: article, error: articleError } = await supabaseClient
      .from('articles')
      .insert({
        title,
        content: processedContent,
        summary,
        source_type: sourceType,
        topics: await extractTopics(processedContent),
        difficulty_level: await assessDifficulty(processedContent),
        estimated_read_time: Math.ceil(processedContent.split(' ').length / 200)
      })
      .select()
      .single()

    if (articleError) throw articleError

    // Generate quiz cards using OpenAI
    const quizCards = await generateQuizCards(processedContent, article.id)

    // Insert quiz cards
    const { error: quizError } = await supabaseClient
      .from('quiz_cards')
      .insert(quizCards)

    if (quizError) throw quizError

    // Update processing status to completed
    await supabaseClient
      .from('user_sources')
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
  const openAIKey = Deno.env.get('OPENAI_API_KEY')
  if (!openAIKey) return []

  try {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${openAIKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-3.5-turbo',
        messages: [{
          role: 'user',
          content: `Extract 3-5 key technical topics from this content. Return only a JSON array of topic names: ${content.substring(0, 1000)}`
        }],
        max_tokens: 100,
        temperature: 0.3,
      }),
    })

    const data = await response.json()
    const topicsStr = data.choices[0]?.message?.content || '[]'
    return JSON.parse(topicsStr)
  } catch (error) {
    console.error('Topic extraction failed:', error)
    return []
  }
}

async function assessDifficulty(content: string): Promise<string> {
  const openAIKey = Deno.env.get('OPENAI_API_KEY') 
  if (!openAIKey) return 'medium'

  try {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${openAIKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-3.5-turbo',
        messages: [{
          role: 'user',
          content: `Assess the technical difficulty of this content. Return only one word: "beginner", "intermediate", or "advanced": ${content.substring(0, 500)}`
        }],
        max_tokens: 10,
        temperature: 0,
      }),
    })

    const data = await response.json()
    const difficulty = data.choices[0]?.message?.content?.toLowerCase()?.trim() || 'medium'
    return ['beginner', 'intermediate', 'advanced'].includes(difficulty) ? difficulty : 'medium'
  } catch (error) {
    console.error('Difficulty assessment failed:', error)
    return 'medium'
  }
}

async function generateQuizCards(content: string, articleId: string) {
  const openAIKey = Deno.env.get('OPENAI_API_KEY')
  if (!openAIKey) {
    // Return sample quiz cards if no OpenAI key
    return [{
      article_id: articleId,
      question: "What is the main topic of this article?",
      answer: "Technical content",
      card_type: "flashcard",
      difficulty: "medium",
      card_order: 1
    }]
  }

  try {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${openAIKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-4',
        messages: [{
          role: 'system',
          content: 'You are an expert at creating educational quiz cards from technical content. Generate 5-15 diverse quiz cards that test understanding of key concepts, definitions, processes, and applications.'
        }, {
          role: 'user',
          content: `Create quiz cards from this content. Return a JSON array where each card has: question, answer, card_type ("flashcard" or "multiple_choice"), choices (array of 4 options for multiple choice, null for flashcard), difficulty ("easy", "medium", "hard"), source_paragraph (relevant excerpt). Content: ${content.substring(0, 3000)}`
        }],
        max_tokens: 2000,
        temperature: 0.7,
      }),
    })

    const data = await response.json()
    const cardsStr = data.choices[0]?.message?.content || '[]'
    const cards = JSON.parse(cardsStr)

    return cards.map((card: any, index: number) => ({
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
    // Return fallback quiz card
    return [{
      article_id: articleId,
      question: "What is the main concept discussed in this content?",
      answer: "Please review the article content",
      card_type: "flashcard",
      difficulty: "medium",
      card_order: 1
    }]
  }
}