/**
 * Force calculator configuration and live-peek service.
 *
 * The App Clip runs on a spectator's device and cannot see the performer's
 * settings, so it fetches them here at launch. The performer's app publishes
 * settings whenever they change, which lets a written NFC tag or printed QR code
 * stay valid forever instead of freezing a snapshot of the settings.
 *
 * Live peek runs the same channel in reverse: when the performer enables it, the
 * clip reports the number the spectator is typing so the performer's app can read
 * it back. Reads and writes are deliberately mirror images of the config route:
 * the clip writes the peek without a token (it can never hold one), and only the
 * performer, who holds the write token, may read it back.
 *
 *   GET    /v1/config?id=<performer>  -> current settings, readable by the App Clip
 *   PUT    /v1/config?id=<performer>  -> replace settings, requires that id's token
 *   PUT    /v1/peek?id=<performer>    -> report one number the spectator typed, no token
 *   GET    /v1/peek?id=<performer>    -> the calculation so far, requires that id's token
 *   DELETE /v1/peek?id=<performer>    -> clear it between spectators, requires the token
 *   GET    /health                    -> liveness probe
 *
 * Peek keeps the whole calculation rather than only the last number. Each settled value
 * is its own entry, and the operator that ended it is attached to that same entry when
 * the key is pressed, so the performer reads `123 +` then `456 =` then `579` instead of
 * a bare `579` with no idea what produced it.
 *
 * Each install generates its own id and write token. The first write to an id stores a
 * hash of its token, and nothing else may write or read peeks for that id afterwards.
 * Before this, every install shared the id `default` behind one service-wide token, so
 * performers overwrote each other's force numbers and could read each other's peeks.
 */

import {
  authorize,
  bearerToken,
  clearPeek,
  corsHeaders,
  json,
  MAX_PAYLOAD_BYTES,
  problem,
  pruneExpiredPeeks,
  readBoundedBody,
  readPeek,
  sha256Hex,
  writePeek,
  type Claim,
  type PeekEnv,
} from "./peek";

const DEFAULT_ID = "default";

/** Ids are used directly as primary keys, so keep them boring. */
const ID_PATTERN = /^[A-Za-z0-9_-]{1,64}$/;

interface Env extends PeekEnv {}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/health") {
      return json({ ok: true });
    }

    if (url.pathname === "/" || url.pathname === "") {
      return homePage();
    }

    if (url.pathname === "/privacy" || url.pathname === "/privacy/") {
      return privacyPolicy();
    }

    if (url.pathname === "/support" || url.pathname === "/support/") {
      return supportPage();
    }

    if (url.pathname !== "/v1/config" && url.pathname !== "/v1/peek") {
      return problem(404, "Not found");
    }

    const id = url.searchParams.get("id") ?? DEFAULT_ID;
    if (!ID_PATTERN.test(id)) {
      return problem(400, "Invalid id");
    }

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders() });
    }

    if (url.pathname === "/v1/peek") {
      switch (request.method) {
        case "GET":
          return readPeek(request, env, id);
        case "PUT":
          return writePeek(request, env, id);
        case "DELETE":
          return clearPeek(request, env, id);
        default:
          return problem(405, "Method not allowed");
      }
    }

    switch (request.method) {
      case "GET":
        return readConfig(env, id);
      case "PUT":
        return writeConfig(request, env, id);
      default:
        return problem(405, "Method not allowed");
    }
  },

  async scheduled(
    _controller: ScheduledController,
    env: Env,
    _ctx: ExecutionContext,
  ): Promise<void> {
    await pruneExpiredPeeks(env);
  },
} satisfies ExportedHandler<Env>;

async function readConfig(env: Env, id: string): Promise<Response> {
  const row = await env.DB.prepare(
    "SELECT payload, updated_at FROM config WHERE id = ?",
  )
    .bind(id)
    .first<{ payload: string; updated_at: number }>();

  if (!row) {
    return problem(404, "No configuration published yet");
  }

  // The clip must never act on a cached copy: the performer may have changed the
  // force number seconds ago.
  return new Response(row.payload, {
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      "x-updated-at": String(row.updated_at),
      ...corsHeaders(),
    },
  });
}

async function writeConfig(
  request: Request,
  env: Env,
  id: string,
): Promise<Response> {
  const presented = bearerToken(request);
  if (presented === null) {
    return problem(401, "Unauthorized");
  }
  const claim = await authorize(env, id, presented);
  if (claim === "denied") {
    return problem(401, "Unauthorized");
  }

  const bounded = await readBoundedBody(
    request,
    MAX_PAYLOAD_BYTES,
    "Configuration too large",
  );
  if (!bounded.ok) {
    return bounded.response;
  }
  const body = bounded.body;

  // Store the document verbatim so the Worker needs no knowledge of the app's
  // settings shape, but confirm it is JSON so a bad write cannot poison reads.
  try {
    JSON.parse(body);
  } catch {
    return problem(400, "Body must be JSON");
  }

  const stored = await storeConfig(env, id, body, presented, claim);
  if (!stored) {
    return problem(401, "Unauthorized");
  }
  return new Response(null, { status: 204, headers: corsHeaders() });
}

/**
 * Writes the payload, re-checking ownership in the same statement that writes it.
 *
 * `authorize` reads before the write, so two first writers could both be told `claim`.
 * An upsert let the loser of that race overwrite the winner's payload, and let whoever
 * landed first take the id from the install that printed it on a tag. A claim is now an
 * insert that does nothing if the id exists, and every other write is an update that only
 * matches the right owner. A claim that loses the race is authorized again, so the same
 * install publishing twice at once still lands.
 */
async function storeConfig(
  env: Env,
  id: string,
  body: string,
  presented: string,
  claim: Exclude<Claim, "denied">,
): Promise<boolean> {
  const tokenHash = await sha256Hex(presented);
  const now = Date.now();
  let access: Claim = claim;

  if (access === "claim") {
    const inserted = await env.DB.prepare(
      `INSERT INTO config (id, payload, updated_at, token_hash) VALUES (?, ?, ?, ?)
       ON CONFLICT(id) DO NOTHING`,
    )
      .bind(id, body, now, tokenHash)
      .run();
    if (inserted.meta.changes > 0) {
      return true;
    }
    access = await authorize(env, id, presented);
  }
  if (access !== "matched") {
    return false;
  }

  // `matched` means the row carries this token's hash, or carries none and the request
  // presented the service-wide token. No write ever sets a hash on an existing row, so
  // neither can change between the check and this statement. A legacy row keeps its
  // NULL hash rather than being locked away from the install that owns it.
  const updated = await env.DB.prepare(
    `UPDATE config SET payload = ?, updated_at = ?
     WHERE id = ? AND (token_hash = ? OR token_hash IS NULL)`,
  )
    .bind(body, now, id, tokenHash)
    .run();
  return updated.meta.changes > 0;
}

/** Brand landing for forcemagic.app — points reviewers and buyers to support. */
function homePage(): Response {
  const body = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Force — Calculator prop for magicians</title>
  <style>
    :root { color-scheme: light dark; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
      line-height: 1.5;
      max-width: 40rem;
      margin: 2rem auto;
      padding: 0 1.25rem;
      color: #111;
    }
    @media (prefers-color-scheme: dark) { body { color: #eee; } }
    h1 { font-size: 1.75rem; margin-bottom: 0.35rem; }
    .meta { color: #666; font-size: 0.95rem; margin-bottom: 1.5rem; }
    @media (prefers-color-scheme: dark) { .meta { color: #aaa; } }
    a { color: inherit; }
    ul { padding-left: 1.25rem; }
  </style>
</head>
<body>
  <h1>Force</h1>
  <p class="meta">Calculator prop for magicians</p>
  <p>
    Force is a working calculator that, at a moment you choose, lands on the number
    you set in advance. Share it with a spectator via QR or NFC App Clip.
  </p>
  <ul>
    <li><a href="/support">Support</a></li>
    <li><a href="/privacy">Privacy policy</a></li>
  </ul>
</body>
</html>`;

  return new Response(body, {
    status: 200,
    headers: {
      "content-type": "text/html; charset=utf-8",
      "cache-control": "public, max-age=300",
      ...corsHeaders(),
    },
  });
}

/** Public privacy policy for App Store Connect. HTML so a browser can open it. */
function privacyPolicy(): Response {
  const body = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Force — Privacy Policy</title>
  <style>
    :root { color-scheme: light dark; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
      line-height: 1.5;
      max-width: 40rem;
      margin: 2rem auto;
      padding: 0 1.25rem;
      color: #111;
    }
    @media (prefers-color-scheme: dark) {
      body { color: #eee; }
    }
    h1 { font-size: 1.6rem; margin-bottom: 0.25rem; }
    h2 { font-size: 1.15rem; margin-top: 1.75rem; }
    .meta { color: #666; font-size: 0.9rem; margin-bottom: 1.5rem; }
    @media (prefers-color-scheme: dark) { .meta { color: #aaa; } }
    ul { padding-left: 1.25rem; }
  </style>
</head>
<body>
  <h1>Force Privacy Policy</h1>
  <p class="meta">Last updated: September 23, 2026</p>

  <p>
    Force is a calculator prop for magicians. It includes an optional App Clip that a
    spectator opens from a QR code or NFC sticker. This policy covers the iOS app, the
    App Clip, and the configuration service they talk to.
  </p>

  <h2>What we collect</h2>
  <p>Force does not create accounts and does not ask for your name, email, or phone number.</p>
  <ul>
    <li>
      <strong>Performer settings.</strong> When you change your force number or related
      options, the app may upload those settings to our configuration service so a printed
      QR code or NFC sticker keeps working after you edit them. Settings are numbers and
      toggles only.
    </li>
    <li>
      <strong>Live Peek (optional, off by default).</strong> If you turn Live Peek on, the
      App Clip sends the calculation a spectator types so you can read it on your own
      phone during a performance. Entries are short numeric strings and operators. They are
      kept briefly for the performance, then expire automatically, and you can clear them
      at any time.
    </li>
    <li>
      <strong>Install identifiers.</strong> Each install generates a random performer id
      and a random write token on the device. Neither is derived from your Apple ID,
      device serial, advertising identifier, or other personal data.
    </li>
  </ul>

  <h2>What we do not collect</h2>
  <ul>
    <li>Analytics, crash reports, or advertising identifiers</li>
    <li>Location, contacts, photos (except a screenshot you optionally choose yourself
      for the “Start with Screenshot” launch screen, which stays on your device)</li>
    <li>Data from third-party SDKs — Force ships with none</li>
  </ul>

  <h2>How data is used</h2>
  <p>
    Settings and Live Peek exist only so the trick works across your phone and a
    spectator’s App Clip. We do not sell data, use it for advertising, or combine it with
    other sources to identify a person.
  </p>

  <h2>Where data is stored</h2>
  <p>
    Configuration and Live Peek are stored on a Cloudflare Worker and D1 database under
    our control. Tokens never leave the performer’s Keychain except as a bearer
    credential on publish and peek-read requests.
  </p>

  <h2>Retention</h2>
  <ul>
    <li>Settings remain until you overwrite them or we delete unused records.</li>
    <li>Live Peek entries expire after about ten minutes and can be cleared sooner.</li>
  </ul>

  <h2>Children</h2>
  <p>Force is not directed at children under 13, and we do not knowingly collect data from them.</p>

  <h2>Contact</h2>
  <p>
    Questions about this policy: Jonathan Mobley —
    <a href="mailto:jon.mobley@me.com">jon.mobley@me.com</a>
  </p>
</body>
</html>`;

  return new Response(body, {
    status: 200,
    headers: {
      "content-type": "text/html; charset=utf-8",
      "cache-control": "public, max-age=300",
      ...corsHeaders(),
    },
  });
}

/** Support page required by App Store Connect (Guideline 1.5). */
function supportPage(): Response {
  const body = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Force — Support</title>
  <style>
    :root { color-scheme: light dark; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
      line-height: 1.5;
      max-width: 40rem;
      margin: 2rem auto;
      padding: 0 1.25rem;
      color: #111;
    }
    @media (prefers-color-scheme: dark) { body { color: #eee; } }
    h1 { font-size: 1.6rem; margin-bottom: 0.25rem; }
    h2 { font-size: 1.15rem; margin-top: 1.75rem; }
    .meta { color: #666; font-size: 0.9rem; margin-bottom: 1.5rem; }
    @media (prefers-color-scheme: dark) { .meta { color: #aaa; } }
    ul { padding-left: 1.25rem; }
  </style>
</head>
<body>
  <h1>Force Support</h1>
  <p class="meta">Force Calculator Magic — help for performers</p>

  <p>
    Force is a calculator prop for magicians. If something is not working during a
    show or while setting up QR / NFC sharing, email and we will help you sort it out.
  </p>

  <h2>Contact</h2>
  <p>
    Jonathan Mobley —
    <a href="mailto:jonmobley@gmail.com">jonmobley@gmail.com</a>
  </p>

  <h2>Common topics</h2>
  <ul>
    <li>App Clip QR code or NFC sticker not opening the spectator calculator</li>
    <li>Live Peek not showing the spectator’s calculation</li>
    <li>Settings not updating for spectators after you change the force number</li>
    <li>Perfect Plus / face-down behavior</li>
  </ul>

  <h2>Privacy</h2>
  <p>
    See the
    <a href="/privacy">privacy policy</a>
    for what the app sends over the network.
  </p>
</body>
</html>`;

  return new Response(body, {
    status: 200,
    headers: {
      "content-type": "text/html; charset=utf-8",
      "cache-control": "public, max-age=300",
      ...corsHeaders(),
    },
  });
}

