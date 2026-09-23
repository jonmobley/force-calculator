-- The spectator's whole calculation, rather than only the last thing they typed.
--
-- `peek` held one row per performer and overwrote it on every report, so a spectator
-- working through `123 + 456 =` left the performer looking at `579` with no idea what
-- produced it. Each settled number now gets its own row, and the operator that ended it
-- is attached afterwards, so the performer reads the arithmetic rather than guessing.
--
-- `entry_id` is minted by the clip and carries its session, so a report can be updated
-- in place when the operator lands without a second row appearing. Old rows are pruned
-- on write; the `peek` table stays as it is so an older clip keeps working.
CREATE TABLE IF NOT EXISTS peek_entry (
  id         TEXT    NOT NULL,
  entry_id   TEXT    NOT NULL,
  value      TEXT    NOT NULL,
  -- The key pressed after this number: +, −, ×, ÷, %, or =. NULL while it is still
  -- the number on screen and nothing has closed it yet.
  op         TEXT,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (id, entry_id)
);

CREATE INDEX IF NOT EXISTS peek_entry_recent ON peek_entry (id, created_at);
