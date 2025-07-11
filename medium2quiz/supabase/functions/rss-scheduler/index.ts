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
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '', // Use service role for cron jobs
    )

    const { action = 'process_scheduled_feeds' } = await req.json().catch(() => ({}))

    switch (action) {
      case 'process_scheduled_feeds':
        return await processScheduledRSSFeeds(supabaseClient)
      case 'update_single_feed':
        const { rss_source_id } = await req.json()
        return await updateSingleFeed(supabaseClient, rss_source_id)
      case 'cleanup_old_data':
        return await cleanupOldData(supabaseClient)
      case 'update_user_patterns':
        return await updateUserReadingPatterns(supabaseClient)
      default:
        throw new Error('Invalid action')
    }

  } catch (error) {
    console.error('RSS scheduler error:', error)
    
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      },
    )
  }
})

async function processScheduledRSSFeeds(supabaseClient: any) {
  const startTime = Date.now()
  
  // Get all active RSS sources due for refresh
  const { data: dueSources, error: sourcesError } = await supabaseClient
    .from('rss_sources')
    .select(`
      id,
      name,
      url,
      fetch_interval,
      last_fetched,
      auto_refresh_enabled,
      content_quality_score,
      avg_engagement_score
    `)
    .eq('is_active', true)
    .eq('auto_refresh_enabled', true)
    .or(`last_fetched.is.null,last_fetched.lt.${new Date(Date.now() - 3600000).toISOString()}`) // Due for refresh

  if (sourcesError) {
    console.error('Error fetching due sources:', sourcesError)
    throw sourcesError
  }

  console.log(`Found ${dueSources.length} RSS sources due for refresh`)

  let processedSources = 0
  let totalArticlesProcessed = 0
  let totalUsersImpacted = 0

  // Process sources in priority order
  const prioritizedSources = dueSources.sort((a, b) => {
    const aPriority = (a.content_quality_score || 0) + (a.avg_engagement_score || 0)
    const bPriority = (b.content_quality_score || 0) + (b.avg_engagement_score || 0)
    return bPriority - aPriority
  })

  // Process each RSS source
  for (const source of prioritizedSources) {
    try {
      console.log(`Processing RSS source: ${source.name}`)
      
      // Call the RSS processor function to fetch and process articles
      const response = await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/rss-processor`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${Deno.env.get('SUPABASE_ANON_KEY')}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          action: 'fetch_feed',
          rss_source_id: source.id
        })
      })

      if (response.ok) {
        const result = await response.json()
        console.log(`Processed ${result.processedCount} articles for ${source.name}`)
        totalArticlesProcessed += result.processedCount || 0
        processedSources++

        // Update user schedules and auto-queue high-scoring articles
        const usersImpacted = await processUserSchedulesForSource(supabaseClient, source.id)
        totalUsersImpacted += usersImpacted

      } else {
        console.error(`Failed to process RSS source ${source.name}:`, await response.text())
        
        // Update source failure count
        await supabaseClient
          .from('rss_sources')
          .update({
            last_fetched: new Date().toISOString(),
            consecutive_failures: 'COALESCE(consecutive_failures, 0) + 1'
          })
          .eq('id', source.id)
      }

      // Dynamic delay based on source quality and system load
      const delay = calculateProcessingDelay(source, processedSources)
      await new Promise(resolve => setTimeout(resolve, delay))

    } catch (error) {
      console.error(`Error processing RSS source ${source.name}:`, error.message)
      continue
    }
  }

  // Update RSS source engagement scores based on recent activity
  await updateSourceEngagementScores(supabaseClient)

  // Clean up old/inactive feed schedules
  await cleanupFeedSchedules(supabaseClient)

  // Update system performance metrics
  await updateSystemMetrics(supabaseClient, {
    processedSources,
    totalArticlesProcessed,
    totalUsersImpacted,
    processingTime: Date.now() - startTime,
    timestamp: new Date().toISOString()
  })

  return new Response(
    JSON.stringify({ 
      success: true,
      processedSources,
      totalArticlesProcessed,
      totalUsersImpacted,
      processingTimeMs: Date.now() - startTime
    }),
    {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    }
  )
}

async function processUserSchedulesForSource(supabaseClient: any, rssSourceId: string): Promise<number> {
  try {
    // Get users subscribed to this RSS source
    const { data: subscribers, error: subError } = await supabaseClient
      .from('user_rss_feeds')
      .select(`
        user_id,
        affinity_score,
        subscription_strength,
        users!inner (
          id,
          preferred_difficulty,
          daily_study_goal
        )
      `)
      .eq('rss_source_id', rssSourceId)
      .eq('is_active', true)
      .gte('affinity_score', 1.0) // Only process users with positive affinity

    if (subError || !subscribers.length) return 0

    // Process articles for each user
    for (const subscriber of subscribers) {
      // Get or create feed schedule for this user-source combination
      await ensureUserFeedSchedule(supabaseClient, subscriber.user_id, rssSourceId, subscriber.affinity_score)
      
      // Auto-queue high-scoring articles for this user
      await autoQueueArticlesForUser(supabaseClient, subscriber.user_id, rssSourceId)
    }

    return subscribers.length

  } catch (error) {
    console.error(`Error processing user schedules for source ${rssSourceId}:`, error.message)
    return 0
  }
}

async function ensureUserFeedSchedule(supabaseClient: any, userId: string, rssSourceId: string, affinityScore: number) {
  try {
    // Calculate optimal fetch frequency based on user engagement
    const frequency = calculateOptimalFetchFrequency(affinityScore)
    const priority = Math.min(5.0, Math.max(0.1, affinityScore))

    // Upsert user feed schedule
    await supabaseClient
      .from('rss_fetch_schedule')
      .upsert({
        user_id: userId,
        rss_source_id: rssSourceId,
        next_fetch_time: new Date().toISOString(),
        fetch_frequency: frequency,
        priority_score: priority,
        is_active: true,
        consecutive_failures: 0
      }, { onConflict: 'user_id,rss_source_id' })

  } catch (error) {
    console.error(`Error ensuring feed schedule for user ${userId}:`, error.message)
  }
}

async function autoQueueArticlesForUser(supabaseClient: any, userId: string, rssSourceId: string) {
  try {
    // Get recent unqueued articles from this source
    const { data: articles, error: articlesError } = await supabaseClient
      .from('articles')
      .select('id, title, topics, difficulty_level, published_date, content_quality_score')
      .eq('rss_source_id', rssSourceId)
      .gte('published_date', new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString()) // Last 7 days
      .order('published_date', { ascending: false })
      .limit(10)

    if (articlesError || !articles.length) return

    // Get user's reading patterns for scoring
    const { data: userPattern } = await supabaseClient
      .from('user_reading_patterns')
      .select('*')
      .eq('user_id', userId)
      .single()

    let queuedCount = 0

    for (const article of articles) {
      // Check if already queued
      const { data: existingQueue } = await supabaseClient
        .from('user_articles')
        .select('id')
        .eq('user_id', userId)
        .eq('article_id', article.id)
        .single()

      if (existingQueue) continue

      // Calculate article score for this user
      const score = await calculatePersonalizedArticleScore(article, userPattern)
      
      // Auto-queue if score meets threshold
      if (score > 0.65) {
        await supabaseClient
          .from('user_articles')
          .insert({
            user_id: userId,
            article_id: article.id,
            status: 'queued',
            personalized_score: score,
            preference_score: 0,
            queued_at: new Date().toISOString()
          })

        queuedCount++
      }
    }

    console.log(`Auto-queued ${queuedCount} articles for user ${userId}`)

  } catch (error) {
    console.error(`Error auto-queuing articles for user ${userId}:`, error.message)
  }
}

async function calculatePersonalizedArticleScore(article: any, userPattern: any): Promise<number> {
  let score = 0.5 // Base score

  // Topic relevance
  if (userPattern?.preferred_topics && article.topics) {
    const matchingTopics = article.topics.filter((topic: string) => 
      userPattern.preferred_topics.includes(topic)
    ).length
    const topicRelevance = matchingTopics / Math.max(article.topics.length, 1)
    score += topicRelevance * 0.4
  }

  // Difficulty match
  if (userPattern?.optimal_difficulty_level && article.difficulty_level) {
    if (article.difficulty_level === userPattern.optimal_difficulty_level) {
      score += 0.3
    } else if (
      (article.difficulty_level === 'beginner' && userPattern.optimal_difficulty_level === 'intermediate') ||
      (article.difficulty_level === 'intermediate' && ['beginner', 'advanced'].includes(userPattern.optimal_difficulty_level)) ||
      (article.difficulty_level === 'advanced' && userPattern.optimal_difficulty_level === 'intermediate')
    ) {
      score += 0.2
    }
  }

  // Content quality
  if (article.content_quality_score) {
    score += article.content_quality_score * 0.2
  }

  // Freshness (favor recent articles)
  if (article.published_date) {
    const hoursOld = (Date.now() - new Date(article.published_date).getTime()) / (1000 * 60 * 60)
    const freshness = Math.max(0, 1 - (hoursOld / (7 * 24))) // Decay over 7 days
    score += freshness * 0.1
  }

  return Math.min(1.0, Math.max(0.0, score))
}

async function updateSourceEngagementScores(supabaseClient: any) {
  try {
    console.log('Updating RSS source engagement scores...')

    const { data: sources, error: sourcesError } = await supabaseClient
      .from('rss_sources')
      .select('id, name')
      .eq('is_active', true)

    if (sourcesError) throw sourcesError

    for (const source of sources) {
      // Calculate engagement metrics from the last 30 days
      const { data: metrics, error: metricsError } = await supabaseClient
        .rpc('calculate_source_engagement', { source_id: source.id })

      if (!metricsError && metrics) {
        await supabaseClient
          .from('rss_sources')
          .update({ avg_engagement_score: metrics })
          .eq('id', source.id)
      }
    }

    console.log(`Updated engagement scores for ${sources.length} sources`)

  } catch (error) {
    console.error('Error updating source engagement scores:', error.message)
  }
}

async function cleanupFeedSchedules(supabaseClient: any) {
  try {
    console.log('Cleaning up inactive feed schedules...')

    // Remove schedules for inactive RSS sources
    await supabaseClient
      .from('rss_fetch_schedule')
      .delete()
      .in('rss_source_id', 
        supabaseClient
          .from('rss_sources')
          .select('id')
          .eq('is_active', false)
      )

    // Deactivate schedules with too many consecutive failures
    await supabaseClient
      .from('rss_fetch_schedule')
      .update({ is_active: false })
      .gte('consecutive_failures', 5)

    // Remove schedules for users who haven't been active recently
    await supabaseClient
      .from('rss_fetch_schedule')
      .delete()
      .in('user_id',
        supabaseClient
          .from('users')
          .select('id')
          .lt('last_study_date', new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString())
      )

    console.log('Feed schedule cleanup completed')

  } catch (error) {
    console.error('Error during feed schedule cleanup:', error.message)
  }
}

async function cleanupOldData(supabaseClient: any) {
  try {
    console.log('Starting old data cleanup...')

    // Clean up old articles (keep starred and recent)
    await supabaseClient
      .from('articles')
      .delete()
      .lt('created_at', new Date(Date.now() - 6 * 30 * 24 * 60 * 60 * 1000).toISOString()) // 6 months
      .not('id', 'in', 
        supabaseClient
          .from('user_articles')
          .select('article_id')
          .eq('is_starred', true)
      )

    // Clean up old study sessions (keep recent performance data)
    await supabaseClient
      .from('study_sessions')
      .delete()
      .lt('started_at', new Date(Date.now() - 3 * 30 * 24 * 60 * 60 * 1000).toISOString()) // 3 months
      .eq('is_completed', true)

    // Archive old quiz performance data for mastered cards
    await supabaseClient
      .from('user_quiz_performance')
      .delete()
      .eq('review_stage', 3) // Mastered
      .lt('last_studied', new Date(Date.now() - 6 * 30 * 24 * 60 * 60 * 1000).toISOString()) // 6 months
      .gte('mastery_level', 0.95)

    console.log('Old data cleanup completed')

    return new Response(
      JSON.stringify({ success: true, message: 'Old data cleanup completed' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error during data cleanup:', error.message)
    throw error
  }
}

async function updateUserReadingPatterns(supabaseClient: any) {
  try {
    console.log('Updating user reading patterns...')

    // Update reading patterns based on recent activity
    await supabaseClient.rpc('update_all_user_patterns')

    console.log('User reading patterns updated')

    return new Response(
      JSON.stringify({ success: true, message: 'User reading patterns updated' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error updating user reading patterns:', error.message)
    throw error
  }
}

async function updateSingleFeed(supabaseClient: any, rssSourceId: string) {
  try {
    const response = await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/rss-processor`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('SUPABASE_ANON_KEY')}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        action: 'fetch_feed',
        rss_source_id: rssSourceId
      })
    })

    const result = await response.json()

    return new Response(
      JSON.stringify({
        success: true,
        result,
        message: 'RSS feed updated successfully'
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    throw new Error(`Failed to update feed ${rssSourceId}: ${error.message}`)
  }
}

async function updateSystemMetrics(supabaseClient: any, metrics: any) {
  try {
    // Log metrics for monitoring
    console.log('RSS Scheduler Metrics:', metrics)

    // Store in system metrics table if it exists
    await supabaseClient
      .from('system_metrics')
      .insert({
        metric_type: 'rss_scheduler_run',
        metric_data: metrics,
        created_at: new Date().toISOString()
      })
      .onConflict('metric_type,created_at')

  } catch (error) {
    // If system_metrics table doesn't exist, just log
    console.log('Could not store system metrics (table may not exist):', error.message)
  }
}

// Helper functions

function calculateOptimalFetchFrequency(affinityScore: number): number {
  const baseFrequency = 3600 // 1 hour in seconds
  
  // High affinity users get more frequent updates
  if (affinityScore >= 4.0) return 1800 // 30 minutes
  if (affinityScore >= 3.0) return 2700 // 45 minutes
  if (affinityScore >= 2.0) return 3600 // 1 hour
  if (affinityScore >= 1.0) return 7200 // 2 hours
  
  return 14400 // 4 hours for low affinity
}

function calculateProcessingDelay(source: any, processedCount: number): number {
  const baseDelay = 200 // 200ms base delay
  const qualityMultiplier = (source.content_quality_score || 0.5)
  const loadMultiplier = Math.min(2.0, processedCount / 10) // Increase delay as we process more
  
  return Math.round(baseDelay * (2 - qualityMultiplier) * (1 + loadMultiplier))
}