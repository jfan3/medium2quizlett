-- Add missing tags column to articles table
ALTER TABLE articles ADD COLUMN IF NOT EXISTS tags TEXT[];

-- Create index on tags for better performance
CREATE INDEX IF NOT EXISTS idx_articles_tags ON articles USING GIN(tags);