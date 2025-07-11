#!/bin/bash

# Setup script for RSS crawler and dynamic source discovery
echo "🚀 Setting up RSS crawler and dynamic source discovery..."

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js first:"
    echo "   brew install node"
    exit 1
fi

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "❌ npm is not installed. Please install npm first."
    exit 1
fi

echo "✅ Node.js and npm are installed"

# Install dependencies
echo "📦 Installing Node.js dependencies..."
npm install

if [ $? -eq 0 ]; then
    echo "✅ Dependencies installed successfully"
else
    echo "❌ Failed to install dependencies"
    exit 1
fi

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating .env file..."
    cp env_config.txt .env
    echo "✅ Created .env file from env_config.txt"
else
    echo "✅ .env file already exists"
fi

# Test RSS crawler
echo "🧪 Testing RSS crawler..."
node rss_crawler.js

if [ $? -eq 0 ]; then
    echo "🎉 Setup complete! RSS crawler is ready to use."
    echo ""
    echo "Available commands:"
    echo "  npm run crawl                    - Run RSS crawler"
    echo "  node discover_sources.js [topics] - Discover new RSS sources"
    echo ""
    echo "Example usage:"
    echo "  node discover_sources.js \"Machine Learning\" \"Cloud Computing\""
else
    echo "⚠️ RSS crawler test failed. Please check your database connection and configuration."
fi