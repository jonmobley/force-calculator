import { createExecutionContext } from "cloudflare:test";
import { env } from "cloudflare:workers";
import worker from "../src/index";

export { env };

export const ORIGIN = "https://force.test";

/** A random id in the shape the app mints, so tests never collide on a row. */
export function freshId(): string {
  return crypto.randomUUID().replaceAll("-", "");
}

/** A random token; only its SHA-256 is ever stored. */
export function freshToken(): string {
  return crypto.randomUUID();
}

/**
 * A random client address. The config write limit is keyed on it and its counter is
 * not rolled back between tests, so every test that writes config gets its own.
 */
export function freshIp(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(4));
  return Array.from(bytes).join(".");
}

interface CallOptions {
  token?: string;
  body?: string;
  ip?: string;
}

/** Sends one request through the Worker's `fetch` handler. */
export function call(
  method: string,
  path: "/v1/config" | "/v1/peek",
  id: string,
  { token, body, ip }: CallOptions = {},
): Promise<Response> {
  const headers = new Headers({ "cf-connecting-ip": ip ?? freshIp() });
  if (token !== undefined) {
    headers.set("authorization", `Bearer ${token}`);
  }
  if (body !== undefined) {
    headers.set("content-type", "application/json");
  }
  const request = new Request(`${ORIGIN}${path}?id=${id}`, {
    method,
    headers,
    body,
  });
  return worker.fetch(request, env);
}

/** Runs the cron handler once. */
export async function runScheduled(): Promise<void> {
  const controller = {
    scheduledTime: Date.now(),
    cron: "*/5 * * * *",
    noRetry() {},
  } satisfies ScheduledController;
  await worker.scheduled(controller, env, createExecutionContext());
}

export interface ConfigRow {
  id: string;
  payload: string;
  updated_at: number;
  token_hash: string | null;
  erased_at: number | null;
}

/** The raw `config` row, or null when there is none. */
export function configRow(id: string): Promise<ConfigRow | null> {
  return env.DB.prepare(
    "SELECT id, payload, updated_at, token_hash, erased_at FROM config WHERE id = ?",
  )
    .bind(id)
    .first<ConfigRow>();
}

/** Inserts a row as an older deploy would have written it. */
export async function insertRow(
  row: Partial<ConfigRow> & Pick<ConfigRow, "id">,
): Promise<void> {
  await env.DB.prepare(
    `INSERT INTO config (id, payload, updated_at, token_hash, erased_at)
     VALUES (?, ?, ?, ?, ?)`,
  )
    .bind(
      row.id,
      row.payload ?? "{}",
      row.updated_at ?? Date.now(),
      row.token_hash ?? null,
      row.erased_at ?? null,
    )
    .run();
}

/** How many peek rows, in both tables, an id currently has. */
export async function peekRowCount(id: string): Promise<number> {
  const entries = await env.DB.prepare(
    "SELECT COUNT(*) AS n FROM peek_entry WHERE id = ?",
  )
    .bind(id)
    .first<{ n: number }>();
  const legacy = await env.DB.prepare("SELECT COUNT(*) AS n FROM peek WHERE id = ?")
    .bind(id)
    .first<{ n: number }>();
  return (entries?.n ?? 0) + (legacy?.n ?? 0);
}

/** Publishes a config that has Live Peek on, so peek writes are admitted. */
export async function publishWithPeek(id: string, token: string): Promise<void> {
  const response = await call("PUT", "/v1/config", id, {
    token,
    body: JSON.stringify({ forceNumber: 42, livePeekEnabled: true }),
  });
  if (response.status !== 204) {
    throw new Error(`publish failed: ${response.status}`);
  }
}
