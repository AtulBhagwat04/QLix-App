-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Drop existing types and tables if they exist (for clean initialization)
DROP TABLE IF EXISTS templates CASCADE;
DROP TABLE IF EXISTS announcements CASCADE;
DROP TABLE IF EXISTS quiz_scores CASCADE;
DROP TABLE IF EXISTS question_upvotes CASCADE;
DROP TABLE IF EXISTS questions CASCADE;
DROP TABLE IF EXISTS votes CASCADE;
DROP TABLE IF EXISTS poll_options CASCADE;
DROP TABLE IF EXISTS polls CASCADE;
DROP TABLE IF EXISTS participants CASCADE;
DROP TABLE IF EXISTS sessions CASCADE;
DROP TABLE IF EXISTS users CASCADE;

DROP TYPE IF EXISTS question_status CASCADE;
DROP TYPE IF EXISTS poll_status CASCADE;
DROP TYPE IF EXISTS poll_type CASCADE;
DROP TYPE IF EXISTS session_state CASCADE;

-- Role/State Enums
CREATE TYPE session_state AS ENUM ('draft', 'active', 'ended');
CREATE TYPE poll_type AS ENUM ('multiple_choice', 'word_cloud', 'rating', 'open_text', 'ranking', 'survey');
CREATE TYPE poll_status AS ENUM ('draft', 'active', 'locked', 'ended');
CREATE TYPE question_status AS ENUM ('pending', 'approved', 'answered', 'dismissed');

-- Users Table (Hosts)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Sessions Table
CREATE TABLE sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    access_code VARCHAR(6) UNIQUE NOT NULL, -- 6-digit session code (e.g., 123456)
    host_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    state session_state DEFAULT 'draft',
    is_presenter_mode_active BOOLEAN DEFAULT false,
    active_poll_id UUID, -- NULL if no poll is active
    active_quiz_question_id UUID,
    settings JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Participants Table
CREATE TABLE participants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    device_id VARCHAR(255) NOT NULL,
    name VARCHAR(100) DEFAULT 'Anonymous',
    is_anonymous BOOLEAN DEFAULT true,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX idx_participant_session_device ON participants(session_id, device_id);

-- Polls Table
CREATE TABLE polls (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    type poll_type NOT NULL,
    status poll_status DEFAULT 'draft',
    order_index INT NOT NULL DEFAULT 0,
    settings JSONB DEFAULT '{}', -- stores configs like multi-select limits, star rating limits, correct answer keys
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Poll Options Table
CREATE TABLE poll_options (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    poll_id UUID NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
    option_text TEXT NOT NULL,
    is_correct BOOLEAN DEFAULT false,
    order_index INT NOT NULL DEFAULT 0
);

-- Votes Table
CREATE TABLE votes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    poll_id UUID NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
    option_id UUID REFERENCES poll_options(id) ON DELETE CASCADE, -- Null for open text or word cloud
    participant_id UUID NOT NULL REFERENCES participants(id) ON DELETE CASCADE,
    rating_value INT, -- For rating polls
    text_response TEXT, -- For word cloud and open text
    rank_value INT, -- For ranking polls
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Ensure a participant can only vote once per option, or once per poll depending on logic
-- For MC, Rating, Ranking, Open Text, Survey: usually once per poll, or multiple if multi-select
-- To be safe and generic, we enforce unique constraint on (poll_id, participant_id, option_id) to allow multi-select options, 
-- and check single-select in code transaction.
CREATE UNIQUE INDEX idx_votes_poll_participant_option ON votes(poll_id, participant_id, COALESCE(option_id, '00000000-0000-0000-0000-000000000000'::uuid));

-- Q&A Questions Table
CREATE TABLE questions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    participant_id UUID NOT NULL REFERENCES participants(id) ON DELETE CASCADE,
    text TEXT NOT NULL,
    is_anonymous BOOLEAN DEFAULT true,
    status question_status DEFAULT 'pending',
    upvotes_count INT DEFAULT 0,
    is_pinned BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Question Upvotes Table (Prevents double upvoting)
CREATE TABLE question_upvotes (
    question_id UUID NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
    participant_id UUID NOT NULL REFERENCES participants(id) ON DELETE CASCADE,
    PRIMARY KEY (question_id, participant_id)
);

-- Quiz Scores Table
CREATE TABLE quiz_scores (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    participant_id UUID NOT NULL REFERENCES participants(id) ON DELETE CASCADE,
    score INT DEFAULT 0,
    last_answered_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX idx_quiz_scores_session_participant ON quiz_scores(session_id, participant_id);

-- Announcements Table
CREATE TABLE announcements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Templates Table
CREATE TABLE templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    structure JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance optimizations
CREATE INDEX idx_sessions_access_code ON sessions(access_code);
CREATE INDEX idx_polls_session_id ON polls(session_id);
CREATE INDEX idx_poll_options_poll_id ON poll_options(poll_id);
CREATE INDEX idx_questions_session_id ON questions(session_id);
CREATE INDEX idx_votes_poll_id ON votes(poll_id);
