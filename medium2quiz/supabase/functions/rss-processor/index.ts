import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { DOMParser } from 'https://deno.land/x/deno_dom/deno-dom-wasm.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface RSSItem {
  title: string
  link: string
  description: string
  pubDate: string
  author?: string
  guid?: string
}

interface RSSFeed {
  title: string
  description: string
  link: string
  items: RSSItem[]
}

interface ArticleScore {
  topicRelevance: number
  rssAffinity: number
  freshness: number
  difficultyMatch: number
  finalScore: number
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

    const { action, rss_source_id, user_id, selected_topics } = await req.json()

    switch (action) {
      case 'fetch_feed':
        return await fetchAndProcessFeed(supabaseClient, rss_source_id)
      case 'setup_user_feeds':
        return await setupUserFeeds(supabaseClient, user_id, selected_topics)
      case 'backfill_articles':
        return await backfillArticles(supabaseClient, rss_source_id)
      case 'process_scheduled_feeds':
        return await processScheduledFeeds(supabaseClient)
      default:
        throw new Error('Invalid action')
    }

  } catch (error) {
    console.error('RSS processor error:', error)
    
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      },
    )
  }
})

async function fetchAndProcessFeed(supabaseClient: any, rssSourceId: string) {
  // Get RSS source details
  const { data: rssSource, error: sourceError } = await supabaseClient
    .from('rss_sources')
    .select('*')
    .eq('id', rssSourceId)
    .single()

  if (sourceError) throw sourceError

  // Fetch and parse RSS feed
  const feed = await fetchRSSFeed(rssSource.url)
  
  // Set cutoff date to 3 months ago for recent content focus
  const threeMonthsAgo = new Date()
  threeMonthsAgo.setMonth(threeMonthsAgo.getMonth() - 3)
  
  // Process new articles with 3-month filter
  const processedCount = await processRSSItems(supabaseClient, feed.items, rssSourceId, threeMonthsAgo)

  // Update last fetched timestamp and engagement score
  await supabaseClient
    .from('rss_sources')
    .update({ 
      last_fetched: new Date().toISOString(),
      avg_engagement_score: await calculateSourceEngagement(supabaseClient, rssSourceId)
    })
    .eq('id', rssSourceId)

  return new Response(
    JSON.stringify({ 
      success: true, 
      feedTitle: feed.title,
      processedCount,
      rssSourceId 
    }),
    {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    }
  )
}

async function setupUserFeeds(supabaseClient: any, userId: string, selectedTopics: string[]) {
  // Get user's selected topics from latest topic selection session or use provided topics
  let topicsToMatch = selectedTopics
  
  if (!topicsToMatch || topicsToMatch.length === 0) {
    const { data: topicSelections, error: topicError } = await supabaseClient
      .from('user_topic_selections')
      .select(`
        topics (
          name
        )
      `)
      .eq('user_id', userId)
      .eq('is_active', true)
      .order('selected_at', { ascending: false })
      .limit(10)

    if (topicError) throw topicError
    topicsToMatch = topicSelections.map((ts: any) => ts.topics.name)
  }

  // Find RSS sources that match selected topics
  const { data: rssSources, error: sourcesError } = await supabaseClient
    .from('rss_sources')
    .select('*')
    .overlaps('topics', topicsToMatch)
    .eq('is_active', true)
    .eq('auto_refresh_enabled', true)

  if (sourcesError) throw sourcesError

  // Get existing user RSS feeds to calculate initial affinity
  const { data: existingFeeds, error: existingError } = await supabaseClient
    .from('user_rss_feeds')
    .select('*')
    .eq('user_id', userId)

  if (existingError) throw existingError
  
  const existingFeedMap = new Map(existingFeeds.map((feed: any) => [feed.rss_source_id, feed]))

  // Subscribe user to these feeds with smart initial affinity
  const subscriptions = rssSources.map((source: any) => {
    const existing = existingFeedMap.get(source.id)
    const topicMatchCount = source.topics.filter((topic: string) => topicsToMatch.includes(topic)).length
    const topicRelevance = topicMatchCount / Math.max(source.topics.length, 1)
    
    return {
      user_id: userId,
      rss_source_id: source.id,
      affinity_score: existing?.affinity_score ?? (1.0 + topicRelevance), // Boost for topic relevance
      subscription_strength: 1.0 + (source.content_quality_score * 0.5),
      is_active: true
    }
  })

  const { error: subscriptionError } = await supabaseClient
    .from('user_rss_feeds')
    .upsert(subscriptions, { onConflict: 'user_id,rss_source_id' })

  if (subscriptionError) throw subscriptionError

  // Process articles for each source and auto-queue high-scoring ones
  let totalQueued = 0
  
  for (const source of rssSources) {
    try {
      const feed = await fetchRSSFeed(source.url)
      const cutoffDate = new Date()
      cutoffDate.setMonth(cutoffDate.getMonth() - 3) // 3 months back for initial setup
      
      const articles = await processRSSItems(supabaseClient, feed.items, source.id, cutoffDate)
      
      // Auto-queue high-scoring articles for the user
      const queuedCount = await autoQueueArticles(supabaseClient, userId, source.id, cutoffDate)
      totalQueued += queuedCount
      
      // Small delay to avoid overwhelming the system
      await new Promise(resolve => setTimeout(resolve, 500))
      
    } catch (error) {
      console.error(`Error processing source ${source.name}:`, error.message)
      continue
    }
  }

  return new Response(
    JSON.stringify({ 
      success: true, 
      subscriptionsCount: subscriptions.length,
      selectedTopics: topicsToMatch,
      totalArticlesQueued: totalQueued
    }),
    {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    }
  )
}

async function processScheduledFeeds(supabaseClient: any) {
  // Get feeds that are due for refresh
  const { data: scheduledFeeds, error: scheduleError } = await supabaseClient
    .from('rss_fetch_schedule')
    .select(`
      *,
      rss_sources (*),
      users (id, preferred_difficulty)
    `)
    .lte('next_fetch_time', new Date().toISOString())
    .eq('is_active', true)
    .order('priority_score', { ascending: false })
    .limit(50) // Process up to 50 feeds per run

  if (scheduleError) throw scheduleError

  let processed = 0
  let queued = 0

  for (const schedule of scheduledFeeds) {
    try {
      // Fetch and process RSS feed
      const feed = await fetchRSSFeed(schedule.rss_sources.url)
      
      // Only process articles newer than last successful fetch
      const cutoffDate = schedule.last_successful_fetch 
        ? new Date(schedule.last_successful_fetch)
        : new Date(Date.now() - 24 * 60 * 60 * 1000) // 24 hours ago if no previous fetch

      const articlesProcessed = await processRSSItems(
        supabaseClient, 
        feed.items, 
        schedule.rss_source_id, 
        cutoffDate
      )
      
      // Auto-queue articles for this user
      const articlesQueued = await autoQueueArticles(
        supabaseClient, 
        schedule.user_id, 
        schedule.rss_source_id, 
        cutoffDate
      )

      // Update schedule with next fetch time
      const nextFetchTime = new Date()
      nextFetchTime.setSeconds(nextFetchTime.getSeconds() + schedule.fetch_frequency)

      await supabaseClient
        .from('rss_fetch_schedule')
        .update({
          next_fetch_time: nextFetchTime.toISOString(),
          last_successful_fetch: new Date().toISOString(),
          consecutive_failures: 0
        })
        .eq('id', schedule.id)

      processed += articlesProcessed
      queued += articlesQueued
      
    } catch (error) {
      console.error(`Error processing scheduled feed ${schedule.id}:`, error.message)
      
      // Update failure count
      await supabaseClient
        .from('rss_fetch_schedule')
        .update({
          consecutive_failures: schedule.consecutive_failures + 1,
          next_fetch_time: new Date(Date.now() + 3600000).toISOString() // Retry in 1 hour
        })
        .eq('id', schedule.id)
    }
    
    // Small delay between feeds
    await new Promise(resolve => setTimeout(resolve, 200))
  }

  return new Response(
    JSON.stringify({ 
      success: true, 
      feedsProcessed: scheduledFeeds.length,
      articlesProcessed: processed,
      articlesQueued: queued
    }),
    {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    }
  )
}

async function autoQueueArticles(supabaseClient: any, userId: string, rssSourceId: string, cutoffDate: Date) {
  // Get recent articles from this RSS source
  const { data: articles, error: articlesError } = await supabaseClient
    .from('articles')
    .select('*')
    .eq('rss_source_id', rssSourceId)
    .gte('published_date', cutoffDate.toISOString())
    .order('published_date', { ascending: false })
    .limit(20) // Process latest 20 articles

  if (articlesError) throw articlesError

  // Get user's reading patterns for scoring
  const { data: userPattern, error: patternError } = await supabaseClient
    .from('user_reading_patterns')
    .select('*')
    .eq('user_id', userId)
    .single()

  if (patternError && patternError.code !== 'PGRST116') throw patternError

  // Get user's RSS feed affinity
  const { data: userFeed, error: feedError } = await supabaseClient
    .from('user_rss_feeds')
    .select('affinity_score')
    .eq('user_id', userId)
    .eq('rss_source_id', rssSourceId)
    .single()

  if (feedError) throw feedError

  let queuedCount = 0

  for (const article of articles) {
    // Check if article is already queued for this user
    const { data: existingQueue, error: queueError } = await supabaseClient
      .from('user_articles')
      .select('id')
      .eq('user_id', userId)
      .eq('article_id', article.id)
      .single()

    if (!queueError) continue // Already queued

    // Calculate personalized score
    const score = await calculateArticleScore(article, userPattern, userFeed?.affinity_score || 1.0)
    
    // Auto-queue if score is above threshold
    if (score.finalScore > 0.6) {
      await supabaseClient
        .from('user_articles')
        .insert({
          user_id: userId,
          article_id: article.id,
          status: 'queued',
          personalized_score: score.finalScore,
          preference_score: 0,
          queued_at: new Date().toISOString()
        })

      queuedCount++
    }
  }

  return queuedCount
}

async function calculateArticleScore(article: any, userPattern: any, rssAffinity: number): Promise<ArticleScore> {
  let topicRelevance = 0
  let freshness = 0
  let difficultyMatch = 0.5 // Default neutral match
  
  // Calculate topic relevance
  if (userPattern?.preferred_topics && article.topics) {
    const matchingTopics = article.topics.filter((topic: string) => 
      userPattern.preferred_topics.includes(topic)
    )
    topicRelevance = matchingTopics.length / Math.max(article.topics.length, 1)
  }
  
  // Calculate freshness (0-1, where 1 is very recent)
  if (article.published_date) {
    const articleDate = new Date(article.published_date)
    const now = new Date()
    const daysDiff = (now.getTime() - articleDate.getTime()) / (1000 * 60 * 60 * 24)
    freshness = Math.max(0, 1 - (daysDiff / 30)) // Decay over 30 days
  }
  
  // Calculate difficulty match
  if (userPattern?.optimal_difficulty_level && article.difficulty_level) {
    if (article.difficulty_level === userPattern.optimal_difficulty_level) {
      difficultyMatch = 1.0
    } else if (
      (article.difficulty_level === 'easy' && userPattern.optimal_difficulty_level === 'medium') ||
      (article.difficulty_level === 'medium' && ['easy', 'hard'].includes(userPattern.optimal_difficulty_level)) ||
      (article.difficulty_level === 'hard' && userPattern.optimal_difficulty_level === 'medium')
    ) {
      difficultyMatch = 0.7
    } else {
      difficultyMatch = 0.3
    }
  }
  
  // Normalize RSS affinity to 0-1 scale
  const normalizedRssAffinity = Math.min(1, Math.max(0, rssAffinity / 5.0))
  
  // Calculate weighted final score
  const finalScore = (
    topicRelevance * 0.4 +
    normalizedRssAffinity * 0.3 +
    freshness * 0.2 +
    difficultyMatch * 0.1
  )

  return {
    topicRelevance,
    rssAffinity: normalizedRssAffinity,
    freshness,
    difficultyMatch,
    finalScore: Math.round(finalScore * 1000) / 1000 // Round to 3 decimal places
  }
}

async function calculateSourceEngagement(supabaseClient: any, rssSourceId: string): Promise<number> {
  const { data: engagementData, error } = await supabaseClient
    .from('articles')
    .select('total_views, total_likes, total_dislikes')
    .eq('rss_source_id', rssSourceId)
    .gte('created_at', new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString()) // Last 30 days

  if (error || !engagementData.length) return 0

  const totalViews = engagementData.reduce((sum: number, article: any) => sum + (article.total_views || 0), 0)
  const totalLikes = engagementData.reduce((sum: number, article: any) => sum + (article.total_likes || 0), 0)
  const totalDislikes = engagementData.reduce((sum: number, article: any) => sum + (article.total_dislikes || 0), 0)

  const engagementRate = totalViews > 0 ? (totalLikes - totalDislikes) / totalViews : 0
  return Math.max(0, Math.min(1, engagementRate)) // Normalize to 0-1
}

async function fetchRSSFeed(url: string): Promise<RSSFeed> {
  const response = await fetch(url)
  const xmlText = await response.text()
  
  const parser = new DOMParser()
  const doc = parser.parseFromString(xmlText, 'text/xml')
  
  if (!doc) {
    throw new Error('Failed to parse RSS feed')
  }

  const channel = doc.querySelector('channel')
  if (!channel) {
    throw new Error('Invalid RSS feed format')
  }

  const title = channel.querySelector('title')?.textContent || 'Unknown Feed'
  const description = channel.querySelector('description')?.textContent || ''
  const link = channel.querySelector('link')?.textContent || ''

  const items: RSSItem[] = Array.from(channel.querySelectorAll('item')).map(item => {
    const title = item.querySelector('title')?.textContent || ''
    const link = item.querySelector('link')?.textContent || ''
    const description = item.querySelector('description')?.textContent || ''
    const pubDate = item.querySelector('pubDate')?.textContent || ''
    const author = item.querySelector('author')?.textContent || 
                  item.querySelector('creator')?.textContent || ''
    const guid = item.querySelector('guid')?.textContent || link

    return {
      title: cleanText(title),
      link,
      description: cleanText(description),
      pubDate,
      author,
      guid
    }
  })

  return { title, description, link, items }
}

async function processRSSItems(supabaseClient: any, items: RSSItem[], rssSourceId: string, cutoffDate?: Date): Promise<number> {
  let processedCount = 0

  for (const item of items) {
    try {
      // Parse publication date
      const publishedDate = item.pubDate ? new Date(item.pubDate) : null
      
      // Skip articles older than cutoff date if provided
      if (cutoffDate && publishedDate && publishedDate < cutoffDate) {
        continue
      }

      // Check if article already exists
      const { data: existingArticle } = await supabaseClient
        .from('articles')
        .select('id')
        .eq('url', item.link)
        .single()

      if (existingArticle) {
        continue // Skip existing articles
      }

      // Extract full content from article URL
      const content = await extractArticleContent(item.link)
      
      // Skip if content is too short (likely not a full article)
      if (content.length < 500) {
        continue
      }

      // Extract topics and assess difficulty using AI
      const topics = await extractTopics(content)
      const difficulty = await assessDifficulty(content)
      
      // Calculate content quality metrics
      const wordCount = content.split(/\s+/).length
      const readabilityScore = calculateReadabilityScore(content)
      const freshness = publishedDate ? calculateFreshnessScore(publishedDate) : 0

      // Create article record with enhanced metadata
      const { error: articleError } = await supabaseClient
        .from('articles')
        .insert({
          title: item.title,
          url: item.link,
          content,
          summary: item.description.substring(0, 500),
          author: item.author,
          published_date: publishedDate ? publishedDate.toISOString() : null,
          source_type: 'rss',
          rss_source_id: rssSourceId,
          topics,
          difficulty_level: difficulty,
          estimated_read_time: Math.ceil(wordCount / 200),
          word_count: wordCount,
          readability_score: readabilityScore,
          freshness_score: freshness,
          relevance_score: 0.5, // Will be updated by scoring algorithms
          processing_status: 'completed'
        })

      if (articleError) {
        console.error('Error inserting article:', articleError)
        continue
      }

      processedCount++
      
      // Add small delay to avoid overwhelming the system
      if (processedCount % 10 === 0) {
        await new Promise(resolve => setTimeout(resolve, 100))
      }
      
    } catch (error) {
      console.error('Error processing RSS item:', error)
      continue
    }
  }

  return processedCount
}

async function extractArticleContent(url: string): Promise<string> {
  try {
    const response = await fetch(url)
    const html = await response.text()
    
    // Enhanced HTML to text extraction
    let content = html
      .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '')
      .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '')
      .replace(/<nav[^>]*>[\s\S]*?<\/nav>/gi, '')
      .replace(/<footer[^>]*>[\s\S]*?<\/footer>/gi, '')
      .replace(/<header[^>]*>[\s\S]*?<\/header>/gi, '')
      .replace(/<aside[^>]*>[\s\S]*?<\/aside>/gi, '')
      .replace(/<[^>]*>/g, ' ')
      .replace(/\s+/g, ' ')
      .trim()

    return content.substring(0, 15000) // Increased content length limit
  } catch (error) {
    console.error('Failed to extract content from:', url)
    return ''
  }
}

function calculateReadabilityScore(text: string): number {
  // Simple readability score based on sentence and word length
  const sentences = text.split(/[.!?]+/).filter(s => s.trim().length > 0)
  const words = text.split(/\s+/).filter(w => w.length > 0)
  
  if (sentences.length === 0 || words.length === 0) return 0.5
  
  const avgWordsPerSentence = words.length / sentences.length
  const avgCharsPerWord = words.reduce((sum, word) => sum + word.length, 0) / words.length
  
  // Score based on complexity (0-1, where 1 is most readable)
  const complexityScore = Math.max(0, 1 - (avgWordsPerSentence - 15) / 30) * 
                         Math.max(0, 1 - (avgCharsPerWord - 4) / 10)
  
  return Math.round(complexityScore * 100) / 100
}

function calculateFreshnessScore(publishedDate: Date): number {
  const now = new Date()
  const hoursDiff = (now.getTime() - publishedDate.getTime()) / (1000 * 60 * 60)
  
  // Score decays over 7 days
  return Math.max(0, 1 - (hoursDiff / (7 * 24)))
}

async function backfillArticles(supabaseClient: any, rssSourceId: string) {
  // Get RSS source details
  const { data: rssSource, error: sourceError } = await supabaseClient
    .from('rss_sources')
    .select('*')
    .eq('id', rssSourceId)
    .single()

  if (sourceError) throw sourceError

  const cutoffDate = new Date()
  cutoffDate.setFullYear(cutoffDate.getFullYear() - 1) // Past year

  let totalProcessed = 0
  
  try {
    // Fetch current feed
    const currentFeed = await fetchRSSFeed(rssSource.url)
    const currentCount = await processRSSItems(supabaseClient, currentFeed.items, rssSourceId, cutoffDate)
    totalProcessed += currentCount

    // Try common archive patterns for better backfill
    const archiveUrls = generateArchiveUrls(rssSource.url, rssSource.name)
    
    for (const archiveUrl of archiveUrls) {
      try {
        console.log(`Attempting to fetch archive: ${archiveUrl}`)
        const archiveFeed = await fetchRSSFeed(archiveUrl)
        const archiveCount = await processRSSItems(supabaseClient, archiveFeed.items, rssSourceId, cutoffDate)
        totalProcessed += archiveCount
        
        // Add delay to respect rate limits
        await new Promise(resolve => setTimeout(resolve, 1000))
      } catch (error) {
        console.log(`Archive fetch failed for ${archiveUrl}:`, error.message)
        continue
      }
    }

    // Update source metadata
    await supabaseClient
      .from('rss_sources')
      .update({ 
        last_fetched: new Date().toISOString(),
        fetch_interval: 3600, // Reset to hourly after backfill
        avg_engagement_score: await calculateSourceEngagement(supabaseClient, rssSourceId)
      })
      .eq('id', rssSourceId)

    return new Response(
      JSON.stringify({ 
        success: true, 
        totalProcessed,
        rssSourceId,
        backfillComplete: true
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )

  } catch (error) {
    console.error('Backfill error:', error)
    throw error
  }
}

function generateArchiveUrls(baseUrl: string, sourceName: string): string[] {
  const urls: string[] = []
  const currentYear = new Date().getFullYear()
  const currentMonth = new Date().getMonth() + 1
  
  // Generate URLs for past 12 months
  for (let i = 0; i < 12; i++) {
    let year = currentYear
    let month = currentMonth - i
    
    if (month <= 0) {
      month += 12
      year -= 1
    }
    
    const monthStr = month.toString().padStart(2, '0')
    
    // Enhanced archive patterns for more tech blogs
    if (baseUrl.includes('aws.amazon.com')) {
      urls.push(`https://aws.amazon.com/blogs/machine-learning/feed/?m=${year}${monthStr}`)
    } else if (baseUrl.includes('cloud.google.com')) {
      urls.push(`${baseUrl}?m=${year}${monthStr}`)
    } else if (baseUrl.includes('azure.microsoft.com')) {
      urls.push(`${baseUrl}?m=${year}${monthStr}`)
    } else if (baseUrl.includes('netflixtechblog.com')) {
      urls.push(`${baseUrl}?m=${year}${monthStr}`)
    } else if (baseUrl.includes('blog.google')) {
      urls.push(`${baseUrl}?published-min=${year}-${monthStr}-01&published-max=${year}-${monthStr}-31`)
    }
  }
  
  return urls.filter((url, index, arr) => arr.indexOf(url) === index) // Remove duplicates
}

function cleanText(text: string): string {
  return text
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/<[^>]*>/g, '')
    .trim()
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
          content: `Extract 2-4 key technical topics from this content. Choose from these categories: Machine Learning, Cloud Computing, Cybersecurity, Blockchain, Data Visualization, ETL Pipelines, Causal Inference, Quantum Computing, Augmented Reality, Bioinformatics. Return only a JSON array of topic names: ${content.substring(0, 1500)}`
        }]
      }),
    })

    const data = await response.json()
    const topicsStr = data.content[0]?.text || '[]'
    const topics = JSON.parse(topicsStr)
    return Array.isArray(topics) ? topics.slice(0, 4) : []
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
          content: `Assess the technical difficulty of this content for software professionals. Return only one word: "beginner", "intermediate", or "advanced": ${content.substring(0, 1000)}`
        }]
      }),
    })

    const data = await response.json()
    const difficulty = data.content[0]?.text?.toLowerCase()?.trim() || 'medium'
    return ['beginner', 'intermediate', 'advanced'].includes(difficulty) ? difficulty : 'intermediate'
  } catch (error) {
    console.error('Difficulty assessment failed:', error)
    return 'intermediate'
  }
}