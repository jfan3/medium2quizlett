# RSS Crawler Cron Job Setup

## Automated RSS Crawling with Supabase Edge Functions

Your RSS system is now fully automated using Supabase Edge Functions! Here's how to set up automatic crawling:

## 1. Deploy Edge Functions to Supabase

```bash
# Install Supabase CLI if not already installed
npm install -g supabase

# Login to Supabase
supabase login

# Deploy Edge Functions
cd /Users/jfan/Documents/models/medium2quizlett/medium2quiz
supabase functions deploy rss-discovery
supabase functions deploy rss-crawler  
supabase functions deploy rss-scheduler
```

## 2. Set Environment Variables in Supabase

In your Supabase dashboard:
1. Go to **Settings** → **Edge Functions**
2. Add these environment variables:
   - `OPENAI_API_KEY`: Your OpenAI API key
   - `SUPABASE_URL`: Your Supabase project URL
   - `SUPABASE_SERVICE_ROLE_KEY`: Your service role key
   - `SUPABASE_ANON_KEY`: Your anonymous key

## 3. Set Up Cron Job (GitHub Actions)

Create `.github/workflows/rss-crawler.yml`:

```yaml
name: RSS Crawler
on:
  schedule:
    - cron: '0 */2 * * *'  # Every 2 hours
  workflow_dispatch:

jobs:
  crawl:
    runs-on: ubuntu-latest
    steps:
      - name: Trigger RSS Crawler
        run: |
          curl -X POST "${{ secrets.SUPABASE_URL }}/functions/v1/rss-scheduler" \
            -H "Authorization: Bearer ${{ secrets.SUPABASE_ANON_KEY }}" \
            -H "Content-Type: application/json" \
            -d '{"action": "process_scheduled_feeds"}'
```

## 4. Alternative: Supabase Cron (if available)

If your Supabase plan supports pg_cron:

```sql
-- Schedule RSS crawling every 2 hours
SELECT cron.schedule(
  'rss-crawler',
  '0 */2 * * *',
  $$ SELECT net.http_post(
    'https://your-project.supabase.co/functions/v1/rss-scheduler',
    '{"action": "process_scheduled_feeds"}',
    'Bearer your-anon-key'
  ) $$
);
```

## 5. Manual Triggers (for testing)

You can manually trigger crawling:

```bash
# Trigger RSS discovery
curl -X POST "https://your-project.supabase.co/functions/v1/rss-discovery" \
  -H "Authorization: Bearer your-anon-key" \
  -H "Content-Type: application/json" \
  -d '{"topics": ["AI", "Machine Learning"]}'

# Trigger RSS crawling
curl -X POST "https://your-project.supabase.co/functions/v1/rss-crawler" \
  -H "Authorization: Bearer your-anon-key" \
  -H "Content-Type: application/json" \
  -d '{"action": "crawl_all"}'

# Trigger scheduled processing
curl -X POST "https://your-project.supabase.co/functions/v1/rss-scheduler" \
  -H "Authorization: Bearer your-anon-key" \
  -H "Content-Type: application/json" \
  -d '{"action": "process_scheduled_feeds"}'
```

## How It Works

1. **RSS Discovery** (`rss-discovery`): Uses OpenAI to find RSS sources for topics
2. **RSS Crawler** (`rss-crawler`): Fetches articles from RSS feeds
3. **RSS Scheduler** (`rss-scheduler`): Manages automated crawling with intelligent scheduling
4. **iOS App**: Calls Edge Functions directly - no local scripts needed!

## Benefits

- ✅ **Fully Cloud-Based**: No local scripts needed
- ✅ **Automatic Discovery**: OpenAI finds RSS sources
- ✅ **Intelligent Scheduling**: Prioritizes high-quality sources
- ✅ **Error Handling**: Graceful failures and retries
- ✅ **Scalable**: Handles hundreds of RSS sources
- ✅ **Cost-Effective**: Only runs when needed

## Monitoring

Check Edge Function logs in Supabase dashboard:
- **Functions** → **Edge Functions** → **Logs**
- Monitor API usage and errors
- Track RSS source performance

Your RSS system is now fully automated! The iOS app will always have fresh content without any manual intervention.