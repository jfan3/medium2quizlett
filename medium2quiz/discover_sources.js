// Dynamic RSS Source Discovery using OpenAI + Web Search
// Run with: node discover_sources.js

const OpenAI = require('openai');
const axios = require('axios');
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

// Initialize clients
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
});

const supabaseUrl = process.env.SUPABASE_URL || 'https://fjswkvgochsdmcqeaexc.supabase.co';
const supabaseKey = process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZqc3drdmdvY2hzZG1jcWVhZXhjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE0OTI5NjMsImV4cCI6MjA2NzA2ODk2M30.OsvnIZE9TX6qzqzeAjdaa9988Bg2aUhBw23761K3n8U';

const supabase = createClient(supabaseUrl, supabaseKey);

async function discoverRSSSources(topics) {
  console.log(`🔍 Discovering RSS sources for topics: ${topics.join(', ')}`);
  
  try {
    const prompt = `You are an expert at finding high-quality RSS feeds and blogs for professional learning.

For the following topics: ${topics.join(', ')}

Please provide a JSON array of the best RSS feeds and blogs. For each source, include:
- name: The name/title of the blog/publication
- url: The RSS feed URL (must be actual RSS/XML feed, not website homepage)
- description: Brief description of the content
- topics: Array of main topics covered
- quality_score: Estimated quality score (0.0-1.0)

Focus on:
- High-quality technical blogs (Google, Netflix, Uber, Airbnb, etc.)
- Reputable news sources and industry publications
- Well-known developer/engineering blogs
- Official company engineering blogs
- Popular newsletter RSS feeds

Ensure all URLs are valid RSS/XML feeds that can be parsed.

Return ONLY valid JSON array, no markdown or explanation:`;

    const response = await openai.chat.completions.create({
      model: "gpt-4",
      messages: [{ role: "user", content: prompt }],
      temperature: 0.3,
      max_tokens: 2000
    });

    const content = response.choices[0].message.content.trim();
    
    // Parse JSON response
    let sources;
    try {
      // Remove markdown formatting if present
      const jsonStr = content.replace(/```json\n?|\n?```/g, '').trim();
      sources = JSON.parse(jsonStr);
    } catch (parseError) {
      console.error('❌ Failed to parse OpenAI response as JSON:', parseError.message);
      console.log('Raw response:', content);
      return [];
    }

    console.log(`✅ OpenAI suggested ${sources.length} RSS sources`);

    // Validate and verify RSS feeds
    const validatedSources = [];
    for (const source of sources) {
      if (await validateRSSFeed(source.url)) {
        const dbSource = {
          id: require('crypto').randomUUID(),
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
        };
        
        validatedSources.push(dbSource);
        console.log(`✅ Validated: ${source.name}`);
      } else {
        console.log(`❌ Invalid RSS feed: ${source.name} (${source.url})`);
      }
    }

    // Insert into database
    if (validatedSources.length > 0) {
      const { data, error } = await supabase
        .from('rss_sources')
        .upsert(validatedSources, { onConflict: 'url' });

      if (error) {
        console.error('❌ Error inserting RSS sources:', error.message);
      } else {
        console.log(`🎉 Successfully added ${validatedSources.length} RSS sources to database`);
      }
    }

    return validatedSources;

  } catch (error) {
    console.error('❌ Error discovering RSS sources:', error.message);
    return [];
  }
}

async function validateRSSFeed(url) {
  try {
    const response = await axios.get(url, {
      timeout: 10000,
      headers: {
        'User-Agent': 'medium2quiz-rss-discovery/1.0'
      }
    });

    const content = response.data;
    
    // Basic RSS/XML validation
    return content.includes('<rss') || 
           content.includes('<feed') || 
           content.includes('<?xml') ||
           content.includes('<channel>');
           
  } catch (error) {
    return false;
  }
}

function extractTags(text) {
  if (!text) return [];
  
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
  ];
  
  const lowerText = text.toLowerCase();
  return techKeywords.filter(keyword => 
    lowerText.includes(keyword.toLowerCase())
  ).slice(0, 10); // Limit to 10 tags
}

async function generateFlashcardsForArticle(article) {
  try {
    console.log(`📚 Generating flashcards for: ${article.title}`);
    
    const prompt = `Create educational flashcards from this article content.

Title: ${article.title}
Content: ${article.content.substring(0, 2000)}...

Generate 3-5 high-quality flashcards that test key concepts, facts, and understanding from this article.

For each flashcard, provide:
- question: A clear, specific question
- answer: A concise but complete answer
- type: Either "definition", "concept", or "fact"
- difficulty: "easy", "medium", or "hard"

Return JSON array format:
[
  {
    "question": "What is...",
    "answer": "...",
    "type": "definition",
    "difficulty": "medium"
  }
]

Focus on the most important and learnable concepts. Make questions specific and answers educational.

Return ONLY valid JSON array:`;

    const response = await openai.chat.completions.create({
      model: "gpt-4",
      messages: [{ role: "user", content: prompt }],
      temperature: 0.4,
      max_tokens: 1500
    });

    const content = response.choices[0].message.content.trim();
    
    let flashcards;
    try {
      const jsonStr = content.replace(/```json\n?|\n?```/g, '').trim();
      flashcards = JSON.parse(jsonStr);
    } catch (parseError) {
      console.error('❌ Failed to parse flashcard JSON:', parseError.message);
      return [];
    }

    // Convert to database format
    const dbFlashcards = flashcards.map(card => ({
      id: require('crypto').randomUUID(),
      article_id: article.id,
      question: card.question,
      answer: card.answer,
      choices: null, // For flashcard type
      type: 'flashcard',
      difficulty: card.difficulty || 'medium',
      is_starred: false,
      is_completed: false,
      attempts: 0,
      correct_attempts: 0,
      last_studied: null,
      mastery_level: 0.0,
      ease_factor: 2.5,
      interval_days: 1,
      next_review_date: new Date().toISOString(),
      review_stage: 0,
      created_at: new Date().toISOString()
    }));

    // Insert flashcards
    const { data, error } = await supabase
      .from('quiz_cards')
      .insert(dbFlashcards);

    if (error) {
      console.error('❌ Error inserting flashcards:', error.message);
      return [];
    }

    console.log(`✅ Generated ${dbFlashcards.length} flashcards for ${article.title}`);
    return dbFlashcards;

  } catch (error) {
    console.error('❌ Error generating flashcards:', error.message);
    return [];
  }
}

async function setupDynamicRSSForTopics(userTopics) {
  console.log('🚀 Setting up dynamic RSS discovery...');
  
  // Discover new sources for user topics
  const newSources = await discoverRSSSources(userTopics);
  
  if (newSources.length === 0) {
    console.error('❌ No valid RSS sources found for topics:', userTopics);
    throw new Error('No RSS sources could be discovered for the selected topics');
  }
  
  // Run initial crawl to populate articles
  const { crawlAllSources } = require('./rss_crawler');
  await crawlAllSources();
  
  // Verify we have articles
  const { data: articles, error } = await supabase
    .from('articles')
    .select('count')
    .single();
    
  if (error || !articles || articles.count === 0) {
    throw new Error('No articles were fetched from RSS sources. Check connectivity and RSS URLs.');
  }
  
  console.log(`✅ Setup complete! Found ${newSources.length} RSS sources and fetched articles.`);
  return newSources;
}

// Export functions
module.exports = {
  discoverRSSSources,
  generateFlashcardsForArticle,
  setupDynamicRSSForTopics
};

// Run if called directly
if (require.main === module) {
  const topics = process.argv.slice(2);
  if (topics.length === 0) {
    console.log('Usage: node discover_sources.js "Machine Learning" "Cloud Computing"');
    process.exit(1);
  }
  
  setupDynamicRSSForTopics(topics)
    .then(() => {
      console.log('🎉 Dynamic RSS setup complete!');
      process.exit(0);
    })
    .catch(error => {
      console.error('❌ Setup failed:', error.message);
      process.exit(1);
    });
}