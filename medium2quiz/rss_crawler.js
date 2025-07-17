// RSS Crawler Script for medium2quiz
// Run with: node rss_crawler.js

const Parser = require('rss-parser');
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const parser = new Parser({
  customFields: {
    item: ['guid', 'pubDate', 'description', 'content:encoded']
  }
});

// Initialize Supabase client
const supabaseUrl = process.env.SUPABASE_URL || 'https://fjswkvgochsdmcqeaexc.supabase.co';
const supabaseKey = process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZqc3drdmdvY2hzZG1jcWVhZXhjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE0OTI5NjMsImV4cCI6MjA2NzA2ODk2M30.OsvnIZE9TX6qzqzeAjdaa9988Bg2aUhBw23761K3n8U';

const supabase = createClient(supabaseUrl, supabaseKey);

async function crawlRSSSource(source) {
  try {
    console.log(`🔍 Crawling: ${source.name} (${source.url})`);
    
    const feed = await parser.parseURL(source.url);
    const articles = [];

    for (const item of feed.items.slice(0, 10)) { // Limit to 10 most recent
      const article = {
        id: require('crypto').randomUUID(),
        title: item.title?.trim() || '',
        url: item.link || '',
        content: item['content:encoded'] || item.description || item.summary || '',
        summary: item.description?.substring(0, 300) || '',
        author: item.creator || item.author || 'Unknown',
        source_type: 'rss',
        rss_source_id: source.id,
        topics: source.topics || [],
        tags: extractTags(item.title + ' ' + item.description),
        published_date: new Date(item.pubDate || item.isoDate || Date.now()),
        relevance_score: await calculateRelevanceScore(item, source),
        engagement_score: 0,
        freshness_score: calculateFreshnessScore(item.pubDate),
        content_quality_score: calculateQualityScore(item),
        created_at: new Date()
      };

      if (article.title && article.url && article.content.length > 100) {
        articles.push(article);
      }
    }

    // Insert articles into database
    if (articles.length > 0) {
      const { data, error } = await supabase
        .from('articles')
        .upsert(articles, { onConflict: 'url' });

      if (error) {
        console.error(`❌ Error inserting articles for ${source.name}:`, error.message);
      } else {
        console.log(`✅ Inserted ${articles.length} articles from ${source.name}`);
      }
    }

    // Update RSS source last_fetched timestamp
    await supabase
      .from('rss_sources')
      .update({ 
        last_fetched: new Date().toISOString(),
        content_quality_score: articles.length > 0 ? 0.8 : 0.3
      })
      .eq('id', source.id);

    return articles;

  } catch (error) {
    console.error(`❌ Failed to crawl ${source.name}:`, error.message);
    
    // Update source with error info
    await supabase
      .from('rss_sources')
      .update({ 
        last_fetched: new Date().toISOString(),
        is_active: false // Disable problematic sources
      })
      .eq('id', source.id);
    
    return [];
  }
}

function extractTags(text) {
  if (!text) return [];
  
  const commonTags = [
    'AI', 'machine learning', 'cloud', 'kubernetes', 'docker', 'aws', 'azure', 'gcp',
    'javascript', 'python', 'react', 'nodejs', 'typescript', 'golang', 'rust',
    'devops', 'security', 'blockchain', 'crypto', 'startup', 'fintech',
    'data science', 'analytics', 'database', 'api', 'microservices'
  ];
  
  const lowerText = text.toLowerCase();
  return commonTags.filter(tag => lowerText.includes(tag.toLowerCase()));
}

async function calculateRelevanceScore(item, source) {
  let score = 0.5; // Base score
  
  try {
    // Use AI to determine content relevance to the source topics
    const claudeKey = process.env.CLAUDE_API_KEY;
    if (claudeKey && source.topics && source.topics.length > 0) {
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
            content: `Rate the relevance of this article to these topics: ${source.topics.join(', ')}.
            Article title: ${item.title}
            Article description: ${(item.description || '').substring(0, 500)}
            
            Return only a number between 0 and 1, where 1 is highly relevant and 0 is not relevant.`
          }]
        }),
      });

      if (response.ok) {
        const data = await response.json();
        const aiScore = parseFloat(data.content[0]?.text?.trim() || '0.5');
        score = isNaN(aiScore) ? 0.5 : Math.min(1.0, Math.max(0.0, aiScore));
      }
    }
    
    // Adjust for recency (but with less weight than content relevance)
    const daysSincePublished = (Date.now() - new Date(item.pubDate)) / (1000 * 60 * 60 * 24);
    let recencyBonus = 0;
    if (daysSincePublished < 1) recencyBonus = 0.2;
    else if (daysSincePublished < 7) recencyBonus = 0.1;
    else if (daysSincePublished < 30) recencyBonus = 0.05;
    
    // Combine AI relevance score with recency
    score = score * 0.8 + recencyBonus * 0.2; // 80% content relevance, 20% recency
    
  } catch (error) {
    console.error('Error calculating AI relevance score:', error.message);
    // Fallback to basic scoring if AI fails
    const daysSincePublished = (Date.now() - new Date(item.pubDate)) / (1000 * 60 * 60 * 24);
    if (daysSincePublished < 7) score += 0.1;
  }
  
  return Math.min(score, 1.0);
}

function calculateFreshnessScore(pubDate) {
  if (!pubDate) return 0.1;
  
  const daysSincePublished = (Date.now() - new Date(pubDate)) / (1000 * 60 * 60 * 24);
  
  if (daysSincePublished < 1) return 1.0;
  if (daysSincePublished < 3) return 0.8;
  if (daysSincePublished < 7) return 0.6;
  if (daysSincePublished < 30) return 0.4;
  return 0.2;
}

function calculateQualityScore(item) {
  let score = 0.5;
  
  // Title quality
  if (item.title && item.title.length > 10 && item.title.length < 100) score += 0.1;
  
  // Content quality
  const content = item['content:encoded'] || item.description || '';
  if (content.length > 200) score += 0.1;
  if (content.length > 1000) score += 0.1;
  
  // Has author
  if (item.creator || item.author) score += 0.1;
  
  // Not too old
  const daysSincePublished = (Date.now() - new Date(item.pubDate)) / (1000 * 60 * 60 * 24);
  if (daysSincePublished < 30) score += 0.1;
  
  return Math.min(score, 1.0);
}

async function crawlAllSources() {
  try {
    console.log('🚀 Starting RSS crawl...');
    
    // Get all active RSS sources
    const { data: sources, error } = await supabase
      .from('rss_sources')
      .select('*')
      .eq('is_active', true);

    if (error) {
      console.error('❌ Error fetching RSS sources:', error.message);
      return;
    }

    if (!sources || sources.length === 0) {
      console.log('⚠️ No active RSS sources found. Please run the database setup first.');
      return;
    }

    console.log(`📡 Found ${sources.length} RSS sources to crawl`);
    
    let totalArticles = 0;
    
    // Crawl sources sequentially to avoid overwhelming servers
    for (const source of sources) {
      const articles = await crawlRSSSource(source);
      totalArticles += articles.length;
      
      // Wait between requests to be respectful
      await new Promise(resolve => setTimeout(resolve, 1000));
    }
    
    console.log(`🎉 Crawl complete! Total articles fetched: ${totalArticles}`);
    
    if (totalArticles === 0) {
      console.error('❌ WARNING: No articles were successfully fetched! Check RSS source URLs and network connectivity.');
      process.exit(1);
    }
    
  } catch (error) {
    console.error('❌ Crawl failed:', error.message);
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  crawlAllSources();
}

module.exports = { crawlAllSources, crawlRSSSource };