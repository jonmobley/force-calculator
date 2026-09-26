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
| `DELETE` | `/v1/config` | that id's token | Erase settings and peeks for the id |
| `PUT`  | `/v1/peek`   | none              | Report the spectator's number       |
| `GET`  | `/v1/peek`   | that id's token   | Latest reported number, read by app |
| `DELETE` | `/v1/peek` | that id's token   | Clear it between spectators         |
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

## Retention

The privacy policy says settings are erased after a year without the app being opened.
The cron (`*/5 * * * *`, the same one that prunes peeks) runs `eraseUnusedConfigs` in
`src/retention.ts`, which erases every `config` row whose `updated_at` is older than 365
days. The app publishes on launch and on every settings change, so `updated_at` tracks
the last time it was opened. `DELETE /v1/config`, with the id's token, does the same
thing immediately for one id.

Erasing does not drop the row. The id is printed on the performer's QR codes and NFC
tags, and a dropped row would return it to the unclaimed pool for whoever scanned one
next. Instead the payload becomes `{}`, `erased_at` is set, and `token_hash` stays, so
the id remains bound to its install. The id's `peek_entry` and `peek` rows are deleted.
`GET /v1/config` ignores rows with `erased_at` set and answers 404 as if nothing had
been published, `PUT /v1/peek` sees no `livePeekEnabled` and refuses, and the owner's
next `PUT /v1/config` clears `erased_at` and brings the record back.

## Rate limits

`PEEK_WRITE_LIMIT` caps unauthenticated peek writes at 100 per 10 seconds per performer
id. `CONFIG_WRITE_LIMIT` caps config writes at 30 per 60 seconds per client IP
(`cf-connecting-ip`); it is checked before the token, so an unclaimed id, which has no
owner to key on, still cannot be squatted in bulk. Either returns 429.

## Why D1 instead of KV

KV reads are served from an edge cache that can lag a write by up to 60 seconds.
A performer may change the force number seconds before handing over the phone, so
a stale read would silently break the trick. D1 gives read-after-write
consistency, and responses are sent with `cache-control: no-store` so no
intermediary can serve an old force number.

## Security model

Writes are gated on the token bound to the id being written, which lives only in
the performer's device Keychain and is stored here as a hash. `WRITE_TOKEN` remains
only to serve the pre-existing `default` row. Both comparisons hash the presented
token and compare the digests in constant time, so neither the stored hash nor the
length of `WRITE_TOKEN` can be probed through timing.

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

# Apply migrations, then deploy. Always in that order: the code assumes every
# column its migrations add (0005 adds `erased_at`, which reads and the cron use),
# so deploying first would 500 until the migration lands.
npm run migrate          # remote
npm run deploy

# Local D1 for `wrangler dev`
npm run migrate:local

# Rotate the legacy service-wide token, which now only covers the `default` row
npx wrangler secret put WRITE_TOKEN

# Validate, typecheck and test
npm run check
npm run typecheck
npm test

# Live logs
npm run tail
```

## Tests

`npm test` runs Vitest inside `workerd` through `@cloudflare/vitest-plugin`, so the
tests exercise the real D1, rate-limit and crypto bindings rather than mocks.
`vitest.config.mts` reads `wrangler.jsonc` for the bindings, loads `migrations/` into a
test-only `TEST_MIGRATIONS` binding, and `test/apply-migrations.ts` applies them before
each test file. Storage is rolled back between tests; rate-limit counters are not, so
tests that write config use a fresh `cf-connecting-ip` each. `WRITE_TOKEN` is set to a
fixed value under test.

Adding dev dependencies: use `npx npm@11 install -D <package>`. npm 10's resolver
fails on this tree with `Cannot read properties of null (reading 'edgesOut')`. The
lockfile npm 11 writes installs fine with a plain `npm ci` on npm 10, which is what
CI runs.

CI (`.github/workflows/ci.yml`) runs `npm ci`, `npm run typecheck`, `npm run check` and
`npm test` for the Worker on every pull request.

## Inspecting stored config

```bash
npx wrangler d1 execute force-config --remote \
  --command "SELECT id, updated_at, erased_at, token_hash IS NOT NULL AS claimed, payload FROM config"
```
