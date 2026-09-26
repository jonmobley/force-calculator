# Force audit — September 2026

Scope: the Force app (`Force/`), the App Clip (`ForceClip/`), the shared framework (`Shared/`),
the tests (`ForceTests/`), the Cloudflare Worker (`worker/`), and the submission material in
`AppStore/`.

Status key: **Fixed** means fixed on branch `cursor/app-audit-fixes-7a6e`. **Backlog** means
recorded here and not changed. **Decision** needs a product call before anything changes.

## Summary

| Area | Critical | High | Medium | Low |
|---|---|---|---|---|
| Correctness (Swift) | 1 | 4 | 10 | 8 |
| Security (Worker) | 0 | 2 | 5 | 6 |
| App Store and privacy | 1 | 4 | 7 | 5 |
| Code quality and tests | — | 4 | 5 | — |

The most important items:

1. The Perfect Plus number never reaches the readout. Both calculators show `100+` instead of
   `100+4,556,225`, so the main effect fails on screen. **Fixed.**
2. Live Peek sends what the spectator types from the App Clip to the server without telling
   them. This is the biggest App Review risk (guidelines 5.1.1 and 5.1.2). **Decision.**
3. The first claim of a performer id on the Worker can race, and the app shows the QR and NFC
   link before the claim has landed. Someone who sees the code first can lock the performer out
   of every tag printed with it. **Fixed.**
4. The privacy manifests and the App Privacy checklist don't declare the performer id, and the
   Force manifest is missing the App Group UserDefaults reason code. **Fixed.**

---

## 1. Correctness (Swift)

### Critical

**C1. Perfect Plus number hidden by `expressionDisplay`** — **Fixed**
`Shared/PerfectPlusHandler.swift` `calculatePerfectAddend` puts the number in `display`, leaves
`operation = .add` pending and sets `userIsTyping = false`. `CalculatorState.expressionDisplay`
only shows the second operand while typing, so both `CalculatorView`s showed `100+`. The tests
checked `display`, not what the readout shows. Fix: `CalculatorState.stagedOperand` keeps the
number in the readout until the next key, and a test checks `expressionDisplay`.

### High

**H1. Result formatting follows the device locale** — **Fixed**
`Shared/CalculatorFormatter.swift` `grouped` and `scientific` left the `NumberFormatter` on the
current locale. On a comma-decimal locale, `12.5` became `12,5`, and `parseDisplay` read that
back as `125`. Fix: every formatter is pinned to `en_US_POSIX` with `.` and `,`.

**H2. A long press on equals also presses equals** — **Fixed**
`Shared/EqualsButtonWithPeek.swift` runs the `Button` action on release even after the
long-press peek has shown, so a glance at the force number advanced the activation count.
Fix: a press that peeked no longer runs the action, and the timer stops when the view goes away.

**H3. `ac` (activation count) from links and config is not range-checked** — **Fixed**
`Shared/AppClipQuery.swift` accepted any `Int`. Zero or a negative number made every equals press
a force. The settings screen allows 1 to 10. Fix: clamped to `1...10` on URL apply and on decode.

**H4. `fn` (force number) from links and config is not range-checked** — **Fixed**
Negative numbers or numbers over ten digits got past `ForceNumberEditor`'s limits. Fix: clamped
to `0...9_999_999_999` (what the editor accepts) on URL apply and on decode. Both ranges now live
on `CalculatorSettings`, and the settings picker uses the same one.

### Medium

| # | Finding | Where | Status |
|---|---|---|---|
| M1 | The Perfect Plus number reaches the Live Peek transcript. `peekSuppressed` was only true for `armed`/`staged`, and equals checked it after the reveal had reset the trick, so the staged number was reported as if typed. Now suppressed while it is on screen, and read before evaluating. | `ForceClip/CalculatorView.swift` `peekSuppressed` | **Fixed** |
| M2 | The clear key differs between the two calculators. The host toggles clear-entry / clear-all, the Clip always clears everything. | `Force/CalculatorView.swift` `hasEntryToClear`; `ForceClip/CalculatorView.swift` clear | Backlog |
| M3 | Quick Force truncates decimals: `12.5` passes the range check and becomes `12`. | `Shared/QuickForceEntry.swift` ~152-158 | Backlog |
| M4 | Floating-point tails. `0.1 + 0.2` can show a long fraction; a stock calculator rounds for display. | `Shared/CalculatorFormatter.swift` `grouped` | Backlog |
| M5 | The host's long-press mode toggle writes to settings, so it autosaves and publishes mid-show. The Clip keeps it for the session only. | `Force/CalculatorView.swift` ~225 | Backlog |
| M6 | The host calculator ignores Perfect Plus haptics changes while open. The Clip has the `onChange`. | `Force/CalculatorView.swift` | Backlog |
| M7 | Keychain save failures are ignored, so a relaunch can mint a new id and strand printed tags. | `Force/PerformerCredentials.swift` ~84; `Force/ConfigTokenStore.swift` ~51-75 | Backlog |
| M8 | Image save and load failures are swallowed. Undecodable legacy UserDefaults image data is never cleared, so migration retries forever. | `Force/ImageStorageManager.swift`; `Force/ContentView.swift` ~185 | Backlog |
| M9 | `URL(string:)!` in the NFC writer crashes on a malformed string. | `Force/NFCWriter.swift` ~92 | **Fixed** |
| M10 | A failed peek upload is dropped after one retry and the performer gets no sign that peek is stale. | `Shared/PeekUploader.swift` ~81-98 | Backlog (by design; product risk) |

### Low

- Leading zeros are lost in Date and Time forces because the value is an `Int` (`0102261205`
  shows as `102,261,205`). `Shared/DateTimeNumber.swift`. Backlog.
- `toggleSign` skips `"0"` but not `"0."`. `Shared/CalculatorOperations.swift` ~112. Backlog.
- Typing stops at nine digits while forces can show ten. By design, but asymmetric.
- `PerfectPlusHandler` and `PeekReporter` are not `@MainActor`; they rely on callers.
- Activation count allows 1 to 10 in settings but only up to 9 through Quick Force.
- The published settings include `currentCount`, which the Clip applies, so a fetch can reset a
  spectator's progress. Publish a dedicated public DTO instead. `Shared/CalculatorSettings.swift`.
- Division by zero, NaN and infinity are handled (`Error`, `∞`). OK.
- Negative operands and negative Perfect Plus numbers work. OK.

---

## 2. Security (Worker)

Done well: per-install id plus a SHA-256 `token_hash`; peek reads need a matched token; all D1
queries are parameterized; ids are allowlisted; request bodies are streamed with a size cap;
`cache-control: no-store`; no secrets in `wrangler.jsonc`; the token lives in the Keychain, out
of the App Group the Clip can see; 401 bodies are uniform.

### High

**S1. The first claim of an id races** — **Fixed**
`authorize()` returned `claim` for an unknown id, then `writeConfig` upserted with
`COALESCE(config.token_hash, excluded.token_hash)`. Two first writers both passed; the loser
lost the id but still overwrote the payload. Fix: a claim is an `INSERT ... ON CONFLICT DO
NOTHING`, and a write to a claimed id is an `UPDATE ... WHERE token_hash = ?`. A write that
changes no row is re-authorized once and otherwise gets a 401.

**S2. The app shows the id before the claim lands** — **Fixed**
`Force/QRCodeNFCView.swift` built the QR code, the NFC payload and the copy link from the id as
soon as it was minted. Anyone who saw it before the first `PUT` succeeded could claim it. Fix:
the QR code and NFC writer appear only once a publish has succeeded for this id. That is
remembered across launches, so an offline performer can still write tags later.

### Medium

| # | Finding | Where | Status |
|---|---|---|---|
| S3 | Anyone who knows an id can post peeks while Live Peek is on. The rate limit (100 per 10 s) is enough to flood the 40-entry tape. Options: a per-session nonce published with the config, or keep only the first session's entries. | `worker/src/peek.ts` ~120-185 | Backlog |
| S4 | Rows with no `token_hash` still accept the shared `WRITE_TOKEN`, so pre-tenancy installs on `id=default` share one record. The next legacy write now binds the row to that token's hash (`COALESCE`, so only where none is set), and the README gives the check to run before rotating the secret. Installs that still share `default` keep sharing it until they move to their own id. | `worker/src/config.ts` `storeConfig` | **Fixed** (rotate after deploy) |
| S5 | Config writes had no rate limit, so ids could be squatted in bulk. Now `CONFIG_WRITE_LIMIT`, 30 per 60 s per `cf-connecting-ip`, checked before the token so unclaimed ids are covered too; 429 when exceeded. | `worker/src/config.ts` `writeConfig`, `wrangler.jsonc` | **Fixed** |
| S6 | Observability samples every request (`head_sampling_rate: 1`), so logs can keep `Authorization` headers. Lower it and redact. | `worker/wrangler.jsonc` ~14 | Backlog |
| S7 | Config was never deleted although the privacy page said unused settings are. Now `DELETE /v1/config` for the owner, and the cron erases configs not published to in 365 days. Erasing sets the payload to `{}` and `erased_at`, deletes the id's peeks, and keeps `token_hash` so a printed id cannot be re-claimed; the owner's next publish revives it. The privacy page says settings are erased after a year without the app being opened. | `worker/src/retention.ts`, `migrations/0005_add_erased_at.sql` | **Fixed** |

### Low

- The legacy plaintext comparison returned early on a length mismatch. Both sides are now
  hashed with `sha256Hex` before `constantTimeEqual`. `worker/src/peek.ts` `authorize`. **Fixed.**
- `Access-Control-Allow-Origin: *` on API routes. The native clients don't need CORS. Backlog.
- Peek values are only charset-checked (`......` passes). Backlog.
- `GET /v1/config` is public, so anyone with the id can read the force number. Documented and
  inherent while the Clip has no secret.
- The README API table was missing `DELETE /v1/peek`. **Fixed.**
- There are no R2 or KV bindings. Screenshots stay on the device.

---

## 3. App Store and privacy

Checked and fine: bundle ids, versions and build numbers, iOS 17 iPhone-only, App Clip embedding,
NFC and Photo Library Add usage strings, `ITSAppUsesNonExemptEncryption = NO`, both 1024 icons
without alpha, 1320×2868 screenshots, debug logging behind `#if DEBUG`, no `.p8` in git.

### Critical

**A1. Live Peek uploads the spectator's input without telling them** — **Decision**
`ForceClip/CalculatorView.swift` reports each entry through `Shared/PeekReporter.swift` to
`PUT /v1/peek`. The spectator sees an ordinary calculator. The review notes and privacy policy
speak to the performer, not to the person whose input is sent. Options:

1. Show a brief notice in the Clip while Live Peek is on (weakens the trick).
2. Keep peek local (Multipeer Connectivity between the two phones), so nothing leaves for a server.
3. Leave Live Peek out of the first release and ship it after review.
4. Keep it as is and rely on the review-note disclosure (the current approach; highest risk).

### High

| # | Finding | Where | Status |
|---|---|---|---|
| A2 | The Force manifest and the App Privacy checklist don't declare the persistent performer id, and user content is marked not linked. Now User ID plus linked content in the Force manifest and checklist. The Clip manifest stays not linked, because the spectator's input is stored under the performer's id and nothing identifies the spectator; its outdated comment is corrected. | `Force/PrivacyInfo.xcprivacy`, `ForceClip/PrivacyInfo.xcprivacy`, `AppStore/ASC-SETUP.md` | **Fixed** |
| A3 | The Force manifest gives only `CA92.1` for UserDefaults, but settings use an App Group suite, which needs `1C8F.1`. | `Force/PrivacyInfo.xcprivacy`; `Shared/CalculatorSettings.swift` | **Fixed** |
| A4 | "Start with Screenshot" imitates the Home Screen and the calculator looks stock. Disclosed in the review notes, but Review may still object (2.3.1). Attach a demo video. | `Force/ScreenshotView.swift`; `AppStore/REVIEW-NOTES.md` | Backlog |
| A5 | Config is publicly readable by id (see Worker). Make sure the privacy page says so. | `Shared/ForceConfigService.swift` | Backlog |

### Medium

- The App Clip has the App Group entitlement but is designed not to use it.
  `ForceClip/ForceClip.entitlements`. Backlog.
- The ASC API key id is in the repo (not the `.p8`). `AppStore/ASC-SETUP.md`, `asc-ship.sh`.
  Backlog.
- Contact emails differ: `jonmobley@gmail.com` in ASC-SETUP and support, `jon.mobley@me.com` on
  the privacy page (`worker/src/index.ts`). Backlog.
- The Clip polls config every two seconds and samples motion at 10 Hz. Poll only while peek can
  turn on; start motion only when Perfect Plus is on. Backlog.
- `forcemagic.app` has no AASA file, so only the default App Clip links work. Backlog.
- The review notes are about 3,900 of 4,000 characters. Backlog.
- Unauthenticated peek writes (see S3).

### Low

- A real performer id is hardcoded in `Force.xcodeproj/xcshareddata/xcschemes/ForceClip.xcscheme`.
- `Shared` has no privacy manifest of its own (the host manifests cover it today).
- App Clip size has not been measured; archive and check in Organizer before submitting.
- The D1 `database_id` is in `wrangler.jsonc` (not a credential).
- `Force/Info.plist` is empty; fine with generated Info.plist keys.

---

## 4. Code quality and tests

### High

- **Duplicated calculator glue.** `Force/CalculatorView.swift` (264) and
  `ForceClip/CalculatorView.swift` (309) share about thirteen helpers that are 74-100% identical
  (`calculatePerfectAddend`, `digitPressed`, `toggleQuickEntry`, `scheduleModeHide`). The clear-key
  drift (M2) came from this. Move the key handling into `Shared/`. Backlog.
- **No CI.** There was no `.github/`. `.github/workflows/ci.yml` now runs `xcodebuild test` on a
  macOS runner and `npm ci`, `npm run typecheck`, `npm run check` and `npm test` for the Worker
  on every pull request. **Fixed.**
- **No Worker tests** and no lint. `worker/package.json` had only `typecheck` and `check`, and
  `npm run check` failed on the installed Wrangler 4. `check` is now a dry-run deploy, and
  `npm test` runs Vitest inside `workerd` through `@cloudflare/vitest-plugin` against the real
  D1 migrations: ownership, the claim race, the legacy token, erasing, the retention sweep, the
  config write limit, and peek gating, reads and clears. Still no lint. **Fixed.**
- **`ForceConfigService` has no tests.** Stub `URLSession` with a `URLProtocol` subclass. Backlog.

### Medium (Backlog)

- Files over 300 lines: `ForceTests/ForceLogicTests.swift` (546),
  `Shared/PerfectPlusHandler.swift` (338), `ForceClip/CalculatorView.swift` (309). Split
  `ForceLogicTests` by domain.
- `body` over 50 lines: `Force/QRCodeNFCView.swift` (57), `Force/CalculatorView.swift` (56).
- 59 lines over 100 columns, worst in `ForceTests/ForceLogicTests.swift` (17),
  `Shared/CalculatorSettings.swift` (7) and `Force/PhotoLibraryManager.swift` (6).
- MARK comments are in 22 of 64 files; none in `ForceClip/`.
- Missing doc comments: `CalculatorOperations` functions, `CalculatorEvaluation.performOperation`
  and `equals`, `PerfectPlusHandler.stopMonitoring`, many `public init`s, and most top-level types
  in `Force/`.

### Coverage map

| Module | Coverage |
|---|---|
| PerfectPlusMath, AppClipQuery, DateTimeNumber, QuickForceEntry, PeekReporter, PeekUploader | Good |
| PerfectPlusHandler, ForceActivation, CalculatorSettings, CalculatorOperations | Through flow tests |
| CalculatorFormatter | `formatResult` only until this branch; now also locale round-trip |
| ForceConfigService | None |
| UI (keypad, readout, NFC, QR, image storage) | None (expected) |

All Swift files are members of their targets through synchronized root groups; there are no
orphan files.

---

## Verification on this branch

- Worker: `npm run typecheck` passes. The claim fix was run against `wrangler dev` with a local
  D1. Of 20 concurrent first claims with different tokens, one got 204 and its payload is the one
  stored. The same install publishing twice at once succeeds. The legacy `WRITE_TOKEN` row still
  accepts that token and rejects others. On the old code all 20 got 204 and a loser's payload
  was stored. Those checks, plus erasing, the retention sweep, the write limit and peek, are
  now `npm test` (24 tests under `workerd`), and `npm run check` dry-runs the deploy.
- Swift: every file parses with Swift 6.4 on Linux. `CalculatorFormatter` was compiled and run
  there: the new tests' assertions pass, output on an English device is unchanged, and the old
  code on a `de_DE` formatter turns `12.5` into `12,5`, which parses back as `125`.
- Not run: SwiftUI, UIKit, CoreMotion, Security and XCTest cannot build on Linux, so
  `xcodebuild test -scheme Force` still has to run on a Mac. New tests:
  `CalculatorFormatterTests`, `SettingsLimitsTests`, two in `PerfectPlusFlowTests`, and two in
  `ConfigPublishingTests`.
