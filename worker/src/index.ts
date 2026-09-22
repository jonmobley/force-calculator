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
 *   GET  /v1/config?id=default   -> current settings, readable by the App Clip
 *   PUT  /v1/config?id=default   -> replace settings, requires the write token
 *   PUT  /v1/peek?id=default     -> report the spectator's number, no token
 *   GET  /v1/peek?id=default     -> latest reported number, requires the token
 *   GET  /health                 -> liveness probe
 */

/** Largest accepted settings document. The real payload is a few hundred bytes. */
const MAX_PAYLOAD_BYTES = 8 * 1024;

/** A display value is at most nine digits plus grouping, sign, and a decimal. */
const MAX_PEEK_VALUE_LENGTH = 64;

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
  if (!isAuthorized(request, env)) {
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

  await env.DB.prepare(
    `INSERT INTO config (id, payload, updated_at) VALUES (?, ?, ?)
     ON CONFLICT(id) DO UPDATE SET payload = excluded.payload, updated_at = excluded.updated_at`,
  )
    .bind(id, body, Date.now())
    .run();

  return new Response(null, { status: 204, headers: corsHeaders() });
}

// MARK: - Peek

/**
 * Returns the latest number the spectator typed. Guarded by the write token so
 * only the performer can read it: the value is short-lived and low-value, but it
 * is still the spectator's input and should not be readable by a guessed id.
 */
async function readPeek(
  request: Request,
  env: Env,
  id: string,
): Promise<Response> {
  if (!isAuthorized(request, env)) {
    return problem(401, "Unauthorized");
  }

  const row = await env.DB.prepare(
    "SELECT value, updated_at FROM peek WHERE id = ?",
  )
    .bind(id)
    .first<{ value: string; updated_at: number }>();

  if (!row) {
    return problem(404, "No peek reported yet");
  }

  return json({ value: row.value, updatedAt: row.updated_at });
}

/**
 * Records the spectator's current number. Left unauthenticated on purpose: the
 * clip that sends it can never hold the write token. Only a single short value is
 * stored per performer, and each write overwrites the last, so nothing meaningful
 * accumulates even if the endpoint is hit directly.
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

  let value: unknown;
  try {
    value = (JSON.parse(body) as { value?: unknown }).value;
  } catch {
    return problem(400, "Body must be JSON");
  }

  if (typeof value !== "string" || value.length === 0 || value.length > MAX_PEEK_VALUE_LENGTH) {
    return problem(400, "Invalid peek value");
  }

  await env.DB.prepare(
    `INSERT INTO peek (id, value, updated_at) VALUES (?, ?, ?)
     ON CONFLICT(id) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at`,
  )
    .bind(id, value, Date.now())
    .run();

  return new Response(null, { status: 204, headers: corsHeaders() });
}
function isAuthorized(request: Request, env: Env): boolean {
  const header = request.headers.get("authorization") ?? "";
  const prefix = "Bearer ";
  if (!header.startsWith(prefix)) {
    return false;
  }
  const presented = new TextEncoder().encode(header.slice(prefix.length));
  const expected = new TextEncoder().encode(env.WRITE_TOKEN ?? "");
  if (presented.byteLength !== expected.byteLength) {
    return false;
  }
  return crypto.subtle.timingSafeEqual(presented, expected);
}

function corsHeaders(): Record<string, string> {
  return {
    "access-control-allow-origin": "*",
    "access-control-allow-methods": "GET, PUT, OPTIONS",
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
