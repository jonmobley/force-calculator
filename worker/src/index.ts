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

/** Largest accepted settings document. The real payload is a few hundred bytes. */
const MAX_PAYLOAD_BYTES = 8 * 1024;

/** A display value is at most ten digits plus grouping, sign, and a decimal. */
const MAX_PEEK_VALUE_LENGTH = 64;

/** Entry ids are minted by the clip and used as primary keys, so keep them boring. */
const ENTRY_ID_PATTERN = /^[A-Za-z0-9_-]{1,80}$/;

/** The only keys that can close an entry. Anything else is not from our calculator. */
const OPERATORS = new Set(["+", "−", "×", "÷", "%", "="]);

/**
 * How much of a calculation the performer can see at once. Comfortably more than any
 * spectator will type in one sitting, and small enough to read on a phone.
 */
const MAX_ENTRIES = 40;

/**
 * How long an entry stays readable. Long enough to cover a spectator taking their time,
 * short enough that the last person's numbers are gone before the next one starts.
 */
const ENTRY_TTL_MS = 10 * 60 * 1000;

const DEFAULT_ID = "default";

/** Ids are used directly as primary keys, so keep them boring. */
const ID_PATTERN = /^[A-Za-z0-9_-]{1,64}$/;

interface Env {
  DB: D1Database;
  WRITE_TOKEN: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/health") {
      return json({ ok: true });
    }

    if (url.pathname === "/privacy" || url.pathname === "/privacy/") {
      return privacyPolicy();
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

  const body = await request.text();
  if (body.length > MAX_PAYLOAD_BYTES) {
    return problem(413, "Configuration too large");
  }

  // Store the document verbatim so the Worker needs no knowledge of the app's
  // settings shape, but confirm it is JSON so a bad write cannot poison reads.
  try {
    JSON.parse(body);
  } catch {
    return problem(400, "Body must be JSON");
  }

  // The first write to an id binds it to the token that made it. Later writes keep
  // whatever hash is already stored, so a legacy row on the service-wide token is not
  // silently converted and locked away from the install that owns it.
  const tokenHash = claim === "claim" ? await sha256Hex(presented) : null;

  await env.DB.prepare(
    `INSERT INTO config (id, payload, updated_at, token_hash) VALUES (?, ?, ?, ?)
     ON CONFLICT(id) DO UPDATE SET
       payload = excluded.payload,
       updated_at = excluded.updated_at,
       token_hash = COALESCE(config.token_hash, excluded.token_hash)`,
  )
    .bind(id, body, Date.now(), tokenHash)
    .run();

  return new Response(null, { status: 204, headers: corsHeaders() });
}

// MARK: - Peek

/**
 * Returns the calculation the spectator has worked through, oldest first. Guarded by the
 * write token so only the performer can read it: the values are short-lived and
 * low-value, but they are still the spectator's input and should not be readable by a
 * guessed id.
 */
async function readPeek(
  request: Request,
  env: Env,
  id: string,
): Promise<Response> {
  const presented = bearerToken(request);
  // Stricter than a write: a read has to match a record that already exists, so an
  // unclaimed id cannot be used to fish for whatever a spectator happens to be typing.
  if (presented === null || (await authorize(env, id, presented)) !== "matched") {
    return problem(401, "Unauthorized");
  }

  const cutoff = Date.now() - ENTRY_TTL_MS;
  const { results } = await env.DB.prepare(
    `SELECT value, op, created_at FROM peek_entry
     WHERE id = ? AND created_at >= ?
     ORDER BY created_at ASC
     LIMIT ?`,
  )
    .bind(id, cutoff, MAX_ENTRIES)
    .all<{ value: string; op: string | null; created_at: number }>();

  if (!results || results.length === 0) {
    return problem(404, "No peek reported yet");
  }

  return json({
    entries: results.map((row) => ({
      value: row.value,
      op: row.op ?? undefined,
      at: row.created_at,
    })),
  });
}

/** Wipes the calculation so the next spectator starts on a clean readout. */
async function clearPeek(
  request: Request,
  env: Env,
  id: string,
): Promise<Response> {
  const presented = bearerToken(request);
  if (presented === null || (await authorize(env, id, presented)) !== "matched") {
    return problem(401, "Unauthorized");
  }
  await env.DB.batch([
    env.DB.prepare("DELETE FROM peek_entry WHERE id = ?").bind(id),
    env.DB.prepare("DELETE FROM peek WHERE id = ?").bind(id),
  ]);
  return new Response(null, { status: 204, headers: corsHeaders() });
}

/**
 * Records one number from the spectator's calculation. Left unauthenticated on purpose:
 * the clip that sends it can never hold the write token.
 *
 * The same `entryID` may be sent twice, first as a bare number and again once the key
 * that ended it is known, which is how `123` becomes `123 +` in place rather than
 * appearing as two separate numbers. A body with no `entryID` is an older clip, and is
 * stored as a single rolling entry so it still reads something.
 */
async function writePeek(
  request: Request,
  env: Env,
  id: string,
): Promise<Response> {
  const body = await request.text();
  if (body.length > MAX_PAYLOAD_BYTES) {
    return problem(413, "Peek too large");
  }

  let parsed: { value?: unknown; entryID?: unknown; op?: unknown };
  try {
    parsed = JSON.parse(body) as typeof parsed;
  } catch {
    return problem(400, "Body must be JSON");
  }

  const { value, entryID, op } = parsed;
  if (typeof value !== "string" || value.length === 0 || value.length > MAX_PEEK_VALUE_LENGTH) {
    return problem(400, "Invalid peek value");
  }
  if (op !== undefined && (typeof op !== "string" || !OPERATORS.has(op))) {
    return problem(400, "Invalid operator");
  }
  const entry = typeof entryID === "string" ? entryID : "legacy";
  if (!ENTRY_ID_PATTERN.test(entry)) {
    return problem(400, "Invalid entry id");
  }

  const now = Date.now();
  await env.DB.batch([
    // `created_at` is held at its original value on conflict so attaching the operator
    // does not shuffle a finished number to the end of the calculation.
    env.DB.prepare(
      `INSERT INTO peek_entry (id, entry_id, value, op, created_at) VALUES (?, ?, ?, ?, ?)
       ON CONFLICT(id, entry_id) DO UPDATE SET value = excluded.value, op = excluded.op`,
    ).bind(id, entry, value, op ?? null, now),
    // Pruned on the way past, so nothing has to sweep and the previous spectator's
    // numbers cannot survive into somebody else's performance.
    env.DB.prepare("DELETE FROM peek_entry WHERE id = ? AND created_at < ?").bind(
      id,
      now - ENTRY_TTL_MS,
    ),
    // Kept in step for any clip still reading the single-value shape.
    env.DB.prepare(
      `INSERT INTO peek (id, value, updated_at) VALUES (?, ?, ?)
       ON CONFLICT(id) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at`,
    ).bind(id, value, now),
  ]);

  return new Response(null, { status: 204, headers: corsHeaders() });
}
/** The bearer token on the request, or null when there is not one. */
function bearerToken(request: Request): string | null {
  const header = request.headers.get("authorization") ?? "";
  const prefix = "Bearer ";
  if (!header.startsWith(prefix)) {
    return null;
  }
  const token = header.slice(prefix.length);
  return token.length > 0 ? token : null;
}

type Claim = "matched" | "claim" | "denied";

/**
 * Decides whether a token may act on an id.
 *
 * - `matched`: the id is already bound to this token.
 * - `claim`: the id is unused, so this token may take it.
 * - `denied`: the id belongs to someone else.
 *
 * Rows written before per-performer credentials existed carry no hash. Those stay on
 * the service-wide token, so the install that has been publishing to `default` all
 * along keeps its record instead of being locked out by its own upgrade.
 */
async function authorize(env: Env, id: string, presented: string): Promise<Claim> {
  const row = await env.DB.prepare("SELECT token_hash FROM config WHERE id = ?")
    .bind(id)
    .first<{ token_hash: string | null }>();

  if (!row) {
    return "claim";
  }
  if (row.token_hash) {
    return constantTimeEqual(await sha256Hex(presented), row.token_hash)
      ? "matched"
      : "denied";
  }
  const legacy = env.WRITE_TOKEN ?? "";
  return legacy.length > 0 && constantTimeEqual(presented, legacy)
    ? "matched"
    : "denied";
}

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function constantTimeEqual(a: string, b: string): boolean {
  const left = new TextEncoder().encode(a);
  const right = new TextEncoder().encode(b);
  if (left.byteLength !== right.byteLength) {
    return false;
  }
  return crypto.subtle.timingSafeEqual(left, right);
}

function corsHeaders(): Record<string, string> {
  return {
    "access-control-allow-origin": "*",
    "access-control-allow-methods": "GET, PUT, DELETE, OPTIONS",
    "access-control-allow-headers": "authorization, content-type",
  };
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      ...corsHeaders(),
    },
  });
}

function problem(status: number, message: string): Response {
  return json({ error: message }, status);
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
