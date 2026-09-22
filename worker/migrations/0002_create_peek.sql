-- Live peek, one row per performer.
-- Holds the number a spectator is currently typing into the App Clip so the
-- performer's app can read it back. Ephemeral by nature: each write overwrites
-- the previous value, so nothing accumulates. Keyed by the same performer id as
-- `config` (single-performer today, fixed id 'default').
CREATE TABLE IF NOT EXISTS peek (
  id         TEXT    PRIMARY KEY,
  value      TEXT    NOT NULL,
  updated_at INTEGER NOT NULL
);
