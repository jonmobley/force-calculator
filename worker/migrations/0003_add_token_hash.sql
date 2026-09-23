-- Binds a config record to the credentials that created it.
--
-- Every install used to publish to the single id `default` behind one service-wide
-- token, so any performer could overwrite another's force number and read another's
-- live peek. Each install now generates its own id and token; the first write to an id
-- stores the hash of its token here, and later writes must present the same one.
--
-- Rows written before this column existed keep a NULL hash and stay on the service-wide
-- token, so an install that was already publishing is not locked out of its own record.
ALTER TABLE config ADD COLUMN token_hash TEXT;
