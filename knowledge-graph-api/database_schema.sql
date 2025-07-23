-- Knowledge Graph Database Schema for Supabase
-- This schema supports storing documents, concepts, relationships, and study materials

-- Drop all tables first (in reverse dependency order)
DROP TABLE IF EXISTS knowledge_paths CASCADE;
DROP TABLE IF EXISTS study_sessions CASCADE;
DROP TABLE IF EXISTS user_progress CASCADE;
DROP TABLE IF EXISTS study_cards CASCADE;
DROP TABLE IF EXISTS visual_elements CASCADE;
DROP TABLE IF EXISTS concept_relationships CASCADE;
DROP TABLE IF EXISTS concepts CASCADE;
DROP TABLE IF EXISTS document_content CASCADE;
DROP TABLE IF EXISTS documents CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- Drop functions
DROP FUNCTION IF EXISTS search_concepts(TEXT, UUID, INTEGER);
DROP FUNCTION IF EXISTS get_related_concepts(UUID, TEXT[]);

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table (if not already exists from auth)
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Documents table - stores uploaded documents and their metadata
CREATE TABLE documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(500) NOT NULL,
    original_filename VARCHAR(255) NOT NULL,
    file_path VARCHAR(500) NOT NULL,
    file_size INTEGER NOT NULL,
    content_type VARCHAR(100) NOT NULL,
    document_type VARCHAR(50) NOT NULL CHECK (document_type IN ('textbook', 'paper', 'short_text', 'unknown')),
    processing_status VARCHAR(50) NOT NULL DEFAULT 'pending' CHECK (processing_status IN ('pending', 'processing', 'completed', 'failed')),
    word_count INTEGER DEFAULT 0,
    page_count INTEGER DEFAULT 1,
    language VARCHAR(10) DEFAULT 'en',
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Document content table - stores the actual text content
CREATE TABLE document_content (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    full_text TEXT NOT NULL,
    pages JSONB DEFAULT '[]', -- Array of page objects with text and metadata
    processing_details JSONB DEFAULT '{}', -- Classification details, features, etc.
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Concepts table - stores individual concepts extracted from documents
CREATE TABLE concepts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    title VARCHAR(500) NOT NULL,
    content TEXT NOT NULL,
    concept_type VARCHAR(100) NOT NULL, -- definition, example, theorem, principle, etc.
    importance_score DECIMAL(3,2) DEFAULT 0.5 CHECK (importance_score >= 0 AND importance_score <= 1),
    difficulty_level INTEGER DEFAULT 3 CHECK (difficulty_level >= 1 AND difficulty_level <= 5),
    position_in_doc INTEGER, -- Character position in original document
    page_number INTEGER,
    section_title VARCHAR(500),
    tags TEXT[], -- Array of tags for categorization
    metadata JSONB DEFAULT '{}', -- Additional metadata like extraction confidence, etc.
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Concept relationships table - stores relationships between concepts
CREATE TABLE concept_relationships (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_concept_id UUID NOT NULL REFERENCES concepts(id) ON DELETE CASCADE,
    target_concept_id UUID NOT NULL REFERENCES concepts(id) ON DELETE CASCADE,
    relationship_type VARCHAR(100) NOT NULL, -- prerequisite, related, example_of, opposite, part_of, etc.
    strength DECIMAL(3,2) DEFAULT 0.5 CHECK (strength >= 0 AND strength <= 1),
    bidirectional BOOLEAN DEFAULT FALSE,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(source_concept_id, target_concept_id, relationship_type)
);

-- Visual elements table - stores images, charts, diagrams from documents
CREATE TABLE visual_elements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    concept_id UUID REFERENCES concepts(id) ON DELETE SET NULL, -- Link to related concept
    element_type VARCHAR(100) NOT NULL, -- chart, diagram, table, image, etc.
    page_number INTEGER NOT NULL,
    position_data JSONB DEFAULT '{}', -- Bounding box, coordinates, etc.
    image_url VARCHAR(500), -- URL to stored image
    image_base64 TEXT, -- Base64 encoded image data
    description TEXT,
    importance_score DECIMAL(3,2) DEFAULT 0.5,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Study cards table - stores generated study materials
CREATE TABLE study_cards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    concept_id UUID NOT NULL REFERENCES concepts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    card_type VARCHAR(100) NOT NULL, -- concept, definition, example, question, flashcard
    front_content TEXT NOT NULL,
    back_content TEXT,
    difficulty INTEGER DEFAULT 3 CHECK (difficulty >= 1 AND difficulty <= 5),
    image_url VARCHAR(500),
    tags TEXT[],
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User progress table - tracks learning progress
CREATE TABLE user_progress (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    concept_id UUID NOT NULL REFERENCES concepts(id) ON DELETE CASCADE,
    mastery_level DECIMAL(3,2) DEFAULT 0 CHECK (mastery_level >= 0 AND mastery_level <= 1),
    times_studied INTEGER DEFAULT 0,
    times_correct INTEGER DEFAULT 0,
    last_studied_at TIMESTAMP WITH TIME ZONE,
    next_review_at TIMESTAMP WITH TIME ZONE,
    study_streak INTEGER DEFAULT 0,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, concept_id)
);

-- Study sessions table - tracks individual study sessions
CREATE TABLE study_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    document_id UUID REFERENCES documents(id) ON DELETE SET NULL,
    session_type VARCHAR(100) NOT NULL, -- review, learn, test, browse
    concepts_studied UUID[], -- Array of concept IDs
    duration_minutes INTEGER DEFAULT 0,
    cards_completed INTEGER DEFAULT 0,
    accuracy_rate DECIMAL(3,2) DEFAULT 0,
    session_data JSONB DEFAULT '{}',
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    ended_at TIMESTAMP WITH TIME ZONE
);

-- Knowledge graph paths table - stores computed paths between concepts
CREATE TABLE knowledge_paths (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    start_concept_id UUID NOT NULL REFERENCES concepts(id) ON DELETE CASCADE,
    end_concept_id UUID NOT NULL REFERENCES concepts(id) ON DELETE CASCADE,
    path_concepts UUID[] NOT NULL, -- Array of concept IDs in path order
    path_length INTEGER NOT NULL,
    path_strength DECIMAL(3,2) DEFAULT 0.5,
    computed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(start_concept_id, end_concept_id)
);

-- Create indexes for better performance
CREATE INDEX idx_documents_user_id ON documents(user_id);
CREATE INDEX idx_documents_type ON documents(document_type);
CREATE INDEX idx_documents_status ON documents(processing_status);

CREATE INDEX idx_document_content_document_id ON document_content(document_id);

CREATE INDEX idx_concepts_document_id ON concepts(document_id);
CREATE INDEX idx_concepts_type ON concepts(concept_type);
CREATE INDEX idx_concepts_importance ON concepts(importance_score DESC);
CREATE INDEX idx_concepts_difficulty ON concepts(difficulty_level);

CREATE INDEX idx_concept_relationships_source ON concept_relationships(source_concept_id);
CREATE INDEX idx_concept_relationships_target ON concept_relationships(target_concept_id);
CREATE INDEX idx_concept_relationships_type ON concept_relationships(relationship_type);

CREATE INDEX idx_visual_elements_document_id ON visual_elements(document_id);
CREATE INDEX idx_visual_elements_concept_id ON visual_elements(concept_id);

CREATE INDEX idx_study_cards_concept_id ON study_cards(concept_id);
CREATE INDEX idx_study_cards_user_id ON study_cards(user_id);
CREATE INDEX idx_study_cards_type ON study_cards(card_type);

CREATE INDEX idx_user_progress_user_id ON user_progress(user_id);
CREATE INDEX idx_user_progress_concept_id ON user_progress(concept_id);
CREATE INDEX idx_user_progress_mastery ON user_progress(mastery_level);
CREATE INDEX idx_user_progress_next_review ON user_progress(next_review_at);

CREATE INDEX idx_study_sessions_user_id ON study_sessions(user_id);
CREATE INDEX idx_study_sessions_document_id ON study_sessions(document_id);
CREATE INDEX idx_study_sessions_started_at ON study_sessions(started_at);

CREATE INDEX idx_knowledge_paths_start ON knowledge_paths(start_concept_id);
CREATE INDEX idx_knowledge_paths_end ON knowledge_paths(end_concept_id);

-- Full-text search indexes
CREATE INDEX idx_concepts_title_fts ON concepts USING gin(to_tsvector('english', title));
CREATE INDEX idx_concepts_content_fts ON concepts USING gin(to_tsvector('english', content));
CREATE INDEX idx_document_content_fts ON document_content USING gin(to_tsvector('english', full_text));

-- Row Level Security (RLS) policies
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE document_content ENABLE ROW LEVEL SECURITY;
ALTER TABLE concepts ENABLE ROW LEVEL SECURITY;
ALTER TABLE concept_relationships ENABLE ROW LEVEL SECURITY;
ALTER TABLE visual_elements ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_sessions ENABLE ROW LEVEL SECURITY;

-- RLS Policies for user data access
CREATE POLICY "Users can access their own documents" ON documents
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can access content of their documents" ON document_content
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM documents 
            WHERE documents.id = document_content.document_id 
            AND documents.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can access concepts from their documents" ON concepts
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM documents 
            WHERE documents.id = concepts.document_id 
            AND documents.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can access relationships from their concepts" ON concept_relationships
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM concepts 
            JOIN documents ON documents.id = concepts.document_id
            WHERE (concepts.id = concept_relationships.source_concept_id 
                   OR concepts.id = concept_relationships.target_concept_id)
            AND documents.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can access visual elements from their documents" ON visual_elements
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM documents 
            WHERE documents.id = visual_elements.document_id 
            AND documents.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can access their own study cards" ON study_cards
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can access their own progress" ON user_progress
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can access their own study sessions" ON study_sessions
    FOR ALL USING (auth.uid() = user_id);

-- Functions for common operations

-- Function to get related concepts
CREATE OR REPLACE FUNCTION get_related_concepts(concept_uuid UUID, relationship_types TEXT[] DEFAULT NULL)
RETURNS TABLE(
    id UUID,
    title VARCHAR(500),
    content TEXT,
    concept_type VARCHAR(100),
    relationship_type VARCHAR(100),
    strength DECIMAL(3,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.title,
        c.content,
        c.concept_type,
        cr.relationship_type,
        cr.strength
    FROM concepts c
    JOIN concept_relationships cr ON (
        (cr.source_concept_id = concept_uuid AND cr.target_concept_id = c.id) OR
        (cr.target_concept_id = concept_uuid AND cr.source_concept_id = c.id AND cr.bidirectional = true)
    )
    WHERE relationship_types IS NULL OR cr.relationship_type = ANY(relationship_types)
    ORDER BY cr.strength DESC, c.importance_score DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to search concepts
CREATE OR REPLACE FUNCTION search_concepts(
    search_query TEXT,
    user_uuid UUID,
    limit_count INTEGER DEFAULT 20
)
RETURNS TABLE(
    id UUID,
    title VARCHAR(500),
    content TEXT,
    concept_type VARCHAR(100),
    importance_score DECIMAL(3,2),
    rank REAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.title,
        c.content,
        c.concept_type,
        c.importance_score,
        ts_rank(to_tsvector('english', c.title || ' ' || c.content), plainto_tsquery('english', search_query)) as rank
    FROM concepts c
    JOIN documents d ON d.id = c.document_id
    WHERE d.user_id = user_uuid
    AND (
        to_tsvector('english', c.title || ' ' || c.content) @@ plainto_tsquery('english', search_query)
    )
    ORDER BY rank DESC, c.importance_score DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;