# Medium2Quiz - Usage Guide

## ✅ Fixed Issues

1. **RSS Crawler**: Real article fetching from RSS sources
2. **Dynamic Discovery**: OpenAI-powered RSS source discovery  
3. **Error Handling**: Clear messages when no articles found
4. **OpenAI Integration**: Real flashcard generation using your API key

## 🚀 Setup Instructions

### 1. Install Node.js Dependencies
```bash
cd /Users/jfan/Documents/models/medium2quizlett/medium2quiz
./setup_crawler.sh
```

### 2. Setup Database
Make sure your Supabase database is set up with the enhanced schema:
```bash
# Run the database_setup.sql in your Supabase SQL editor
```

### 3. Environment Configuration
Ensure your `env_config.txt` has valid keys:
- `SUPABASE_URL` and `SUPABASE_ANON_KEY`
- `OPENAI_API_KEY` (this will now be used for flashcard generation)

## 📋 Manual Operations (Required)

Since iOS apps can't run Node.js directly, you need to run these manually:

### Discover RSS Sources for New Topics
```bash
cd /Users/jfan/Documents/models/medium2quizlett/medium2quiz
node discover_sources.js "Machine Learning" "Cloud Computing" "Data Science"
```

### Crawl Articles from RSS Sources
```bash
npm run crawl
```

### Check What's in Your Database
```bash
# In Supabase SQL editor:
SELECT COUNT(*) FROM rss_sources WHERE is_active = true;
SELECT COUNT(*) FROM articles WHERE created_at > NOW() - INTERVAL '7 days';
```

## 🔄 Recommended Workflow

### First Time Setup:
1. Run `./setup_crawler.sh`
2. Discover sources: `node discover_sources.js "Your" "Topics"`
3. Crawl articles: `npm run crawl`
4. Open iOS app and select topics

### Daily Usage:
1. Crawl fresh articles: `npm run crawl` 
2. Use iOS app to select articles
3. OpenAI will generate flashcards automatically
4. Study your personalized flashcards

## 🐛 Troubleshooting

### "No RSS sources found"
```bash
# Check if sources exist for your topics
node discover_sources.js "Machine Learning" "AI"
```

### "No articles found" 
```bash
# Run the crawler to fetch fresh content
npm run crawl

# Check database
# In Supabase: SELECT COUNT(*) FROM articles;
```

### "OpenAI API Error"
- Check your `OPENAI_API_KEY` in `env_config.txt`
- Ensure you have OpenAI credits available
- Check the console logs for specific error messages

### "Database Connection Error"
- Verify `SUPABASE_URL` and `SUPABASE_ANON_KEY` in `env_config.txt`
- Ensure Supabase project is active
- Check database schema is properly set up

## 📊 Monitoring

### Check OpenAI Usage
- Go to https://platform.openai.com/usage
- You should now see API calls for flashcard generation

### Database Contents
```sql
-- Check RSS sources
SELECT name, topics, is_active FROM rss_sources;

-- Check recent articles  
SELECT title, source_type, created_at FROM articles 
ORDER BY created_at DESC LIMIT 10;

-- Check generated flashcards
SELECT COUNT(*) FROM quiz_cards;
```

## 🎯 Expected Flow

1. **Topic Selection** → Triggers RSS source discovery if none exist
2. **Source Discovery** → OpenAI finds relevant RSS feeds for your topics  
3. **Article Crawling** → Fetches real articles from discovered sources
4. **Article Selection** → Swipe interface to queue articles
5. **Flashcard Generation** → OpenAI creates educational flashcards
6. **Study Session** → Spaced repetition learning system

## ⚡ Performance Tips

- Run `npm run crawl` daily for fresh content
- Discover sources for new topics as needed
- Monitor OpenAI usage to stay within limits
- Check Supabase storage/bandwidth usage

Now your app will:
- ✅ Use real RSS sources (not static)
- ✅ Generate actual OpenAI flashcards  
- ✅ Show proper errors when things go wrong
- ✅ Crawl fresh articles regularly