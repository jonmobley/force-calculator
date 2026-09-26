-- Marks a config record as erased without freeing its id.
--
-- The privacy policy promises that unused settings are deleted, and an owner may ask
-- for theirs to go now. Dropping the row would return the id to the unclaimed pool, so
-- whoever next scanned a tag printed with it could claim it and lock the performer out.
-- An erased row keeps its `token_hash` and holds an empty payload instead; reads treat
-- it as unpublished, and the owner's next publish clears the mark.
ALTER TABLE config ADD COLUMN erased_at INTEGER;
