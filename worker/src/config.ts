/**
 * Performer configuration: the settings the App Clip fetches at launch.
 *
 * Reads are public because the clip runs on a spectator's device and cannot hold a
 * credential. Writes are bound to the token that first claimed the id.
 */

import {
  authorize,
  bearerToken,
  corsHeaders,
  MAX_PAYLOAD_BYTES,
  problem,
  readBoundedBody,
  sha256Hex,
  type Claim,
  type PeekEnv,
} from "./peek";

export interface ConfigEnv extends PeekEnv {
  CONFIG_WRITE_LIMIT: RateLimit;
}

// MARK: - Route handlers

/** Returns the published settings for an id, readable by anyone who knows the id. */
export async function readConfig(env: ConfigEnv, id: string): Promise<Response> {
  // An erased row still exists to hold the id, but reads as if nothing was published.
  const row = await env.DB.prepare(
    "SELECT payload, updated_at FROM config WHERE id = ? AND erased_at IS NULL",
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

/** Replaces the published settings for an id. Requires that id's token. */
export async function writeConfig(
  request: Request,
  env: ConfigEnv,
  id: string,
): Promise<Response> {
  // Keyed on the caller rather than the id, and checked before auth, so one client
  // cannot squat ids in bulk: unclaimed ids have no owner to key on yet.
  const client = request.headers.get("cf-connecting-ip") ?? "unknown";
  const { success } = await env.CONFIG_WRITE_LIMIT.limit({ key: client });
  if (!success) {
    return problem(429, "Too many configuration writes");
  }

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

// MARK: - Storage

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
export async function storeConfig(
  env: ConfigEnv,
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
  // NULL hash rather than being locked away from the install that owns it. A publish
  // also revives an erased row, since only the owner can get this far.
  const updated = await env.DB.prepare(
    `UPDATE config SET payload = ?, updated_at = ?, erased_at = NULL
     WHERE id = ? AND (token_hash = ? OR token_hash IS NULL)`,
  )
    .bind(body, now, id, tokenHash)
    .run();
  return updated.meta.changes > 0;
}
