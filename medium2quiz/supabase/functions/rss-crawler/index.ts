// RSS Crawler Edge Function
// Automatically crawls RSS feeds and stores articles

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.39.3/+esm'
import { parseFeed } from "https://deno.land/x/rss@0.5.8/mod.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface CrawlRequest {
  action?: string
  source_ids?: string[]
  limit?: number
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { action = 'crawl_all', source_ids, limit = 10 }: CrawlRequest = 
      req.method === 'POST' ? await req.json() : {}

    console.log(`🕷️ Starting RSS crawl with action: ${action}`)

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Get RSS sources to crawl
    let query = supabase
      .from('rss_sources')
      .select('*')
      .eq('is_active', true)

    if (source_ids && source_ids.length > 0) {
      query = query.in('id', source_ids)
    }

    const { data: sources, error: sourcesError } = await query

    if (sourcesError) {
      throw new Error(`Failed to fetch RSS sources: ${sourcesError.message}`)
    }

    if (!sources || sources.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          articles_fetched: 0,
          message: 'No active RSS sources found'
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`📡 Found ${sources.length} RSS sources to crawl`)

    let totalArticles = 0
    const crawlResults = []

    // Crawl each source
    for (const source of sources) {
      try {
        console.log(`🔍 Crawling: ${source.name} (${source.url})`)
        
        const articles = await crawlRSSSource(source, limit)
        
        if (articles.length > 0) {
          // Insert articles into database
          const { data: insertedArticles, error: insertError } = await supabase
            .from('articles')
            .upsert(articles, { onConflict: 'url' })
            .select()

          if (insertError) {
            console.error(`❌ Error inserting articles for ${source.name}:`, insertError.message)
          } else {
            console.log(`✅ Inserted ${articles.length} articles from ${source.name}`)
            totalArticles += articles.length
          }
        }

        // Update RSS source last_fetched timestamp
        await supabase
          .from('rss_sources')
          .update({ 
            last_fetched: new Date().toISOString(),
            content_quality_score: articles.length > 0 ? 0.8 : 0.3
          })
          .eq('id', source.id)

        crawlResults.push({
          source: source.name,
          articles_found: articles.length,
          success: true
        })

        // Rate limiting - wait between requests
        await new Promise(resolve => setTimeout(resolve, 1000))

      } catch (error) {
        console.error(`❌ Failed to crawl ${source.name}:`, error.message)
        
        // If the error indicates HTML instead of RSS, mark source as inactive
        const isHtmlError = error.message.includes('HTML instead of RSS') || 
                           error.message.includes('Type html is not supported')
        
        await supabase
          .from('rss_sources')
          .update({ 
            last_fetched: new Date().toISOString(),
            content_quality_score: isHtmlError ? 0.0 : 0.1,
            is_active: !isHtmlError // Disable sources that return HTML
          })
          .eq('id', source.id)
        
        crawlResults.push({
          source: source.name,
          articles_found: 0,
          success: false,
          error: error.message
        })
      }
    }

    console.log(`🎉 Crawl complete! Total articles fetched: ${totalArticles}`)

    return new Response(
      JSON.stringify({
        success: true,
        articles_fetched: totalArticles,
        sources_crawled: sources.length,
        results: crawlResults,
        message: `Successfully crawled ${sources.length} sources and fetched ${totalArticles} articles`
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )

  } catch (error) {
    console.error('RSS crawler error:', error)
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      }
    )
  }
})

async function crawlRSSSource(source: any, limit: number = 10) {
  const response = await fetch(source.url, {
    headers: {
      'User-Agent': 'medium2quiz-crawler/1.0',
      'Accept': 'application/rss+xml, application/xml, text/xml, */*'
    },
    signal: AbortSignal.timeout(15000) // 15 second timeout
  })

  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${response.statusText}`)
  }

  const xmlText = await response.text()
  const articles = []

  try {
    // Check if the response is HTML instead of XML/RSS
    if (xmlText.trim().toLowerCase().startsWith('<!doctype html') || 
        xmlText.trim().toLowerCase().startsWith('<html')) {
      throw new Error('Feed returned HTML instead of RSS/XML - invalid feed URL')
    }

    // Parse RSS feed
    const feed = await parseFeed(xmlText)

    if (!feed || !feed.entries) {
      throw new Error('Failed to parse RSS feed - no entries found')
    }

    console.log(`📰 Found ${feed.entries.length} entries in ${source.name}`)

    for (let i = 0; i < Math.min(feed.entries.length, limit); i++) {
      const entry = feed.entries[i]
      
      try {
        const title = entry.title?.value || ''
        const link = entry.links?.[0]?.href || entry.id || ''
        const description = entry.description?.value || entry.summary?.value || ''
        const content = entry.content?.value || description
        const pubDate = entry.published || entry.updated || new Date()
        const author = entry.authors?.[0]?.name || 'Unknown'

        if (!title || !link || !content || content.length < 100) {
          continue // Skip items without essential content
        }

        const article = {
          id: crypto.randomUUID(),
          title: title.trim(),
          url: link.trim(),
          content: cleanContent(content),
          summary: description ? cleanContent(description).substring(0, 300) : '',
          author: author,
          source_type: 'rss',
          rss_source_id: source.id,
          topics: source.topics || [],
          tags: extractTags(title + ' ' + description),
          published_date: pubDate instanceof Date ? pubDate.toISOString() : new Date(pubDate).toISOString(),
          relevance_score: await calculateRelevanceScore(title, content, source),
          engagement_score: 0,
          freshness_score: calculateFreshnessScore(pubDate),
          content_quality_score: calculateQualityScore(title, content, author),
          created_at: new Date().toISOString()
        }

        articles.push(article)
      } catch (itemError) {
        console.warn(`Error processing RSS item: ${itemError.message}`)
        continue
      }
    }

  } catch (parseError) {
    throw new Error(`Failed to parse RSS feed: ${parseError.message}`)
  }

  return articles
}

// Removed getTextContent function - no longer needed with RSS parser

function cleanContent(content: string): string {
  if (!content) return ''
  
  // Remove HTML tags and clean up content
  return content
    .replace(/<[^>]*>/g, '') // Remove HTML tags
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#x27;/g, "'")
    .replace(/\s+/g, ' ') // Normalize whitespace
    .trim()
}

function extractTags(text: string): string[] {
  if (!text) return []
  
  const techKeywords = [
    'AI', 'machine learning', 'cloud', 'kubernetes', 'docker', 'aws', 'azure', 'gcp',
    'javascript', 'python', 'react', 'nodejs', 'typescript', 'golang', 'rust',
    'devops', 'security', 'blockchain', 'crypto', 'startup', 'fintech',
    'data science', 'analytics', 'database', 'api', 'microservices'
  ]
  
  const lowerText = text.toLowerCase()
  return techKeywords
    .filter(tag => lowerText.includes(tag.toLowerCase()))
    .slice(0, 8)
}

function parseDate(dateString: string | null): string {
  if (!dateString) return new Date().toISOString()
  
  try {
    const date = new Date(dateString)
    return isNaN(date.getTime()) ? new Date().toISOString() : date.toISOString()
  } catch {
    return new Date().toISOString()
  }
}

async function calculateRelevanceScore(title: string, content: string, source: any): Promise<number> {
  let score = 0.5 // Base score
  
  try {
    // Use AI to determine content relevance to the source topics
    const openAIKey = Deno.env.get('OPENAI_API_KEY')
    if (openAIKey && source.topics && source.topics.length > 0) {
      const response = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${openAIKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: 'gpt-4o-mini',
          messages: [{
            role: 'user',
            content: `Rate the relevance of this article to these topics: ${source.topics.join(', ')}.
            Article title: ${title}
            Article content preview: ${content.substring(0, 500)}
            
            Return only a number between 0 and 1, where 1 is highly relevant and 0 is not relevant.`
          }],
          max_tokens: 10,
          temperature: 0,
        }),
      })

      if (response.ok) {
        const data = await response.json()
        const aiScore = parseFloat(data.choices[0]?.message?.content?.trim() || '0.5')
        score = isNaN(aiScore) ? 0.5 : Math.min(1.0, Math.max(0.0, aiScore))
      }
    }
  } catch (error) {
    console.error('Error calculating AI relevance score:', error.message)
    // Fallback to base score if AI fails
  }
  
  return Math.min(score, 1.0)
}

function calculateFreshnessScore(pubDate: string | Date | null): number {
  if (!pubDate) return 0.1
  
  try {
    const date = pubDate instanceof Date ? pubDate : new Date(pubDate)
    const daysSincePublished = (Date.now() - date.getTime()) / (1000 * 60 * 60 * 24)
    
    if (daysSincePublished < 1) return 1.0
    if (daysSincePublished < 3) return 0.8
    if (daysSincePublished < 7) return 0.6
    if (daysSincePublished < 30) return 0.4
    return 0.2
  } catch {
    return 0.1
  }
}

function calculateQualityScore(title: string, content: string, author: string | null): number {
  let score = 0.5
  
  // Title quality
  if (title && title.length > 10 && title.length < 100) score += 0.1
  
  // Content quality
  if (content && content.length > 500) score += 0.1
  if (content && content.length > 1500) score += 0.1
  
  // Has author
  if (author && author !== 'Unknown') score += 0.1
  
  return Math.min(score, 1.0)
}