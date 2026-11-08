-- InIba database schema (PostgreSQL)

CREATE TABLE users (
    id              SERIAL PRIMARY KEY,
    email           VARCHAR(255) UNIQUE NOT NULL CHECK (email LIKE '%@khi.iba.edu.pk'),
    password_hash   VARCHAR(255) NOT NULL,
    full_name       VARCHAR(100),
    batch           INT,
    department      VARCHAR(50),
    bio             VARCHAR(200),
    mood            VARCHAR(30),
    mood_set_at     TIMESTAMP,
    profile_photo_url TEXT,
    is_verified     BOOLEAN NOT NULL DEFAULT FALSE,
    is_admin        BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE societies (
    id    SERIAL PRIMARY KEY,
    name  VARCHAR(100) UNIQUE NOT NULL
);

CREATE TABLE user_societies (
    user_id     INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    society_id  INT NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, society_id)
);

CREATE TABLE otp_codes (
    id          SERIAL PRIMARY KEY,
    user_id     INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    code        CHAR(6) NOT NULL,
    expires_at  TIMESTAMP NOT NULL,
    attempts    INT NOT NULL DEFAULT 0,
    used        BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE posts (
    id              SERIAL PRIMARY KEY,
    user_id         INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    post_type       VARCHAR(10) NOT NULL CHECK (post_type IN ('moment', 'text')),
    front_image_url TEXT,
    back_image_url  TEXT,
    caption         VARCHAR(300),
    campus_zone     VARCHAR(30),
    is_hidden       BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_posts_created ON posts (created_at DESC);
CREATE INDEX idx_posts_user ON posts (user_id);

CREATE TABLE reactions (
    id          SERIAL PRIMARY KEY,
    post_id     INT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id     INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    emoji       VARCHAR(10) NOT NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (post_id, user_id)
);

CREATE TABLE comments (
    id          SERIAL PRIMARY KEY,
    post_id     INT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id     INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    body        VARCHAR(300) NOT NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE reports (
    id               SERIAL PRIMARY KEY,
    post_id          INT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    reported_by      INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reason           VARCHAR(30) NOT NULL,
    status           VARCHAR(10) NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'removed', 'ignored')),
    created_at       TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (post_id, reported_by)
);

CREATE TABLE highlights (
    id          SERIAL PRIMARY KEY,
    user_id     INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title       VARCHAR(50) NOT NULL,
    cover_url   TEXT
);

CREATE TABLE highlight_posts (
    highlight_id INT NOT NULL REFERENCES highlights(id) ON DELETE CASCADE,
    post_id      INT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    PRIMARY KEY (highlight_id, post_id)
);

CREATE TABLE feedback (
    id          SERIAL PRIMARY KEY,
    user_id     INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    rating      INT CHECK (rating BETWEEN 1 AND 5),
    message     TEXT,
    created_at  TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO societies (name) VALUES
    ('Animation & Pop Culture Society'), ('Computer Science Society'),
    ('Debating Society'), ('Maths & Astronomy Society');
