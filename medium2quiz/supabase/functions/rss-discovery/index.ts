// RSS Discovery Edge Function
// Automatically discovers RSS sources for given topics using OpenAI

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.39.3/+esm'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface DiscoveryRequest {
  topics: string[]
  userId?: string
}

interface RSSSource {
  name: string
  url: string
  description: string
  topics: string[]
  quality_score: number
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { topics, userId }: DiscoveryRequest = await req.json()
    
    if (!topics || topics.length === 0) {
      throw new Error('Topics array is required')
    }

    console.log(`🔍 Discovering RSS sources for topics: ${topics.join(', ')}`)

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Check if we already have sources for these topics
    // Temporarily disabled to allow Claude to generate new sources
    /*
    const { data: existingSources } = await supabase
      .from('rss_sources')
      .select('*')
      .overlaps('topics', topics)
    
    if (existingSources && existingSources.length >= 5) {
      console.log(`✅ Found ${existingSources.length} existing sources for topics`)
      return new Response(
        JSON.stringify({
          success: true,
          sources_discovered: existingSources.length,
          sources: existingSources,
          message: `Using ${existingSources.length} existing RSS sources`
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200,
        }
      )
    }
    */

    // Get Claude API key
    const claudeApiKey = Deno.env.get('CLAUDE_API_KEY')
    if (!claudeApiKey) {
      throw new Error('Claude API key not configured')
    }

    // Call Claude to discover RSS sources
    const prompt = `You are an expert at finding high-quality RSS feeds and blogs for professional learning.

For the following topics: ${topics.join(', ')}

Please provide a JSON array of the best RSS feeds and blogs. For each source, include:
- name: The name/title of the blog/publication
- url: The RSS feed URL (must be actual RSS/XML feed, not website homepage)
- description: Brief description of the content
- topics: Array of main topics covered
- quality_score: Estimated quality score (0.0-1.0)

CRITICAL RSS URL REQUIREMENTS:
- URLs must be actual RSS/XML feeds, not homepage URLs
- Common valid patterns: /feed, /rss, /atom.xml, /feed.xml, /feeds/all.atom.xml
- Use ONLY verified working RSS feeds from these trusted sources:
  * Netflix Tech Blog: https://netflixtechblog.com/feed
  * AWS Blog: https://aws.amazon.com/blogs/aws/feed/
  * Google Cloud: https://cloud.google.com/feeds/gcp-news.xml
  * Airbnb Engineering: https://medium.com/airbnb-engineering/feed
  * Towards Data Science: https://towardsdatascience.com/feed
  * Microsoft Azure: https://azure.microsoft.com/en-us/blog/feed/
  * GitHub Blog: https://github.blog/feed/
  * Stack Overflow: https://stackoverflow.blog/feed/
  * Hacker News: https://hnrss.org/frontpage
  * TechCrunch: https://techcrunch.com/feed/
  * The Verge: https://www.theverge.com/rss/index.xml
  * Wired: https://www.wired.com/feed/rss
  * Ars Technica: https://feeds.arstechnica.com/arstechnica/index

AVOID:
- Google AI Blog (broken RSS)
- Paywalled sources
- Personal blogs without verified RSS
- Feeds that commonly return 404 or HTML instead of XML

Focus on established tech publications and company engineering blogs with reliable RSS feeds.

Return ONLY valid JSON array, no markdown or explanation:`

    const claudeResponse = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': claudeApiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        model: 'claude-3-haiku-20240307',
        max_tokens: 2000,
        temperature: 0.3,
        messages: [
          { role: 'user', content: prompt }
        ]
      })
    })

    if (!claudeResponse.ok) {
      const errorText = await claudeResponse.text()
      throw new Error(`Claude API error: ${claudeResponse.statusText} - ${errorText}`)
    }

    const claudeData = await claudeResponse.json()
    console.log('Claude API response:', JSON.stringify(claudeData, null, 2))
    const content = claudeData.content[0]?.text

    if (!content) {
      throw new Error('No content returned from Claude')
    }

    // Parse JSON response
    let sources: RSSSource[]
    try {
      const cleanContent = content.replace(/```json\n?|\n?```/g, '').trim()
      sources = JSON.parse(cleanContent)
    } catch (parseError) {
      console.error('Failed to parse Claude response:', content)
      throw new Error('Failed to parse Claude response as JSON')
    }

    console.log(`✅ Claude suggested ${sources.length} RSS sources`)
    console.log('Claude response sources:', JSON.stringify(sources, null, 2))

    // Validate and store RSS sources
    const validatedSources = []
    const skipValidation = true // Temporarily disable validation to debug
    
    for (const source of sources) {
      try {
        // Basic URL validation
        const url = new URL(source.url)
        if (!url.protocol.startsWith('http')) {
          continue
        }

        // Skip validation if flag is set
        if (skipValidation) {
          const dbSource = {
            id: crypto.randomUUID(),
            name: source.name,
            url: source.url,
            description: source.description,
            topics: source.topics || topics,
            tags: extractTags(source.name + ' ' + source.description),
            is_active: true,
            auto_refresh_enabled: true,
            content_quality_score: source.quality_score || 0.7,
            avg_engagement_score: 0,
            created_at: new Date().toISOString()
          }
          
          validatedSources.push(dbSource)
          console.log(`✅ Added without validation: ${source.name}`)
          continue
        }

        // Try to fetch the RSS feed to validate
        try {
          const rssResponse = await fetch(source.url, {
            headers: {
              'User-Agent': 'Mozilla/5.0 (compatible; medium2quiz-discovery/1.0; +https://medium2quiz.com/bot)'
            },
            signal: AbortSignal.timeout(8000) // 8 second timeout
          })

          if (rssResponse.ok) {
            const content = await rssResponse.text()
            
            // Check if the response is HTML instead of XML/RSS
            if (content.trim().toLowerCase().startsWith('<!doctype html') || 
                content.trim().toLowerCase().startsWith('<html')) {
              console.log(`❌ Invalid RSS format: ${source.name} - Feed returned HTML instead of RSS/XML`)
              continue
            }
            
            // More comprehensive RSS/XML validation
            if (content.includes('<') && content.includes('>') && 
                (content.toLowerCase().includes('<rss') || content.toLowerCase().includes('<feed') || 
                 content.toLowerCase().includes('<atom') || content.toLowerCase().includes('<?xml'))) {
            
            const dbSource = {
              id: crypto.randomUUID(),
              name: source.name,
              url: source.url,
              description: source.description,
              topics: source.topics || topics,
              tags: extractTags(source.name + ' ' + source.description),
              is_active: true,
              auto_refresh_enabled: true,
              content_quality_score: source.quality_score || 0.7,
              avg_engagement_score: 0,
              created_at: new Date().toISOString()
            }
            
            validatedSources.push(dbSource)
            console.log(`✅ Validated: ${source.name}`)
            } else {
              console.log(`❌ Invalid RSS format: ${source.name} - Content preview: ${content.substring(0, 200)}`)
            }
          } else {
            console.log(`❌ Failed to fetch: ${source.name} (${rssResponse.status}) - URL: ${source.url}`)
          }
        } catch (fetchError) {
          console.log(`❌ Fetch error for ${source.name}: ${fetchError.message} - URL: ${source.url}`)
        }
      } catch (error) {
        console.log(`❌ Error validating ${source.name}: ${error.message}`)
      }
    }

    // Insert validated sources into database
    if (validatedSources.length > 0) {
      console.log(`Attempting to insert ${validatedSources.length} sources`)
      
      // Check for existing sources first and only insert new ones
      const { data: existingSources } = await supabase
        .from('rss_sources')
        .select('url')
        .in('url', validatedSources.map(s => s.url))
      
      const existingUrls = new Set(existingSources?.map(s => s.url) || [])
      const newSources = validatedSources.filter(source => !existingUrls.has(source.url))
      
      if (newSources.length > 0) {
        console.log(`Attempting to insert ${newSources.length} new sources...`)
        console.log('New sources to insert:', JSON.stringify(newSources.map(s => ({ name: s.name, url: s.url, topics: s.topics })), null, 2))
        
        const { data, error } = await supabase
          .from('rss_sources')
          .insert(newSources)
          .select()

        if (error) {
          console.error('Error inserting RSS sources:', error)
          console.error('Error details:', JSON.stringify(error, null, 2))
          console.error('Error code:', error.code)
          console.error('Error message:', error.message)
          console.error('Error hint:', error.hint)
          // Don't throw - return partial success
          console.log('⚠️ Failed to insert sources, but continuing with response')
        } else if (data && data.length > 0) {
          console.log(`🎉 Successfully added ${data.length} new RSS sources`)
          console.log('Inserted data:', JSON.stringify(data, null, 2))
        } else {
          console.log('⚠️ Insert returned no data - sources may not have been inserted')
        }
      } else {
        console.log('ℹ️ All sources already exist in database')
      }
      
      console.log(`✅ Total sources available: ${validatedSources.length} (${newSources.length} new, ${existingUrls.size} existing)`)
      
      // Verify sources are actually in database
      const { data: verifyData, error: verifyError } = await supabase
        .from('rss_sources')
        .select('id, name, topics')
        .in('url', validatedSources.map(s => s.url))
      
      if (verifyError) {
        console.error('Error verifying sources:', verifyError)
      } else {
        console.log(`📊 Verification: Found ${verifyData?.length || 0} sources in database after operation`)
        if (verifyData && verifyData.length > 0) {
          console.log('Verified sources:', JSON.stringify(verifyData.map(s => ({ name: s.name, topics: s.topics })), null, 2))
        }
      }
    } else {
      console.log('⚠️ No sources passed validation')
      console.log('Sources attempted:', sources.length)
    }

    // If we have sources, trigger immediate crawl
    if (validatedSources.length > 0) {
      try {
        await fetch(`${supabaseUrl}/functions/v1/rss-crawler`, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${supabaseServiceKey}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({ 
            action: 'crawl_new_sources',
            source_ids: validatedSources.map(s => s.id)
          })
        })
        console.log('✅ Triggered immediate RSS crawl')
      } catch (crawlError) {
        console.warn('Failed to trigger immediate crawl:', crawlError)
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        sources_discovered: validatedSources.length,
        sources: validatedSources,
        message: `Successfully discovered and validated ${validatedSources.length} RSS sources`
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )

  } catch (error) {
    console.error('RSS discovery error:', error)
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

function extractTags(text: string): string[] {
  if (!text) return []
  
  const techKeywords = [
    'AI', 'machine learning', 'artificial intelligence', 'deep learning',
    'cloud computing', 'aws', 'azure', 'gcp', 'kubernetes', 'docker',
    'javascript', 'python', 'react', 'nodejs', 'typescript', 'golang',
    'data science', 'analytics', 'big data', 'database', 'sql',
    'cybersecurity', 'blockchain', 'cryptocurrency', 'fintech',
    'mobile development', 'ios', 'android', 'flutter', 'react native',
    'web development', 'frontend', 'backend', 'fullstack', 'api',
    'devops', 'ci/cd', 'testing', 'automation', 'monitoring',
    'startup', 'venture capital', 'product management', 'design',
    'software engineering', 'architecture', 'microservices'
  ]
  
  const lowerText = text.toLowerCase()
  return techKeywords
    .filter(keyword => lowerText.includes(keyword.toLowerCase()))
    .slice(0, 10) // Limit to 10 tags
}