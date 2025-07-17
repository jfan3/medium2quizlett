#!/bin/bash

echo "🚀 Deploying Supabase Edge Functions..."

# Deploy functions one by one with progress indication
functions=("generate-tests" "rss-crawler" "process-content" "rss-discovery" "rss-processor")

for func in "${functions[@]}"; do
    echo "📦 Deploying $func..."
    timeout 300 supabase functions deploy "$func" --debug
    if [ $? -eq 0 ]; then
        echo "✅ $func deployed successfully"
    else
        echo "❌ Failed to deploy $func"
    fi
    echo ""
done

echo "🔍 Checking deployed functions..."
supabase functions list

echo "✨ Deployment complete!"