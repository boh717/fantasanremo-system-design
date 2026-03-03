CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TYPE artist_role AS ENUM ('Captain', 'Regular', 'Reserve');
CREATE TYPE league_visibility AS ENUM ('Public', 'Private');
CREATE TYPE message_status AS ENUM ('Pending', 'Processing', 'Processed', 'Failed');

CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    external_id UUID DEFAULT uuid_generate_v4() NOT NULL UNIQUE,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    salt TEXT NOT NULL,
    name TEXT NOT NULL,
    image_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- score_history is a JSONB object that contains the score for each day
-- {
--     "day1": {
--         "total_points": "<score_for_the_day>",
--         "artists": [
--             {
--                 "id": "<artist_id>",
--                 "role_for_the_day": "<artist_role>",
--                 "points": [
--                     {
--                         "id": "<point_id>",
--                         "value": "<point_value>",
--                         "applies_to_reserve": true
--                     }
--                 ]
--             }
--         ]
--     }
-- }

CREATE TABLE teams (
    id BIGSERIAL PRIMARY KEY,
    external_id UUID DEFAULT uuid_generate_v4() NOT NULL UNIQUE,
    name TEXT NOT NULL,
    image_url TEXT,
    cost INT NOT NULL,
    score INT NOT NULL DEFAULT 0,
    score_history JSONB NOT NULL DEFAULT '{}'::jsonb,
    user_id BIGINT NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (name, user_id)
);

CREATE TABLE leagues (
    id BIGSERIAL PRIMARY KEY,
    external_id UUID DEFAULT uuid_generate_v4() NOT NULL UNIQUE,
    name TEXT NOT NULL,
    image_url TEXT,
    join_code TEXT NOT NULL UNIQUE,
    visibility league_visibility NOT NULL DEFAULT 'Public',
    created_by BIGINT NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE team_leagues (
    team_id BIGINT REFERENCES teams(id),
    league_id BIGINT REFERENCES leagues(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (team_id, league_id)
);

CREATE TABLE artists (
    id BIGSERIAL PRIMARY KEY,
    external_id UUID DEFAULT uuid_generate_v4() NOT NULL UNIQUE,
    full_name TEXT NOT NULL,
    song_title TEXT NOT NULL,
    image_url TEXT,
    price INT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);


CREATE TABLE team_artists (
    team_id BIGINT REFERENCES teams(id),
    artist_id BIGINT REFERENCES artists(id),
    role artist_role NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (team_id, artist_id)
);

CREATE TABLE points (
    id BIGSERIAL PRIMARY KEY,
    description TEXT NOT NULL,
    value INT NOT NULL,
    applies_to_reserve BOOLEAN NOT NULL,
    valid_for_date DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE artist_points (
    artist_id BIGINT NOT NULL REFERENCES artists(id),
    point_id BIGINT NOT NULL REFERENCES points(id),
    earned_at DATE NOT NULL,
    PRIMARY KEY (artist_id, point_id, earned_at)
);

CREATE TABLE achievements (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    target_count INT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE user_achievements (
    user_id BIGINT NOT NULL REFERENCES users(id),
    achievement_id BIGINT NOT NULL REFERENCES achievements(id),
    current_progress INT NOT NULL DEFAULT 0,
    completed BOOLEAN NOT NULL DEFAULT FALSE,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, achievement_id)
);

CREATE TABLE messages (
    id BIGSERIAL PRIMARY KEY,
    message_type TEXT NOT NULL,
    message_data JSONB NOT NULL,
    status message_status NOT NULL DEFAULT 'Pending',
    error_message TEXT,
    retry_count INT NOT NULL DEFAULT 0,
    last_retry_at TIMESTAMPTZ,
    processed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_teams_updated_at BEFORE UPDATE ON teams FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_leagues_updated_at BEFORE UPDATE ON leagues FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_artists_updated_at BEFORE UPDATE ON artists FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_team_artists_updated_at BEFORE UPDATE ON team_artists FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_points_updated_at BEFORE UPDATE ON points FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_achievements_updated_at BEFORE UPDATE ON achievements FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_user_achievements_updated_at BEFORE UPDATE ON user_achievements FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_messages_updated_at BEFORE UPDATE ON messages FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX idx_users_external_id ON users(external_id);
CREATE INDEX idx_teams_external_id ON teams(external_id);
CREATE INDEX idx_leagues_external_id ON leagues(external_id);
CREATE UNIQUE INDEX idx_team_artists_one_captain ON team_artists(team_id) WHERE role = 'Captain';
CREATE INDEX idx_teams_score ON teams(score DESC);
CREATE INDEX idx_points_valid_for_date ON points(valid_for_date);
CREATE INDEX idx_messages_pending ON messages(status) WHERE status = 'Pending';
CREATE INDEX idx_user_achievements_user_id ON user_achievements(user_id);
CREATE INDEX idx_user_achievements_achievement_id ON user_achievements(achievement_id);
