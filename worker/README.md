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

| Method | Path             | Auth         | Purpose                          |
| ------ | ---------------- | ------------ | -------------------------------- |
| `GET`  | `/v1/config`     | none         | Current settings, read by clip   |
| `PUT`  | `/v1/config`     | bearer token | Replace settings, called by app  |
| `GET`  | `/health`        | none         | Liveness probe                   |

Both config routes accept an optional `?id=` parameter. The app uses `default`.
The column is a `TEXT` primary key so more performers can be added later without
a schema change.

Deployed at `https://force-config.jonmobley.workers.dev`.

## Why D1 instead of KV

KV reads are served from an edge cache that can lag a write by up to 60 seconds.
A performer may change the force number seconds before handing over the phone, so
a stale read would silently break the trick. D1 gives read-after-write
consistency, and responses are sent with `cache-control: no-store` so no
intermediary can serve an old force number.

## Security model

The write token gates all writes and lives only as a Worker secret and in the
performer's device keychain — it is never committed. Reads are unauthenticated
because the clip runs on an arbitrary spectator's device and has no way to hold a
credential. The payload is therefore readable by anyone who knows the URL. That
is not a regression: previously the force number was written in plain text onto
the NFC tag itself, where any tag reader could see it.

## Common tasks

```bash
npm install

# Deploy
npm run deploy

# Apply migrations
npm run migrate          # remote
npm run migrate:local    # local

# Rotate the write token (then update it in the app)
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
  --command "SELECT id, updated_at, payload FROM config"
```
