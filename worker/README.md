# Force config service

Serves the performer's calculator settings to the App Clip.

## Why this exists

The App Clip runs on a **spectator's** device. It has no access to the
performer's app group container, so historically every setting was encoded into
the invocation URL written onto the NFC tag or QR code. That froze the settings
at the moment the tag was written: changing the force number later meant every
tag and printed code was wrong until it was rewritten.

The clip now reads its settings from this service at launch, so a tag written
once stays correct forever.

## Endpoints

| Method | Path         | Auth              | Purpose                             |
| ------ | ------------ | ----------------- | ----------------------------------- |
| `GET`  | `/v1/config` | none              | Current settings, read by clip      |
| `PUT`  | `/v1/config` | that id's token   | Replace settings, called by app     |
| `PUT`  | `/v1/peek`   | none              | Report the spectator's number       |
| `GET`  | `/v1/peek`   | that id's token   | Latest reported number, read by app |
| `GET`  | `/health`    | none              | Liveness probe                      |

Every route takes `?id=<performer>`, naming whose record to act on.

Deployed at `https://force-config.jonmobley.workers.dev` and `https://forcemagic.app`.

## One record per performer

Each install generates its own performer id and write token on first launch; there
is nothing for the performer to enter. The id is public and travels on the App Clip
URL printed into every QR code and NFC tag. The token stays in the device Keychain.

The first `PUT /v1/config` for an id stores a SHA-256 hash of its token in
`config.token_hash`, claiming that record. Afterwards only the same token may write
it or read its peeks.

Before this, every install shared the id `default` behind one service-wide token, so
a second performer changing their force number overwrote the first performer's, and
live peek returned whichever spectator had typed most recently regardless of who was
watching. Rows written back then have a `NULL` hash and stay on `WRITE_TOKEN`, so the
install that owns `default` is not locked out by the upgrade.

## Why D1 instead of KV

KV reads are served from an edge cache that can lag a write by up to 60 seconds.
A performer may change the force number seconds before handing over the phone, so
a stale read would silently break the trick. D1 gives read-after-write
consistency, and responses are sent with `cache-control: no-store` so no
intermediary can serve an old force number.

## Security model

Writes are gated on the token bound to the id being written, which lives only in
the performer's device Keychain and is stored here as a hash. `WRITE_TOKEN` remains
only to serve the pre-existing `default` row.

Config reads are unauthenticated because the clip runs on an arbitrary spectator's
device and has no way to hold a credential, so a payload is readable by anyone who
knows the id. That is not a regression: the force number used to be written in plain
text onto the NFC tag itself, where any tag reader could see it. Ids are 128 bits of
randomness precisely because reading needs no token.

Peek writes are unauthenticated for the same reason — the clip sending the
spectator's number can never hold a token. Peek *reads* require the id's token, so
only the performer sees what a spectator typed.

## Common tasks

```bash
npm install

# Deploy
npm run deploy

# Apply migrations
npm run migrate          # remote
npm run migrate:local    # local

# Rotate the legacy service-wide token, which now only covers the `default` row
npx wrangler secret put WRITE_TOKEN

# Validate and typecheck
npm run check
npm run typecheck

# Live logs
npm run tail
```

## Inspecting stored config

```bash
npx wrangler d1 execute force-config --remote \
  --command "SELECT id, updated_at, token_hash IS NOT NULL AS claimed, payload FROM config"
```
