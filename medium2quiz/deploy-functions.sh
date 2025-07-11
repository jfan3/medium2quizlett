#!/bin/bash

# Deploy Supabase Edge Functions
# Run this script to deploy all RSS automation functions

echo "🚀 Deploying RSS Automation Edge Functions to Supabase"

# Check if user is logged in
if ! supabase projects list &>/dev/null; then
    echo "❌ Not logged in to Supabase CLI"
    echo "Please run: supabase login"
    echo "Then run this script again"
    exit 1
fi

# Get project ref from config
PROJECT_REF=$(grep SUPABASE_URL env_config.txt | cut -d'/' -f3 | cut -d'.' -f1)

if [ -z "$PROJECT_REF" ]; then
    echo "❌ Could not determine project ref from env_config.txt"
    echo "Please check your SUPABASE_URL in env_config.txt"
    exit 1
fi

echo "📝 Project ref: $PROJECT_REF"

# Link to project
echo "🔗 Linking to Supabase project..."
supabase link --project-ref $PROJECT_REF

# Deploy functions
echo "📦 Deploying RSS Discovery function..."
supabase functions deploy rss-discovery --project-ref $PROJECT_REF

echo "📦 Deploying RSS Crawler function..."
supabase functions deploy rss-crawler --project-ref $PROJECT_REF

echo "📦 Deploying RSS Scheduler function..."
supabase functions deploy rss-scheduler --project-ref $PROJECT_REF

echo "📦 Deploying RSS Processor function..."
supabase functions deploy rss-processor --project-ref $PROJECT_REF

echo "📦 Deploying Process Content function..."
supabase functions deploy process-content --project-ref $PROJECT_REF

echo ""
echo "✅ All Edge Functions deployed successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Go to your Supabase dashboard → Settings → Edge Functions"
echo "2. Add these environment variables:"
echo "   - OPENAI_API_KEY: $(grep OPENAI_API_KEY env_config.txt | cut -d'=' -f2)"
echo "   - SUPABASE_URL: $(grep SUPABASE_URL env_config.txt | cut -d'=' -f2)"
echo "   - SUPABASE_SERVICE_ROLE_KEY: [Your service role key]"
echo "   - SUPABASE_ANON_KEY: $(grep SUPABASE_ANON_KEY env_config.txt | cut -d'=' -f2)"
echo ""
echo "3. Test the functions with your iOS app!"
echo "4. Set up automated crawling (see cron-setup.md)"