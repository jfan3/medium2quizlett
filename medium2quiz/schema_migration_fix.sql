-- Schema Migration Fix for medium2quiz
-- Run this in your Supabase SQL editor to fix schema mismatches

-- 1. Add missing 'topic' column to articles table
ALTER TABLE articles ADD COLUMN IF NOT EXISTS topic VARCHAR;

-- 2. Add missing 'image_url' column to articles table  
ALTER TABLE articles ADD COLUMN IF NOT EXISTS image_url VARCHAR;

-- 3. Add missing 'updated_at' column to articles table
ALTER TABLE articles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT NOW();

-- 4. Add comments for clarity
COMMENT ON COLUMN articles.topic IS 'Single topic classification for the article';
COMMENT ON COLUMN articles.image_url IS 'URL to the main image/thumbnail for the article';
COMMENT ON COLUMN articles.updated_at IS 'Timestamp of last update to the article';

-- 5. Verify all columns exist
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'articles' 
AND column_name IN ('topic', 'image_url', 'updated_at')
ORDER BY column_name;

-- 6. Verify flashcards table structure (should already be correct)
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'flashcards' 
ORDER BY ordinal_position;