-- Supabase Database Setup for medium2quiz - Enhanced Version
-- Run this in your Supabase SQL editor

-- Drop all existing tables first (in reverse dependency order)
-- Gamification tables
DROP TABLE IF EXISTS user_league_progress CASCADE;
DROP TABLE IF EXISTS leagues CASCADE;
DROP TABLE IF EXISTS user_power_ups CASCADE;
DROP TABLE IF EXISTS power_ups CASCADE;
DROP TABLE IF EXISTS study_sessions CASCADE;
DROP TABLE IF EXISTS study_sessions_v2 CASCADE; -- Old name
DROP TABLE IF EXISTS user_achievements CASCADE;
DROP TABLE IF EXISTS achievements CASCADE;
DROP TABLE IF EXISTS user_stats CASCADE;
DROP TABLE IF EXISTS test_questions CASCADE;
-- Original tables
DROP TABLE IF EXISTS user_reading_patterns CASCADE;
DROP TABLE IF EXISTS study_sessions_old CASCADE;
DROP TABLE IF EXISTS user_quiz_performance CASCADE;
DROP TABLE IF EXISTS flashcard_attempts CASCADE;
DROP TABLE IF EXISTS flashcards CASCADE;
DROP TABLE IF EXISTS quiz_cards CASCADE; -- For backwards compatibility
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
  email VARCHAR,
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
  created_at TIMESTAMP DEFAULT NOW(),
  priority_level INTEGER DEFAULT 1,
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
  topic VARCHAR,
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
  image_url VARCHAR,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
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

-- Flashcards (renamed from quiz_cards for clarity)
CREATE TABLE flashcards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  article_id UUID REFERENCES articles(id) ON DELETE CASCADE,
  question TEXT NOT NULL,
  answer TEXT NOT NULL,
  explanation TEXT,
  choices JSONB,
  card_type VARCHAR DEFAULT 'flashcard',
  difficulty VARCHAR DEFAULT 'medium',
  tags TEXT[],
  source_paragraph TEXT,
  card_order INTEGER,
  quality_score DECIMAL DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- User's flashcard performance with spaced repetition and mastery tracking
CREATE TABLE user_quiz_performance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  quiz_card_id UUID REFERENCES flashcards(id) ON DELETE CASCADE,
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
  flashcard_mastered BOOLEAN DEFAULT FALSE,
  test_unlocked BOOLEAN DEFAULT FALSE,
  test_attempts INTEGER DEFAULT 0,
  best_test_score DECIMAL(5,2),
  last_test_date TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, quiz_card_id)
);

-- Study sessions tracking (original - kept for backward compatibility)
CREATE TABLE study_sessions_old (
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
  user_id UUID REFERENCES users(id) ON DELETE CASCADE UNIQUE,
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
  quiz_card_id UUID REFERENCES flashcards(id),
  feedback_type VARCHAR NOT NULL, -- 'content_quality', 'difficulty', 'relevance'
  rating INTEGER CHECK (rating >= 1 AND rating <= 5),
  feedback_text TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- GAMIFICATION TABLES

-- Test questions generated from mastered flashcards
CREATE TABLE test_questions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  flashcard_id UUID REFERENCES flashcards(id) ON DELETE CASCADE,
  question_type TEXT NOT NULL CHECK (question_type IN ('multiple_choice', 'fill_blank', 'true_false', 'matching', 'short_answer')),
  question_data JSONB NOT NULL,
  difficulty_level INTEGER DEFAULT 1 CHECK (difficulty_level BETWEEN 1 AND 5),
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- User gamification stats
CREATE TABLE user_stats (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  xp_points INTEGER DEFAULT 0 CHECK (xp_points >= 0),
  coins INTEGER DEFAULT 100 CHECK (coins >= 0),
  gems INTEGER DEFAULT 5 CHECK (gems >= 0),
  current_streak INTEGER DEFAULT 0 CHECK (current_streak >= 0),
  longest_streak INTEGER DEFAULT 0 CHECK (longest_streak >= 0),
  last_study_date DATE,
  level INTEGER DEFAULT 1 CHECK (level >= 1),
  daily_goal_minutes INTEGER DEFAULT 15,
  daily_minutes_studied INTEGER DEFAULT 0,
  total_study_time_minutes INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Achievements system
CREATE TABLE achievements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  description TEXT NOT NULL,
  icon_name TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('streak', 'mastery', 'speed', 'accuracy', 'social', 'special')),
  requirement_type TEXT NOT NULL CHECK (requirement_type IN ('count', 'streak', 'percentage', 'time')),
  requirement_value INTEGER NOT NULL,
  xp_reward INTEGER DEFAULT 100,
  coin_reward INTEGER DEFAULT 50,
  gem_reward INTEGER DEFAULT 0,
  is_hidden BOOLEAN DEFAULT FALSE,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- User earned achievements
CREATE TABLE user_achievements (
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  achievement_id UUID REFERENCES achievements(id) ON DELETE CASCADE,
  earned_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  progress INTEGER DEFAULT 0,
  PRIMARY KEY (user_id, achievement_id)
);

-- Enhanced study sessions with XP tracking
CREATE TABLE study_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  session_type TEXT NOT NULL CHECK (session_type IN ('flashcard', 'test', 'mixed', 'battle')),
  started_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  ended_at TIMESTAMPTZ,
  duration_minutes INTEGER,
  cards_studied INTEGER DEFAULT 0,
  correct_count INTEGER DEFAULT 0,
  xp_earned INTEGER DEFAULT 0,
  coins_earned INTEGER DEFAULT 0,
  perfect_streak INTEGER DEFAULT 0,
  session_data JSONB
);

-- Power-ups store
CREATE TABLE power_ups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  description TEXT NOT NULL,
  icon_name TEXT NOT NULL,
  effect_type TEXT NOT NULL CHECK (effect_type IN ('xp_boost', 'time_freeze', 'streak_shield', 'hint', 'skip')),
  effect_value DECIMAL(5,2) NOT NULL,
  duration_minutes INTEGER,
  coin_cost INTEGER NOT NULL,
  gem_cost INTEGER DEFAULT 0,
  max_owned INTEGER DEFAULT 10
);

-- User power-up inventory
CREATE TABLE user_power_ups (
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  power_up_id UUID REFERENCES power_ups(id) ON DELETE CASCADE,
  quantity INTEGER DEFAULT 0 CHECK (quantity >= 0),
  PRIMARY KEY (user_id, power_up_id)
);

-- Competitive leagues
CREATE TABLE leagues (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  tier INTEGER NOT NULL UNIQUE CHECK (tier BETWEEN 1 AND 5),
  min_xp_required INTEGER NOT NULL,
  icon_name TEXT NOT NULL,
  color_hex TEXT NOT NULL
);

-- User league progress
CREATE TABLE user_league_progress (
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  league_id UUID REFERENCES leagues(id),
  week_start_date DATE NOT NULL,
  weekly_xp INTEGER DEFAULT 0,
  rank INTEGER,
  promoted BOOLEAN DEFAULT FALSE,
  demoted BOOLEAN DEFAULT FALSE,
  PRIMARY KEY (user_id, week_start_date)
);

-- Insert the dev user early to support foreign key constraints
-- This prevents foreign key violations when creating user_articles and user_quiz_performance
DO $$
BEGIN
    -- Create the dev user that the iOS app expects
    INSERT INTO users (
        id,
        email,
        occupation,
        company_interests,
        overall_accuracy,
        streak_days,
        last_study_date,
        onboarding_complete,
        skill_level,
        preferred_difficulty,
        daily_study_goal,
        created_at,
        updated_at
    ) VALUES (
        '00000000-0000-0000-0000-000000000001',
        'dev@example.com',
        'Developer',
        ARRAY['Technology', 'AI', 'Swift'],
        0,
        0,
        NULL,
        true,
        'intermediate',
        'medium',
        20,
        NOW(),
        NOW()
    ) ON CONFLICT (id) DO NOTHING;
    
    RAISE NOTICE 'Dev user created/verified with ID: 00000000-0000-0000-0000-000000000001';
END $$;

-- Row Level Security (RLS) Policies
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE rss_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_rss_feeds ENABLE ROW LEVEL SECURITY;
ALTER TABLE rss_fetch_schedule ENABLE ROW LEVEL SECURITY;
ALTER TABLE articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE flashcards ENABLE ROW LEVEL SECURITY;
ALTER TABLE test_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_sessions_old ENABLE ROW LEVEL SECURITY;
ALTER TABLE power_ups ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_power_ups ENABLE ROW LEVEL SECURITY;
ALTER TABLE leagues ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_league_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_quiz_performance ENABLE ROW LEVEL SECURITY;
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

-- Users table policies - WORKING APPROACH
-- Allow anonymous users full access (for user creation and RSS setup)
CREATE POLICY "users_anon_all" ON users
  FOR ALL TO anon USING (true) WITH CHECK (true);

-- Allow service role full access (for edge functions)
CREATE POLICY "users_service_all" ON users
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- RSS sources are readable by anonymous and authenticated users
CREATE POLICY "Allow anonymous read access to rss_sources" ON rss_sources
  FOR SELECT TO anon, authenticated USING (true);

-- Allow service role full access to rss_sources (for edge functions)
CREATE POLICY "Allow service role full access to rss_sources" ON rss_sources
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- User RSS feeds policies - WORKING APPROACH (matches force_fix_user_rss_feeds.sql)
-- Allow anonymous users full access (for RSS setup when not authenticated)
CREATE POLICY "user_rss_feeds_anon_all" ON user_rss_feeds
  FOR ALL TO anon USING (true) WITH CHECK (true);

-- Allow service role full access (for edge functions)  
CREATE POLICY "user_rss_feeds_service_all" ON user_rss_feeds
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Allow authenticated users to manage their own feeds
CREATE POLICY "user_rss_feeds_auth_own" ON user_rss_feeds
  FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- RSS fetch schedule policies - WORKING APPROACH
-- Allow anonymous users full access (for RSS setup when not authenticated)
CREATE POLICY "rss_fetch_schedule_anon_all" ON rss_fetch_schedule
  FOR ALL TO anon USING (true) WITH CHECK (true);

-- Allow service role full access (for edge functions)
CREATE POLICY "rss_fetch_schedule_service_all" ON rss_fetch_schedule
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Allow authenticated users to manage their own schedules
CREATE POLICY "rss_fetch_schedule_auth_own" ON rss_fetch_schedule
  FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Articles are readable by anonymous and authenticated users
CREATE POLICY "Allow anonymous read access to articles" ON articles
  FOR SELECT TO anon, authenticated USING (true);

-- Allow authenticated users to insert articles (for PDF and custom content)
CREATE POLICY "Allow authenticated users to insert articles" ON articles
  FOR INSERT TO authenticated WITH CHECK (true);

-- Allow anonymous users to insert articles (for development/dev user)
CREATE POLICY "Allow anonymous users to insert articles" ON articles
  FOR INSERT TO anon WITH CHECK (true);

-- Allow service role full access to articles (for edge functions)
CREATE POLICY "Allow service role full access to articles" ON articles
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- User articles policies - WORKING APPROACH
-- Allow anonymous users full access (for RSS setup when not authenticated)
CREATE POLICY "user_articles_anon_all" ON user_articles
  FOR ALL TO anon USING (true) WITH CHECK (true);

-- Allow service role full access (for edge functions)
CREATE POLICY "user_articles_service_all" ON user_articles
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Allow authenticated users to manage their own articles
CREATE POLICY "user_articles_auth_own" ON user_articles
  FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Flashcards are publicly readable
CREATE POLICY "Flashcards are publicly readable" ON flashcards
  FOR SELECT TO authenticated USING (true);

-- Allow authenticated users to insert flashcards (for PDF and custom content)
CREATE POLICY "Allow authenticated users to insert flashcards" ON flashcards
  FOR INSERT TO authenticated WITH CHECK (true);

-- Allow anonymous users to insert flashcards (for development/dev user)
CREATE POLICY "Allow anonymous users to insert flashcards" ON flashcards
  FOR INSERT TO anon WITH CHECK (true);

-- User quiz performance policies - COMPREHENSIVE FOR ANONYMOUS ACCESS
CREATE POLICY "Allow anonymous all user_quiz_performance" ON user_quiz_performance
  FOR ALL TO anon USING (true) WITH CHECK (true);

CREATE POLICY "Allow service role all user_quiz_performance" ON user_quiz_performance
  FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "Users can view own performance" ON user_quiz_performance
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own performance" ON user_quiz_performance
  FOR ALL USING (auth.uid() = user_id);

-- Study sessions policies (old table)
CREATE POLICY "Users can view own study sessions old" ON study_sessions_old
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own study sessions old" ON study_sessions_old
  FOR ALL USING (auth.uid() = user_id);

-- User reading patterns policies - WORKING APPROACH
-- Allow anonymous users full access (for RSS setup when not authenticated)
CREATE POLICY "user_reading_patterns_anon_all" ON user_reading_patterns
  FOR ALL TO anon USING (true) WITH CHECK (true);

-- Allow service role full access (for edge functions)
CREATE POLICY "user_reading_patterns_service_all" ON user_reading_patterns
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Allow authenticated users to manage their own patterns
CREATE POLICY "user_reading_patterns_auth_own" ON user_reading_patterns
  FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

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

-- COMPREHENSIVE ANONYMOUS ACCESS POLICIES FOR ALL TABLES
-- These policies ensure the iOS app can perform all operations with anonymous key

-- Flashcards - anonymous read access
CREATE POLICY "Allow anonymous read flashcards" ON flashcards
  FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "Allow service role full access to flashcards" ON flashcards
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- User quiz performance policies already defined above

-- Study sessions old - anonymous insert access  
CREATE POLICY "Allow anonymous insert study_sessions_old" ON study_sessions_old
  FOR INSERT TO anon WITH CHECK (true);

CREATE POLICY "Allow service role full access to study_sessions_old" ON study_sessions_old
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Topics - anonymous read access
CREATE POLICY "Allow anonymous read topics" ON topics
  FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "Allow service role full access to topics" ON topics
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- User topic selections - anonymous insert access
CREATE POLICY "Allow anonymous insert user_topic_selections" ON user_topic_selections
  FOR INSERT TO anon WITH CHECK (true);

CREATE POLICY "Allow service role full access to user_topic_selections" ON user_topic_selections
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- User sources - anonymous insert access
CREATE POLICY "Allow anonymous insert user_sources" ON user_sources
  FOR INSERT TO anon WITH CHECK (true);

CREATE POLICY "Allow service role full access to user_sources" ON user_sources
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Article recommendations - anonymous insert access
CREATE POLICY "Allow anonymous insert article_recommendations" ON article_recommendations
  FOR INSERT TO anon WITH CHECK (true);

CREATE POLICY "Allow service role full access to article_recommendations" ON article_recommendations
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Content quality feedback - anonymous insert access
CREATE POLICY "Allow anonymous insert content_quality_feedback" ON content_quality_feedback
  FOR INSERT TO anon WITH CHECK (true);

CREATE POLICY "Allow service role full access to content_quality_feedback" ON content_quality_feedback
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- GAMIFICATION TABLE POLICIES

-- Test questions policies
CREATE POLICY "Users can view test questions for their flashcards" ON test_questions
  FOR SELECT USING (
    flashcard_id IN (
      SELECT f.id FROM flashcards f
      JOIN articles a ON f.article_id = a.id
      JOIN user_articles ua ON a.id = ua.article_id
      WHERE ua.user_id = auth.uid()
    )
  );

CREATE POLICY "Allow service role full access to test_questions" ON test_questions
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- User stats policies
CREATE POLICY "Users can view own stats" ON user_stats
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can update own stats" ON user_stats
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "Users can insert own stats" ON user_stats
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Allow anonymous manage user_stats" ON user_stats
  FOR ALL TO anon USING (true) WITH CHECK (true);

CREATE POLICY "Allow service role full access to user_stats" ON user_stats
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Achievements policies (public read)
CREATE POLICY "Achievements are publicly readable" ON achievements
  FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "Allow service role full access to achievements" ON achievements
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- User achievements policies
CREATE POLICY "Users can view own achievements" ON user_achievements
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can insert own achievements" ON user_achievements
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Allow anonymous manage user_achievements" ON user_achievements
  FOR ALL TO anon USING (true) WITH CHECK (true);

CREATE POLICY "Allow service role full access to user_achievements" ON user_achievements
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Study sessions policies (gamified version)
CREATE POLICY "Users can view own study sessions" ON study_sessions
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can insert own study sessions" ON study_sessions
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own study sessions" ON study_sessions
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "Allow anonymous manage study_sessions" ON study_sessions
  FOR ALL TO anon USING (true) WITH CHECK (true);

CREATE POLICY "Allow service role full access to study_sessions" ON study_sessions
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Power-ups policies (public read)
CREATE POLICY "Power-ups are publicly readable" ON power_ups
  FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "Allow service role full access to power_ups" ON power_ups
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- User power-ups policies
CREATE POLICY "Users can view own power-ups" ON user_power_ups
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can update own power-ups" ON user_power_ups
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "Allow anonymous manage user_power_ups" ON user_power_ups
  FOR ALL TO anon USING (true) WITH CHECK (true);

CREATE POLICY "Allow service role full access to user_power_ups" ON user_power_ups
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Leagues policies (public read)
CREATE POLICY "Leagues are publicly readable" ON leagues
  FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "Allow service role full access to leagues" ON leagues
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- User league progress policies
CREATE POLICY "Users can view own league progress" ON user_league_progress
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can view league leaderboard" ON user_league_progress
  FOR SELECT USING (week_start_date >= CURRENT_DATE - INTERVAL '7 days');

CREATE POLICY "Allow anonymous manage user_league_progress" ON user_league_progress
  FOR ALL TO anon USING (true) WITH CHECK (true);

CREATE POLICY "Allow service role full access to user_league_progress" ON user_league_progress
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Indexes for better performance
CREATE INDEX idx_user_articles_user_id ON user_articles(user_id);
CREATE INDEX idx_user_articles_status ON user_articles(status);
CREATE INDEX idx_user_articles_personalized_score ON user_articles(personalized_score DESC);
CREATE INDEX idx_flashcards_article_id ON flashcards(article_id);
CREATE INDEX idx_flashcards_user_id ON flashcards(user_id);
CREATE INDEX idx_flashcards_user_article ON flashcards(user_id, article_id);
CREATE INDEX idx_user_quiz_performance_user_id ON user_quiz_performance(user_id);
CREATE INDEX idx_user_quiz_performance_quiz_card_id ON user_quiz_performance(quiz_card_id);
CREATE INDEX idx_user_quiz_performance_user_card ON user_quiz_performance(user_id, quiz_card_id);
CREATE INDEX idx_user_quiz_performance_mastery ON user_quiz_performance(mastery_level);
CREATE INDEX idx_user_quiz_performance_next_review ON user_quiz_performance(next_review_date);
CREATE INDEX idx_user_quiz_performance_starred ON user_quiz_performance(is_starred);
CREATE INDEX idx_flashcards_is_active ON flashcards(is_active);
-- New gamification indexes
CREATE INDEX idx_test_questions_flashcard ON test_questions(flashcard_id);
CREATE INDEX idx_user_stats_level ON user_stats(level);
CREATE INDEX idx_user_stats_streak ON user_stats(current_streak);
CREATE INDEX idx_study_sessions_user_date ON study_sessions(user_id, started_at);
CREATE INDEX idx_user_league_weekly ON user_league_progress(week_start_date, weekly_xp DESC);
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
('Anthropic Blog', 'https://www.anthropic.com/news/rss.xml', 'Anthropic research and product announcements', ARRAY['Machine Learning'], ARRAY['AI', 'machine learning', 'research'], 0.98),
('Netflix Tech Blog', 'https://netflixtechblog.com/feed', 'Netflix engineering and ML at scale', ARRAY['Machine Learning'], ARRAY['machine learning', 'recommendation systems', 'engineering'], 0.92),
('AWS Machine Learning Blog', 'https://aws.amazon.com/blogs/machine-learning/feed/', 'AWS ML services and case studies', ARRAY['Machine Learning', 'Cloud Computing'], ARRAY['machine learning', 'AWS', 'cloud'], 0.88),
('Towards Data Science', 'https://towardsdatascience.com/feed', 'Machine learning and data science articles', ARRAY['Machine Learning'], ARRAY['machine learning', 'data science', 'tutorials'], 0.89),
('Distill', 'https://distill.pub/rss.xml', 'Interactive machine learning research', ARRAY['Machine Learning'], ARRAY['machine learning', 'research', 'visualization'], 0.93),

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

-- Data Science & ETL sources  
('KDnuggets', 'https://www.kdnuggets.com/feed', 'Data science news and tutorials', ARRAY['ETL Pipelines', 'Data Visualization'], ARRAY['data science', 'ETL', 'analytics'], 0.87),
('Analytics Vidhya', 'https://www.analyticsvidhya.com/blog/feed/', 'Data science and machine learning tutorials', ARRAY['ETL Pipelines', 'Machine Learning'], ARRAY['data science', 'tutorials', 'analytics'], 0.86),

-- Causal Inference sources (replacing failed ones)
('Andrew Gelman Blog', 'https://statmodeling.stat.columbia.edu/feed/', 'Statistical modeling and causal inference', ARRAY['Causal Inference'], ARRAY['statistics', 'causal inference', 'research'], 0.91),
('Simply Statistics', 'https://simplystatistics.org/index.xml', 'Statistics and data science insights', ARRAY['Causal Inference'], ARRAY['statistics', 'data science', 'research'], 0.88),

-- Bioinformatics sources
('Nature Bioinformatics', 'https://www.nature.com/subjects/bioinformatics.rss', 'Latest bioinformatics research', ARRAY['Bioinformatics'], ARRAY['bioinformatics', 'computational biology', 'research'], 0.96),
('BMC Bioinformatics', 'https://bmcbioinformatics.biomedcentral.com/articles/most-recent/rss.xml', 'Open access bioinformatics research', ARRAY['Bioinformatics'], ARRAY['bioinformatics', 'open access', 'research'], 0.93),

-- Data Visualization sources
('Flowing Data', 'https://flowingdata.com/feed/', 'Data visualization and statistical analysis', ARRAY['Data Visualization'], ARRAY['data visualization', 'statistics', 'design'], 0.90),
('Information is Beautiful', 'https://informationisbeautiful.net/feed/', 'Creative data visualization', ARRAY['Data Visualization'], ARRAY['data visualization', 'infographics', 'design'], 0.85);

-- Insert default achievements
INSERT INTO achievements (name, description, icon_name, category, requirement_type, requirement_value, xp_reward, coin_reward, gem_reward) VALUES
('First Steps', 'Complete your first flashcard', 'footsteps', 'mastery', 'count', 1, 50, 25, 0),
('Streak Starter', 'Maintain a 3-day streak', 'fire', 'streak', 'streak', 3, 100, 50, 1),
('Week Warrior', 'Maintain a 7-day streak', 'fire', 'streak', 'streak', 7, 250, 100, 3),
('Speed Demon', 'Answer 10 cards correctly in under 30 seconds', 'lightning', 'speed', 'time', 30, 150, 75, 2),
('Perfectionist', 'Get 100% on a test', 'star', 'accuracy', 'percentage', 100, 200, 100, 2),
('Knowledge Seeker', 'Master 50 flashcards', 'graduation-cap', 'mastery', 'count', 50, 500, 250, 5),
('Social Butterfly', 'Add 5 friends', 'users', 'social', 'count', 5, 150, 75, 1),
('Night Owl', 'Study after 10 PM', 'moon', 'special', 'count', 1, 100, 50, 1),
('Early Bird', 'Study before 6 AM', 'sun', 'special', 'count', 1, 100, 50, 1);

-- Insert default power-ups
INSERT INTO power_ups (name, description, icon_name, effect_type, effect_value, duration_minutes, coin_cost, gem_cost) VALUES
('XP Boost', 'Double XP for 30 minutes', 'rocket', 'xp_boost', 2.0, 30, 100, 0),
('Streak Shield', 'Protect your streak for one day', 'shield', 'streak_shield', 1.0, 1440, 200, 0),
('Time Freeze', 'Extra 10 seconds per question', 'clock', 'time_freeze', 10.0, NULL, 50, 0),
('Hint Helper', 'Reveal a hint for the current question', 'lightbulb', 'hint', 1.0, NULL, 25, 0),
('Skip Card', 'Skip a difficult question', 'forward', 'skip', 1.0, NULL, 40, 0);

-- Insert default leagues
INSERT INTO leagues (name, tier, min_xp_required, icon_name, color_hex) VALUES
('Bronze', 1, 0, 'bronze-medal', '#CD7F32'),
('Silver', 2, 1000, 'silver-medal', '#C0C0C0'),
('Gold', 3, 2500, 'gold-medal', '#FFD700'),
('Diamond', 4, 5000, 'diamond', '#B9F2FF'),
('Master', 5, 10000, 'crown', '#9B59B6');

-- Functions for calculating user metrics
CREATE OR REPLACE FUNCTION calculate_user_accuracy(user_uuid UUID)
RETURNS DECIMAL AS $$
DECLARE
    total_attempts_sum INTEGER;
    correct_attempts_sum INTEGER;
BEGIN
    SELECT 
        COALESCE(SUM(uqp.total_attempts), 0),
        COALESCE(SUM(uqp.correct_attempts), 0)
    INTO total_attempts_sum, correct_attempts_sum
    FROM user_quiz_performance uqp
    WHERE uqp.user_id = user_uuid;
    
    IF total_attempts_sum = 0 THEN
        RETURN 0;
    END IF;
    
    RETURN ROUND((correct_attempts_sum::DECIMAL / total_attempts_sum::DECIMAL) * 100, 2);
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

-- Function to check and update streaks
CREATE OR REPLACE FUNCTION check_and_update_streak(p_user_id UUID)
RETURNS VOID AS $$
DECLARE
    v_last_study_date DATE;
    v_current_streak INTEGER;
    v_longest_streak INTEGER;
BEGIN
    SELECT last_study_date, current_streak, longest_streak
    INTO v_last_study_date, v_current_streak, v_longest_streak
    FROM user_stats
    WHERE user_id = p_user_id;
    
    IF v_last_study_date IS NULL OR v_last_study_date = CURRENT_DATE THEN
        -- First study or already studied today
        UPDATE user_stats
        SET last_study_date = CURRENT_DATE
        WHERE user_id = p_user_id;
    ELSIF v_last_study_date = CURRENT_DATE - INTERVAL '1 day' THEN
        -- Studied yesterday, increment streak
        v_current_streak := v_current_streak + 1;
        v_longest_streak := GREATEST(v_longest_streak, v_current_streak);
        
        UPDATE user_stats
        SET 
            current_streak = v_current_streak,
            longest_streak = v_longest_streak,
            last_study_date = CURRENT_DATE
        WHERE user_id = p_user_id;
    ELSE
        -- Streak broken
        UPDATE user_stats
        SET 
            current_streak = 1,
            last_study_date = CURRENT_DATE
        WHERE user_id = p_user_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update user stats after study sessions
CREATE OR REPLACE FUNCTION update_user_stats_after_session()
RETURNS TRIGGER AS $$
BEGIN
    -- Update user stats
    UPDATE user_stats
    SET 
        xp_points = xp_points + NEW.xp_earned,
        coins = coins + NEW.coins_earned,
        daily_minutes_studied = daily_minutes_studied + COALESCE(NEW.duration_minutes, 0),
        total_study_time_minutes = total_study_time_minutes + COALESCE(NEW.duration_minutes, 0),
        updated_at = CURRENT_TIMESTAMP
    WHERE user_id = NEW.user_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_user_stats
AFTER INSERT OR UPDATE ON study_sessions
FOR EACH ROW
WHEN (NEW.ended_at IS NOT NULL)
EXECUTE FUNCTION update_user_stats_after_session();

-- Trigger to update user accuracy when quiz performance changes
-- DISABLED: This trigger causes "column reference 'total_attempts' is ambiguous" errors
-- User accuracy should be calculated on-demand in the application instead
CREATE OR REPLACE FUNCTION update_user_accuracy()
RETURNS TRIGGER AS $$
BEGIN
    -- Temporarily disabled to avoid ambiguous column errors
    -- The user accuracy can be calculated on-demand in the app instead
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



-- Fix RLS policies for flashcards table to allow insertion
-- This is needed for flashcard generation to work

-- Add INSERT policy for anonymous users (needed for app functionality)
CREATE POLICY "Allow anonymous insert flashcards_v2" ON flashcards
  FOR INSERT TO anon WITH CHECK (true);

-- Add UPDATE policy for anonymous users (in case needed)
CREATE POLICY "Allow anonymous update flashcards_v2" ON flashcards
  FOR UPDATE TO anon USING (true) WITH CHECK (true);

-- Add DELETE policy for service role (for maintenance)
CREATE POLICY "Allow service role delete flashcards" ON flashcards
  FOR DELETE TO service_role USING (true);

-- Also ensure anonymous users can read all flashcards
DROP POLICY IF EXISTS "Flashcards are publicly readable" ON flashcards;
CREATE POLICY "Allow anonymous read all flashcards" ON flashcards
  FOR SELECT TO anon, authenticated USING (true);

-- IMPORTANT: Column name conflict warning
-- When joining user_quiz_performance with flashcards using PostgREST's !inner syntax,
-- column name conflicts will occur (e.g., 'created_at' exists in both tables).
-- Solution: Fetch from each table separately and join in application code.
COMMENT ON TABLE user_quiz_performance IS 'When joining with flashcards, be aware of column name conflicts. Fetch separately and join in application code to avoid ambiguity.';
COMMENT ON TABLE flashcards IS 'When joined with user_quiz_performance, column name conflicts may occur. Consider fetching separately.';

-- FORCE CREATE DEV USER - This will execute and create the dev user
INSERT INTO users (id, email, occupation, company_interests, overall_accuracy, streak_days, last_study_date, onboarding_complete, skill_level, preferred_difficulty, daily_study_goal, created_at, updated_at) VALUES ('00000000-0000-0000-0000-000000000001', 'dev@example.com', 'Developer', ARRAY['Technology', 'AI', 'Swift'], 0, 0, NULL, true, 'intermediate', 'medium', 20, NOW(), NOW()) ON CONFLICT (id) DO NOTHING;

-- Verify dev user exists
SELECT 'Dev user created/exists:' as status, id, email FROM users WHERE id = '00000000-0000-0000-0000-000000000001';

-- CRITICAL: Ensure dev user exists for PDF functionality
-- This is a safety measure to ensure the dev user exists even if the earlier insert failed
-- The ON CONFLICT clause prevents errors if the user already exists
DO $$
BEGIN
    -- Try to insert the dev user, ignore if it already exists
    INSERT INTO users (
        id,
        email,
        occupation,
        company_interests,
        overall_accuracy,
        streak_days,
        last_study_date,
        onboarding_complete,
        skill_level,
        preferred_difficulty,
        daily_study_goal,
        created_at,
        updated_at
    ) VALUES (
        '00000000-0000-0000-0000-000000000001',
        'dev@example.com',
        'Developer',
        ARRAY['Technology', 'AI', 'Swift'],
        0,
        0,
        NULL,
        true,
        'intermediate',
        'medium',
        20,
        NOW(),
        NOW()
    ) ON CONFLICT (id) DO NOTHING;
    
    -- Verify the user exists
    IF NOT EXISTS (SELECT 1 FROM users WHERE id = '00000000-0000-0000-0000-000000000001') THEN
        RAISE EXCEPTION 'Failed to create dev user - check constraints and permissions';
    END IF;
    
    RAISE NOTICE 'Dev user verified: %', (SELECT email FROM users WHERE id = '00000000-0000-0000-0000-000000000001');
    
    -- Initialize user_stats for the dev user
    INSERT INTO user_stats (user_id) 
    VALUES ('00000000-0000-0000-0000-000000000001')
    ON CONFLICT (user_id) DO NOTHING;
    
    RAISE NOTICE 'Dev user stats initialized';
END $$;

-- Initialize user_stats for any existing users
INSERT INTO user_stats (user_id)
SELECT id FROM users
ON CONFLICT (user_id) DO NOTHING;