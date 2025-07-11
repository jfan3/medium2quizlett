-- Supabase Database Setup for medium2quiz - Enhanced Version
-- Run this in your Supabase SQL editor

-- Drop all existing tables first (in reverse dependency order)
DROP TABLE IF EXISTS user_reading_patterns CASCADE;
DROP TABLE IF EXISTS study_sessions CASCADE;
DROP TABLE IF EXISTS user_quiz_performance CASCADE;
DROP TABLE IF EXISTS flashcard_attempts CASCADE;
DROP TABLE IF EXISTS quiz_cards CASCADE;
DROP TABLE IF EXISTS user_articles CASCADE;
DROP TABLE IF EXISTS articles CASCADE;
DROP TABLE IF EXISTS rss_fetch_schedule CASCADE;
DROP TABLE IF EXISTS user_rss_feeds CASCADE;
DROP TABLE IF EXISTS user_sources CASCADE;
DROP TABLE IF EXISTS rss_sources CASCADE;
DROP TABLE IF EXISTS topic_selections CASCADE;
DROP TABLE IF EXISTS topics CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS article_recommendations CASCADE;
DROP TABLE IF EXISTS content_quality_feedback CASCADE;
DROP TABLE IF EXISTS user_topic_selections CASCADE;


-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_cron";

-- Users table
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR UNIQUE NOT NULL,
  occupation VARCHAR,
  company_interests TEXT[],
  overall_accuracy DECIMAL DEFAULT 0,
  streak_days INTEGER DEFAULT 0,
  last_study_date TIMESTAMP,
  onboarding_complete BOOLEAN DEFAULT false,
  skill_level VARCHAR DEFAULT 'beginner',
  preferred_difficulty VARCHAR DEFAULT 'medium',
  daily_study_goal INTEGER DEFAULT 20,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- RSS feed sources (global feed definitions)
CREATE TABLE rss_sources (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR NOT NULL,
  url VARCHAR UNIQUE NOT NULL,
  description TEXT,
  topics TEXT[],
  tags TEXT[],
  last_fetched TIMESTAMP,
  fetch_interval INTEGER DEFAULT 3600, -- seconds
  is_active BOOLEAN DEFAULT true,
  auto_refresh_enabled BOOLEAN DEFAULT true,
  content_quality_score DECIMAL DEFAULT 0,
  avg_engagement_score DECIMAL DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW()
);

-- User's RSS feed subscriptions with enhanced tracking
CREATE TABLE user_rss_feeds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  rss_source_id UUID REFERENCES rss_sources(id) ON DELETE CASCADE,
  affinity_score DECIMAL DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  subscription_strength DECIMAL DEFAULT 1.0,
  articles_read INTEGER DEFAULT 0,
  articles_liked INTEGER DEFAULT 0,
  articles_disliked INTEGER DEFAULT 0,
  subscribed_at TIMESTAMP DEFAULT NOW(),
  last_interaction_at TIMESTAMP,
  UNIQUE(user_id, rss_source_id)
);

-- RSS fetch scheduling for intelligent refresh
CREATE TABLE rss_fetch_schedule (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  rss_source_id UUID REFERENCES rss_sources(id) ON DELETE CASCADE,
  next_fetch_time TIMESTAMP DEFAULT NOW(),
  fetch_frequency INTEGER DEFAULT 3600,
  priority_score DECIMAL DEFAULT 1.0,
  last_successful_fetch TIMESTAMP,
  consecutive_failures INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, rss_source_id)
);

-- Articles from RSS feeds and other sources with enhanced scoring
CREATE TABLE articles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR NOT NULL,
  url VARCHAR UNIQUE,
  content TEXT,
  summary TEXT,
  author VARCHAR,
  published_date TIMESTAMP,
  source_type VARCHAR DEFAULT 'rss',
  rss_source_id UUID REFERENCES rss_sources(id),
  source_metadata JSONB,
  topics TEXT[],
  tags TEXT[],
  difficulty_level VARCHAR DEFAULT 'medium',
  estimated_read_time INTEGER,
  processing_status VARCHAR DEFAULT 'pending',
  relevance_score DECIMAL DEFAULT 0,
  engagement_score DECIMAL DEFAULT 0,
  freshness_score DECIMAL DEFAULT 0,
  content_quality_score DECIMAL DEFAULT 0,
  word_count INTEGER DEFAULT 0,
  readability_score DECIMAL DEFAULT 0,
  total_views INTEGER DEFAULT 0,
  total_likes INTEGER DEFAULT 0,
  total_dislikes INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW()
);

-- User's article queue and preferences with enhanced tracking
CREATE TABLE user_articles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  article_id UUID REFERENCES articles(id) ON DELETE CASCADE,
  status VARCHAR DEFAULT 'queued',
  preference_score DECIMAL DEFAULT 0,
  personalized_score DECIMAL DEFAULT 0,
  is_starred BOOLEAN DEFAULT false,
  user_rating INTEGER CHECK (user_rating >= 1 AND user_rating <= 5),
  reading_progress DECIMAL DEFAULT 0,
  time_spent_reading INTEGER DEFAULT 0,
  interaction_type VARCHAR, -- 'swiped_right', 'swiped_left', 'clicked', 'starred'
  queued_at TIMESTAMP DEFAULT NOW(),
  started_at TIMESTAMP,
  completed_at TIMESTAMP,
  last_interaction_at TIMESTAMP,
  UNIQUE(user_id, article_id)
);

-- Quiz cards generated from articles
CREATE TABLE quiz_cards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  article_id UUID REFERENCES articles(id) ON DELETE CASCADE,
  question TEXT NOT NULL,
  answer TEXT NOT NULL,
  choices JSONB,
  card_type VARCHAR DEFAULT 'flashcard',
  difficulty VARCHAR DEFAULT 'medium',
  source_paragraph TEXT,
  card_order INTEGER,
  quality_score DECIMAL DEFAULT 0,
  avg_response_time INTEGER DEFAULT 0,
  total_attempts INTEGER DEFAULT 0,
  success_rate DECIMAL DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW()
);

-- User's quiz card performance with spaced repetition
CREATE TABLE user_quiz_performance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  quiz_card_id UUID REFERENCES quiz_cards(id) ON DELETE CASCADE,
  is_starred BOOLEAN DEFAULT false,
  total_attempts INTEGER DEFAULT 0,
  correct_attempts INTEGER DEFAULT 0,
  last_studied TIMESTAMP,
  mastery_level DECIMAL DEFAULT 0,
  ease_factor DECIMAL DEFAULT 2.5,
  interval_days INTEGER DEFAULT 1,
  next_review_date TIMESTAMP DEFAULT NOW(),
  review_stage INTEGER DEFAULT 0, -- 0=new, 1=learning, 2=review, 3=mastered
  consecutive_correct INTEGER DEFAULT 0,
  consecutive_incorrect INTEGER DEFAULT 0,
  avg_response_time INTEGER DEFAULT 0,
  difficulty_rating INTEGER CHECK (difficulty_rating >= 1 AND difficulty_rating <= 5),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, quiz_card_id)
);

-- Study sessions tracking
CREATE TABLE study_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  session_type VARCHAR DEFAULT 'daily_practice',
  cards_studied INTEGER DEFAULT 0,
  new_cards INTEGER DEFAULT 0,
  review_cards INTEGER DEFAULT 0,
  correct_answers INTEGER DEFAULT 0,
  session_duration INTEGER DEFAULT 0,
  accuracy_rate DECIMAL DEFAULT 0,
  focus_topics TEXT[],
  started_at TIMESTAMP DEFAULT NOW(),
  completed_at TIMESTAMP,
  is_completed BOOLEAN DEFAULT false
);

-- User reading patterns and preferences
CREATE TABLE user_reading_patterns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  preferred_topics TEXT[],
  avoided_topics TEXT[],
  optimal_difficulty_level VARCHAR DEFAULT 'medium',
  avg_reading_time INTEGER DEFAULT 0,
  preferred_content_length INTEGER DEFAULT 0,
  preferred_reading_hours INTEGER[] DEFAULT ARRAY[9,10,11,14,15,16,17,18,19,20],
  reading_streak INTEGER DEFAULT 0,
  weekly_reading_goal INTEGER DEFAULT 5,
  learning_velocity DECIMAL DEFAULT 1.0,
  engagement_patterns JSONB DEFAULT '{}',
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Topic bubbles for explore feature
CREATE TABLE topics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR UNIQUE NOT NULL,
  category VARCHAR,
  popularity_score DECIMAL DEFAULT 0,
  difficulty_level VARCHAR DEFAULT 'medium',
  parent_topic_id UUID REFERENCES topics(id),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW()
);

-- User's topic selections in explore mode
CREATE TABLE user_topic_selections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  topic_id UUID REFERENCES topics(id) ON DELETE CASCADE,
  interest_level DECIMAL DEFAULT 1.0,
  proficiency_level DECIMAL DEFAULT 0,
  selected_at TIMESTAMP DEFAULT NOW(),
  last_studied TIMESTAMP,
  session_id UUID,
  is_active BOOLEAN DEFAULT true,
  UNIQUE(user_id, topic_id, session_id)
);

-- User's custom sources (manual additions)
CREATE TABLE user_sources (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  source_type VARCHAR NOT NULL,
  source_content TEXT NOT NULL,
  processing_status VARCHAR DEFAULT 'pending',
  processing_attempts INTEGER DEFAULT 0,
  last_processing_attempt TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Article recommendations tracking
CREATE TABLE article_recommendations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  article_id UUID REFERENCES articles(id) ON DELETE CASCADE,
  recommendation_type VARCHAR DEFAULT 'algorithmic',
  confidence_score DECIMAL DEFAULT 0,
  reasoning TEXT,
  recommended_at TIMESTAMP DEFAULT NOW(),
  user_action VARCHAR, -- 'accepted', 'rejected', 'ignored'
  action_timestamp TIMESTAMP
);

-- Content quality feedback
CREATE TABLE content_quality_feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  article_id UUID REFERENCES articles(id),
  quiz_card_id UUID REFERENCES quiz_cards(id),
  feedback_type VARCHAR NOT NULL, -- 'content_quality', 'difficulty', 'relevance'
  rating INTEGER CHECK (rating >= 1 AND rating <= 5),
  feedback_text TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Row Level Security (RLS) Policies
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE rss_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_rss_feeds ENABLE ROW LEVEL SECURITY;
ALTER TABLE rss_fetch_schedule ENABLE ROW LEVEL SECURITY;
ALTER TABLE articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_quiz_performance ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_reading_patterns ENABLE ROW LEVEL SECURITY;
ALTER TABLE topics ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_topic_selections ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE article_recommendations ENABLE ROW LEVEL SECURITY;
ALTER TABLE content_quality_feedback ENABLE ROW LEVEL SECURITY;

-- Users can only access their own data
CREATE POLICY "Users can view own profile" ON users
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON users
  FOR INSERT WITH CHECK (auth.uid() = id);

-- RSS sources are publicly readable
CREATE POLICY "RSS sources are publicly readable" ON rss_sources
  FOR SELECT TO authenticated USING (true);

-- User RSS feeds policies
CREATE POLICY "Users can view own RSS feeds" ON user_rss_feeds
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own RSS feeds" ON user_rss_feeds
  FOR ALL USING (auth.uid() = user_id);

-- RSS fetch schedule policies
CREATE POLICY "Users can view own RSS schedule" ON rss_fetch_schedule
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own RSS schedule" ON rss_fetch_schedule
  FOR ALL USING (auth.uid() = user_id);

-- Articles are publicly readable but only system can insert
CREATE POLICY "Articles are publicly readable" ON articles
  FOR SELECT TO authenticated USING (true);

-- User articles policies
CREATE POLICY "Users can view own articles" ON user_articles
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own articles" ON user_articles
  FOR ALL USING (auth.uid() = user_id);

-- Quiz cards are publicly readable
CREATE POLICY "Quiz cards are publicly readable" ON quiz_cards
  FOR SELECT TO authenticated USING (true);

-- User quiz performance policies
CREATE POLICY "Users can view own performance" ON user_quiz_performance
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own performance" ON user_quiz_performance
  FOR ALL USING (auth.uid() = user_id);

-- Study sessions policies
CREATE POLICY "Users can view own study sessions" ON study_sessions
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own study sessions" ON study_sessions
  FOR ALL USING (auth.uid() = user_id);

-- User reading patterns policies
CREATE POLICY "Users can view own reading patterns" ON user_reading_patterns
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own reading patterns" ON user_reading_patterns
  FOR ALL USING (auth.uid() = user_id);

-- Topics are publicly readable
CREATE POLICY "Topics are publicly readable" ON topics
  FOR SELECT TO authenticated USING (true);

-- User topic selections policies
CREATE POLICY "Users can view own topic selections" ON user_topic_selections
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own topic selections" ON user_topic_selections
  FOR ALL USING (auth.uid() = user_id);

-- User sources policies
CREATE POLICY "Users can view own sources" ON user_sources
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own sources" ON user_sources
  FOR ALL USING (auth.uid() = user_id);

-- Article recommendations policies
CREATE POLICY "Users can view own recommendations" ON article_recommendations
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own recommendations" ON article_recommendations
  FOR ALL USING (auth.uid() = user_id);

-- Content quality feedback policies
CREATE POLICY "Users can view own feedback" ON content_quality_feedback
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own feedback" ON content_quality_feedback
  FOR ALL USING (auth.uid() = user_id);

-- Indexes for better performance
CREATE INDEX idx_user_articles_user_id ON user_articles(user_id);
CREATE INDEX idx_user_articles_status ON user_articles(status);
CREATE INDEX idx_user_articles_personalized_score ON user_articles(personalized_score DESC);
CREATE INDEX idx_quiz_cards_article_id ON quiz_cards(article_id);
CREATE INDEX idx_user_quiz_performance_user_id ON user_quiz_performance(user_id);
CREATE INDEX idx_user_quiz_performance_mastery ON user_quiz_performance(mastery_level);
CREATE INDEX idx_user_quiz_performance_next_review ON user_quiz_performance(next_review_date);
CREATE INDEX idx_articles_published_date ON articles(published_date);
CREATE INDEX idx_articles_rss_source_id ON articles(rss_source_id);
CREATE INDEX idx_articles_processing_status ON articles(processing_status);
CREATE INDEX idx_articles_relevance_score ON articles(relevance_score DESC);
CREATE INDEX idx_topics_popularity ON topics(popularity_score);
CREATE INDEX idx_rss_sources_topics ON rss_sources USING GIN(topics);
CREATE INDEX idx_user_rss_feeds_user_id ON user_rss_feeds(user_id);
CREATE INDEX idx_user_rss_feeds_affinity ON user_rss_feeds(affinity_score DESC);
CREATE INDEX idx_rss_fetch_schedule_next_fetch ON rss_fetch_schedule(next_fetch_time);
CREATE INDEX idx_study_sessions_user_id ON study_sessions(user_id);
CREATE INDEX idx_study_sessions_started_at ON study_sessions(started_at);
CREATE INDEX idx_user_reading_patterns_user_id ON user_reading_patterns(user_id);

-- Insert the 10 main topics from the app
INSERT INTO topics (name, category, popularity_score, difficulty_level) VALUES
('Causal Inference', 'data_science', 82, 'advanced'),
('ETL Pipelines', 'data_engineering', 85, 'intermediate'),
('Data Visualization', 'data_science', 75, 'beginner'),
('Machine Learning', 'ai_ml', 95, 'intermediate'),
('Cloud Computing', 'infrastructure', 88, 'intermediate'),
('Cybersecurity', 'security', 80, 'intermediate'),
('Blockchain', 'fintech', 70, 'intermediate'),
('Quantum Computing', 'emerging_tech', 65, 'advanced'),
('Augmented Reality', 'emerging_tech', 60, 'intermediate'),
('Bioinformatics', 'life_sciences', 68, 'advanced');

-- Insert RSS sources from our research
INSERT INTO rss_sources (name, url, description, topics, tags, content_quality_score) VALUES
-- Machine Learning sources
('Google AI Blog', 'https://blog.google/technology/ai/rss/', 'Official Google AI research and developments', ARRAY['Machine Learning'], ARRAY['AI', 'machine learning', 'research'], 0.95),
('OpenAI Blog', 'https://openai.com/blog/rss.xml', 'OpenAI research and product announcements', ARRAY['Machine Learning'], ARRAY['AI', 'machine learning', 'research'], 0.98),
('Netflix Tech Blog', 'https://netflixtechblog.com/feed', 'Netflix engineering and ML at scale', ARRAY['Machine Learning'], ARRAY['machine learning', 'recommendation systems', 'engineering'], 0.92),
('AWS Machine Learning Blog', 'https://aws.amazon.com/blogs/machine-learning/feed/', 'AWS ML services and case studies', ARRAY['Machine Learning', 'Cloud Computing'], ARRAY['machine learning', 'AWS', 'cloud'], 0.88),

-- Cloud Computing sources
('AWS Blog', 'https://aws.amazon.com/blogs/aws/feed/', 'Official AWS announcements and tutorials', ARRAY['Cloud Computing'], ARRAY['cloud computing', 'AWS', 'infrastructure'], 0.90),
('Google Cloud Blog', 'https://cloud.google.com/blog/rss', 'Google Cloud Platform updates and guides', ARRAY['Cloud Computing'], ARRAY['cloud computing', 'Google Cloud', 'infrastructure'], 0.89),
('Microsoft Azure Blog', 'https://azure.microsoft.com/en-us/blog/feed/', 'Azure services and cloud solutions', ARRAY['Cloud Computing'], ARRAY['cloud computing', 'Azure', 'infrastructure'], 0.87),

-- Cybersecurity sources
('Krebs on Security', 'https://krebsonsecurity.com/feed/', 'Independent security journalism', ARRAY['Cybersecurity'], ARRAY['cybersecurity', 'security research', 'threats'], 0.94),
('Security Week', 'https://www.securityweek.com/feed/', 'Enterprise security news and analysis', ARRAY['Cybersecurity'], ARRAY['cybersecurity', 'security news', 'industry'], 0.85),

-- Blockchain sources
('CoinDesk', 'https://www.coindesk.com/arc/outboundfeeds/rss/', 'Cryptocurrency and blockchain news', ARRAY['Blockchain'], ARRAY['blockchain', 'cryptocurrency', 'fintech'], 0.82),
('Ethereum Blog', 'https://blog.ethereum.org/feed.xml', 'Official Ethereum development updates', ARRAY['Blockchain'], ARRAY['blockchain', 'Ethereum', 'smart contracts'], 0.91),

-- Bioinformatics sources
('Nature Bioinformatics', 'https://www.nature.com/subjects/bioinformatics.rss', 'Latest bioinformatics research', ARRAY['Bioinformatics'], ARRAY['bioinformatics', 'computational biology', 'research'], 0.96),
('BMC Bioinformatics', 'https://bmcbioinformatics.biomedcentral.com/articles/most-recent/rss.xml', 'Open access bioinformatics research', ARRAY['Bioinformatics'], ARRAY['bioinformatics', 'open access', 'research'], 0.93);

-- Functions for calculating user metrics
CREATE OR REPLACE FUNCTION calculate_user_accuracy(user_uuid UUID)
RETURNS DECIMAL AS $$
DECLARE
    total_attempts INTEGER;
    correct_attempts INTEGER;
BEGIN
    SELECT 
        COALESCE(SUM(total_attempts), 0),
        COALESCE(SUM(correct_attempts), 0)
    INTO total_attempts, correct_attempts
    FROM user_quiz_performance 
    WHERE user_id = user_uuid;
    
    IF total_attempts = 0 THEN
        RETURN 0;
    END IF;
    
    RETURN ROUND((correct_attempts::DECIMAL / total_attempts::DECIMAL) * 100, 2);
END;
$$ LANGUAGE plpgsql;

-- Function to calculate article personalized score
CREATE OR REPLACE FUNCTION calculate_article_score(article_uuid UUID, user_uuid UUID)
RETURNS DECIMAL AS $$
DECLARE
    topic_relevance DECIMAL := 0;
    rss_affinity DECIMAL := 0;
    freshness DECIMAL := 0;
    difficulty_match DECIMAL := 0;
    final_score DECIMAL := 0;
    article_record RECORD;
    user_record RECORD;
    user_pattern RECORD;
BEGIN
    -- Get article details
    SELECT * INTO article_record FROM articles WHERE id = article_uuid;
    
    -- Get user details
    SELECT * INTO user_record FROM users WHERE id = user_uuid;
    
    -- Get user reading patterns
    SELECT * INTO user_pattern FROM user_reading_patterns WHERE user_id = user_uuid;
    
    -- Calculate topic relevance (0-1)
    IF user_pattern.preferred_topics IS NOT NULL THEN
        SELECT COALESCE(
            (SELECT COUNT(*) FROM unnest(article_record.topics) AS topic 
             WHERE topic = ANY(user_pattern.preferred_topics))::DECIMAL / 
            GREATEST(array_length(article_record.topics, 1), 1), 0
        ) INTO topic_relevance;
    END IF;
    
    -- Calculate RSS source affinity (0-1)
    IF article_record.rss_source_id IS NOT NULL THEN
        SELECT COALESCE(affinity_score / 5.0, 0) INTO rss_affinity
        FROM user_rss_feeds 
        WHERE user_id = user_uuid AND rss_source_id = article_record.rss_source_id;
    END IF;
    
    -- Calculate freshness score (0-1)
    IF article_record.published_date IS NOT NULL THEN
        SELECT GREATEST(0, 1 - (EXTRACT(EPOCH FROM (NOW() - article_record.published_date)) / 2592000)) INTO freshness;
    END IF;
    
    -- Calculate difficulty match (0-1)
    IF article_record.difficulty_level = user_record.preferred_difficulty THEN
        difficulty_match := 1.0;
    ELSIF (article_record.difficulty_level = 'easy' AND user_record.preferred_difficulty = 'medium') OR
          (article_record.difficulty_level = 'medium' AND user_record.preferred_difficulty IN ('easy', 'hard')) OR
          (article_record.difficulty_level = 'hard' AND user_record.preferred_difficulty = 'medium') THEN
        difficulty_match := 0.7;
    ELSE
        difficulty_match := 0.3;
    END IF;
    
    -- Calculate final weighted score
    final_score := (topic_relevance * 0.4) + (rss_affinity * 0.3) + (freshness * 0.2) + (difficulty_match * 0.1);
    
    RETURN ROUND(final_score, 3);
END;
$$ LANGUAGE plpgsql;

-- Function to update spaced repetition schedule
CREATE OR REPLACE FUNCTION update_spaced_repetition(
    user_uuid UUID, 
    card_uuid UUID, 
    is_correct BOOLEAN,
    response_time INTEGER DEFAULT 0
)
RETURNS VOID AS $$
DECLARE
    performance_record RECORD;
    new_ease_factor DECIMAL;
    new_interval INTEGER;
    new_stage INTEGER;
BEGIN
    -- Get current performance record
    SELECT * INTO performance_record 
    FROM user_quiz_performance 
    WHERE user_id = user_uuid AND quiz_card_id = card_uuid;
    
    -- If no record exists, create one
    IF performance_record IS NULL THEN
        INSERT INTO user_quiz_performance (
            user_id, quiz_card_id, total_attempts, correct_attempts, 
            ease_factor, interval_days, review_stage
        ) VALUES (
            user_uuid, card_uuid, 1, 
            CASE WHEN is_correct THEN 1 ELSE 0 END,
            2.5, 1, 0
        );
        RETURN;
    END IF;
    
    -- Calculate new ease factor
    IF is_correct THEN
        new_ease_factor := GREATEST(1.3, performance_record.ease_factor + 0.1);
        new_interval := GREATEST(1, (performance_record.interval_days * new_ease_factor)::INTEGER);
        new_stage := CASE 
            WHEN performance_record.review_stage = 0 THEN 1
            WHEN performance_record.review_stage = 1 AND performance_record.consecutive_correct >= 1 THEN 2
            WHEN performance_record.review_stage = 2 AND performance_record.consecutive_correct >= 3 THEN 3
            ELSE performance_record.review_stage
        END;
    ELSE
        new_ease_factor := GREATEST(1.3, performance_record.ease_factor - 0.2);
        new_interval := GREATEST(1, (performance_record.interval_days * 0.5)::INTEGER);
        new_stage := CASE 
            WHEN performance_record.review_stage > 1 THEN 1
            ELSE performance_record.review_stage
        END;
    END IF;
    
    -- Update performance record
    UPDATE user_quiz_performance SET
        total_attempts = performance_record.total_attempts + 1,
        correct_attempts = performance_record.correct_attempts + CASE WHEN is_correct THEN 1 ELSE 0 END,
        consecutive_correct = CASE WHEN is_correct THEN performance_record.consecutive_correct + 1 ELSE 0 END,
        consecutive_incorrect = CASE WHEN is_correct THEN 0 ELSE performance_record.consecutive_incorrect + 1 END,
        ease_factor = new_ease_factor,
        interval_days = new_interval,
        review_stage = new_stage,
        next_review_date = CURRENT_DATE + INTERVAL '1 day' * new_interval,
        last_studied = NOW(),
        avg_response_time = (performance_record.avg_response_time + response_time) / 2,
        mastery_level = CASE 
            WHEN new_stage = 3 THEN 1.0
            WHEN new_stage = 2 THEN 0.7
            WHEN new_stage = 1 THEN 0.4
            ELSE 0.1
        END,
        updated_at = NOW()
    WHERE user_id = user_uuid AND quiz_card_id = card_uuid;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update user accuracy when quiz performance changes
CREATE OR REPLACE FUNCTION update_user_accuracy()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE users 
    SET overall_accuracy = calculate_user_accuracy(NEW.user_id),
        updated_at = NOW()
    WHERE id = NEW.user_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_user_accuracy
    AFTER INSERT OR UPDATE ON user_quiz_performance
    FOR EACH ROW
    EXECUTE FUNCTION update_user_accuracy();

-- Function to update user reading patterns
CREATE OR REPLACE FUNCTION update_reading_patterns()
RETURNS TRIGGER AS $$
BEGIN
    -- Update or create user reading patterns
    INSERT INTO user_reading_patterns (user_id, updated_at)
    VALUES (NEW.user_id, NOW())
    ON CONFLICT (user_id) DO UPDATE SET
        updated_at = NOW();
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_reading_patterns
    AFTER INSERT OR UPDATE ON user_articles
    FOR EACH ROW
    EXECUTE FUNCTION update_reading_patterns();

-- Function to auto-score articles for users
CREATE OR REPLACE FUNCTION auto_score_articles()
RETURNS TRIGGER AS $$
BEGIN
    -- Update personalized scores for all relevant users
    UPDATE user_articles 
    SET personalized_score = calculate_article_score(NEW.id, user_id)
    WHERE article_id = NEW.id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_auto_score_articles
    AFTER INSERT ON articles
    FOR EACH ROW
    EXECUTE FUNCTION auto_score_articles();

-- Schedule RSS fetching every hour
SELECT cron.schedule(
    'rss-fetch-scheduler',
    '0 * * * *',
    'SELECT * FROM rss_fetch_schedule WHERE next_fetch_time <= NOW() AND is_active = true;'
);

-- Schedule daily cleanup
SELECT cron.schedule(
    'daily-cleanup',
    '0 2 * * *',
    $$
    DELETE FROM articles 
    WHERE created_at < NOW() - INTERVAL '6 months'
    AND id NOT IN (
        SELECT DISTINCT article_id FROM user_articles 
        WHERE is_starred = true OR status != 'completed'
    );
    $$
);

-- Schedule weekly pattern analysis
SELECT cron.schedule(
    'weekly-pattern-analysis',
    '0 3 * * 0',
    $$
    UPDATE user_reading_patterns 
    SET preferred_topics = (
        SELECT ARRAY_AGG(DISTINCT topic) 
        FROM (
            SELECT unnest(topics) as topic
            FROM articles a
            JOIN user_articles ua ON a.id = ua.article_id
            WHERE ua.user_id = user_reading_patterns.user_id
            AND ua.preference_score > 0
            AND ua.completed_at > NOW() - INTERVAL '1 month'
        ) topics
    ),
    updated_at = NOW();
    $$
);

-- Create additional indexes for performance
CREATE INDEX IF NOT EXISTS idx_articles_tags ON articles USING GIN(tags);
CREATE INDEX IF NOT EXISTS idx_articles_topics ON articles USING GIN(topics);
CREATE INDEX IF NOT EXISTS idx_articles_rss_source_id ON articles(rss_source_id);
CREATE INDEX IF NOT EXISTS idx_rss_sources_topics ON rss_sources USING GIN(topics);