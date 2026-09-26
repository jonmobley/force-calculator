/**
 * Retention: erasing a performer's settings on request and after a year unused.
 *
 * Erasing never deletes the `config` row. The id is printed on the performer's tags,
 * so freeing it would let the next person to scan one claim it. The row keeps its
 * `token_hash`, its payload becomes `{}`, and `erased_at` marks it so reads report it
 * as unpublished. The owner's next publish brings it back.
 */

import {
  authorize,
  bearerToken,
  corsHeaders,
  problem,
  type PeekEnv,
} from "./peek";

/** How long settings stay after the app last published them. */
export const CONFIG_RETENTION_MS = 365 * 24 * 60 * 60 * 1000;

// MARK: - Route handler

/**
 * Erases the settings and any peek for an id. Only the owner may call it: a read of the
 * payload is public, but wiping it must not be.
 */
export async function eraseConfig(
  request: Request,
  env: PeekEnv,
  id: string,
): Promise<Response> {
  const presented = bearerToken(request);
  if (presented === null || (await authorize(env, id, presented)) !== "matched") {
    return problem(401, "Unauthorized");
  }
  await env.DB.batch(eraseStatements(env, id, Date.now()));
  return new Response(null, { status: 204, headers: corsHeaders() });
}

// MARK: - Scheduled sweep

/**
 * Erases every config the app has not published to in a year. Runs from the cron so the
 * privacy policy's promise holds for a performer who deleted the app without asking.
 */
export async function eraseUnusedConfigs(env: PeekEnv): Promise<void> {
  const now = Date.now();
  const cutoff = now - CONFIG_RETENTION_MS;
  const { results } = await env.DB.prepare(
    "SELECT id FROM config WHERE updated_at < ? AND erased_at IS NULL",
  )
    .bind(cutoff)
    .all<{ id: string }>();

  const statements = (results ?? []).flatMap((row) =>
    eraseStatements(env, row.id, now),
  );
  if (statements.length > 0) {
    await env.DB.batch(statements);
  }
}

// MARK: - Statements

function eraseStatements(
  env: PeekEnv,
  id: string,
  now: number,
): D1PreparedStatement[] {
  return [
    env.DB.prepare(
      "UPDATE config SET payload = '{}', erased_at = ? WHERE id = ?",
    ).bind(now, id),
    env.DB.prepare("DELETE FROM peek_entry WHERE id = ?").bind(id),
    env.DB.prepare("DELETE FROM peek WHERE id = ?").bind(id),
  ];
}
