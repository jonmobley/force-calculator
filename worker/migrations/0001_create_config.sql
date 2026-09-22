-- Performer configuration, one row per performer.
-- Single-performer today, so the app uses the fixed id 'default'. The primary
-- key is a TEXT id so additional performers can be added without a migration.
CREATE TABLE IF NOT EXISTS config (
  id         TEXT    PRIMARY KEY,
  payload    TEXT    NOT NULL,
  updated_at INTEGER NOT NULL
);
