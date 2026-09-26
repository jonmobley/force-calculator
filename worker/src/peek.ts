/**
 * Live peek: the spectator reports a calculation; the performer reads it back.
 *
 * Writes are unauthenticated on purpose (the App Clip cannot hold the token), so
 * admission is the published `livePeekEnabled` switch, a rate limit on the
 * performer id, and a tight allowlist of calculator display text. Expired rows
 * are pruned on write and by a cron so the privacy policy's ten-minute lifetime
 * is real even when nobody writes again.
 */

/** Largest accepted JSON body for peek or config. */
export const MAX_PAYLOAD_BYTES = 8 * 1024;

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
export const ENTRY_TTL_MS = 10 * 60 * 1000;

/** Digits and the punctuation the calculator display actually uses, including scientific. */
const DISPLAY_CHARS = /^[0-9,.\-+eE∞]+$/;

export interface PeekEnv {
  DB: D1Database;
  WRITE_TOKEN: string;
  PEEK_WRITE_LIMIT: RateLimit;
}

export type Claim = "matched" | "claim" | "denied";

// MARK: - Route handlers

/**
 * Returns the calculation the spectator has worked through, oldest first. Guarded by the
 * write token so only the performer can read it: the values are short-lived and
 * low-value, but they are still the spectator's input and should not be readable by a
 * guessed id.
 */
export async function readPeek(
  request: Request,
  env: PeekEnv,
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
    `SELECT value, op, created_at FROM (
       SELECT value, op, created_at FROM peek_entry
       WHERE id = ? AND created_at >= ?
       ORDER BY created_at DESC
       LIMIT ?
     ) AS recent
     ORDER BY created_at ASC`,
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
export async function clearPeek(
  request: Request,
  env: PeekEnv,
  id: string,
): Promise<Response> {
  const presented = bearerToken(request);
  if (presented === null || (await authorize(env, id, presented)) !== "matched") {
    return problem(401, "Unauthorized");
  }
  await env.DB.batch([
    env.DB.prepare("DELETE FROM peek_entry WHERE id = ?").bind(id),
    // Leftover rows from the old single-value table; nothing writes it anymore.
    env.DB.prepare("DELETE FROM peek WHERE id = ?").bind(id),
  ]);
  return new Response(null, { status: 204 });
}

/**
 * Records one number from the spectator's calculation. Left unauthenticated on purpose:
 * the clip that sends it can never hold the write token. Admission is the published
 * peek switch for this id, a rate limit, and a display-shaped value.
 *
 * The same `entryID` may be sent twice, first as a bare number and again once the key
 * that ended it is known, which is how `123` becomes `123 +` in place rather than
 * appearing as two separate numbers. A body with no `entryID` is an older clip, and is
 * stored as a single rolling entry so it still reads something.
 */
export async function writePeek(
  request: Request,
  env: PeekEnv,
  id: string,
): Promise<Response> {
  const { success } = await env.PEEK_WRITE_LIMIT.limit({ key: id });
  if (!success) {
    return problem(429, "Too many peek writes");
  }

  if (!(await livePeekIsOn(env, id))) {
    return problem(404, "Live peek is not enabled");
  }

  const bounded = await readBoundedBody(request, MAX_PAYLOAD_BYTES, "Peek too large");
  if (!bounded.ok) {
    return bounded.response;
  }

  let parsed: { value?: unknown; entryID?: unknown; op?: unknown };
  try {
    parsed = JSON.parse(bounded.body) as typeof parsed;
  } catch {
    return problem(400, "Body must be JSON");
  }

  const { value, entryID, op } = parsed;
  if (typeof value !== "string" || !isValidPeekValue(value)) {
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
    // Pruned on the way past, so a previous spectator's numbers cannot linger.
    env.DB.prepare("DELETE FROM peek_entry WHERE id = ? AND created_at < ?").bind(
      id,
      now - ENTRY_TTL_MS,
    ),
    // Keep only the newest MAX_ENTRIES so a long tape cannot hide the live number.
    env.DB.prepare(
      `DELETE FROM peek_entry
       WHERE id = ?
         AND rowid NOT IN (
           SELECT rowid FROM peek_entry
           WHERE id = ?
           ORDER BY created_at DESC
           LIMIT ?
         )`,
    ).bind(id, id, MAX_ENTRIES),
  ]);

  return new Response(null, { status: 204, headers: corsHeaders() });
}

/**
 * Deletes peek rows past the ten-minute lifetime for every id. The read path already
 * hides them; this makes the privacy policy's automatic expiry true when nobody writes.
 */
export async function pruneExpiredPeeks(env: PeekEnv): Promise<void> {
  const cutoff = Date.now() - ENTRY_TTL_MS;
  await env.DB.batch([
    env.DB.prepare("DELETE FROM peek_entry WHERE created_at < ?").bind(cutoff),
    env.DB.prepare("DELETE FROM peek WHERE updated_at < ?").bind(cutoff),
  ]);
}

// MARK: - Body size

/**
 * Reads a request body up to `maxBytes`. A declared Content-Length over the cap is
 * rejected without buffering; otherwise the stream is read and stopped at the cap.
 */
export async function readBoundedBody(
  request: Request,
  maxBytes: number,
  tooLargeMessage: string,
): Promise<{ ok: true; body: string } | { ok: false; response: Response }> {
  const declared = request.headers.get("content-length");
  if (declared !== null) {
    const length = Number(declared);
    if (!Number.isFinite(length) || length < 0) {
      return { ok: false, response: problem(400, "Invalid content length") };
    }
    if (length > maxBytes) {
      return { ok: false, response: problem(413, tooLargeMessage) };
    }
  }

  const reader = request.body?.getReader();
  if (!reader) {
    return { ok: true, body: "" };
  }

  const chunks: Uint8Array[] = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) {
      break;
    }
    total += value.byteLength;
    if (total > maxBytes) {
      await reader.cancel();
      return { ok: false, response: problem(413, tooLargeMessage) };
    }
    chunks.push(value);
  }

  const merged = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    merged.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return { ok: true, body: new TextDecoder().decode(merged) };
}

// MARK: - Auth (shared with config writes)

/** The bearer token on the request, or null when there is not one. */
export function bearerToken(request: Request): string | null {
  const header = request.headers.get("authorization") ?? "";
  const prefix = "Bearer ";
  if (!header.startsWith(prefix)) {
    return null;
  }
  const token = header.slice(prefix.length);
  return token.length > 0 ? token : null;
}

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
export async function authorize(
  env: PeekEnv,
  id: string,
  presented: string,
): Promise<Claim> {
  const row = await env.DB.prepare("SELECT token_hash FROM config WHERE id = ?")
    .bind(id)
    .first<{ token_hash: string | null }>();

  if (!row) {
    return "claim";
  }
  const presentedHash = await sha256Hex(presented);
  if (row.token_hash) {
    return constantTimeEqual(presentedHash, row.token_hash) ? "matched" : "denied";
  }
  // Hashing both sides gives equal-length inputs, so the length check in
  // `constantTimeEqual` cannot leak how long the service-wide token is.
  const legacy = env.WRITE_TOKEN ?? "";
  return legacy.length > 0 &&
    constantTimeEqual(presentedHash, await sha256Hex(legacy))
    ? "matched"
    : "denied";
}

export async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
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

// MARK: - HTTP helpers

export function corsHeaders(): Record<string, string> {
  return {
    "access-control-allow-origin": "*",
    "access-control-allow-methods": "GET, PUT, DELETE, OPTIONS",
    "access-control-allow-headers": "authorization, content-type",
  };
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      ...corsHeaders(),
    },
  });
}

export function problem(status: number, message: string): Response {
  return json({ error: message }, status);
}

// MARK: - Validation

/** True when the published config for this id has live peek turned on. */
async function livePeekIsOn(env: PeekEnv, id: string): Promise<boolean> {
  const row = await env.DB.prepare("SELECT payload FROM config WHERE id = ?")
    .bind(id)
    .first<{ payload: string }>();
  if (!row) {
    return false;
  }
  try {
    const parsed = JSON.parse(row.payload) as { livePeekEnabled?: unknown };
    return parsed.livePeekEnabled === true;
  } catch {
    return false;
  }
}

/**
 * Calculator display text only: the word Error, or digits and the punctuation the
 * formatter uses (grouping, decimal, sign, scientific, infinity).
 */
function isValidPeekValue(value: string): boolean {
  if (value === "Error") {
    return true;
  }
  if (value.length === 0 || value.length > MAX_PEEK_VALUE_LENGTH) {
    return false;
  }
  return DISPLAY_CHARS.test(value);
}
