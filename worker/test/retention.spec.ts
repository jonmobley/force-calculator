import { describe, expect, it } from "vitest";
import { sha256Hex } from "../src/peek";
import { CONFIG_RETENTION_MS, eraseUnusedConfigs } from "../src/retention";
import {
  call,
  configRow,
  env,
  freshId,
  freshToken,
  insertRow,
  peekRowCount,
  publishWithPeek,
  runScheduled,
} from "./helpers";

const DAY_MS = 24 * 60 * 60 * 1000;

async function reportPeek(id: string, value: string): Promise<void> {
  const response = await call("PUT", "/v1/peek", id, {
    body: JSON.stringify({ value, entryID: crypto.randomUUID() }),
  });
  expect(response.status).toBe(204);
}

describe("DELETE /v1/config", () => {
  it("erases the settings and peeks but keeps the id bound to its token", async () => {
    const id = freshId();
    const owner = freshToken();
    const intruder = freshToken();
    await publishWithPeek(id, owner);
    await reportPeek(id, "123");
    await env.DB.prepare(
      "INSERT INTO peek (id, value, updated_at) VALUES (?, ?, ?)",
    )
      .bind(id, "old", Date.now())
      .run();
    expect(await peekRowCount(id)).toBe(2);

    expect((await call("DELETE", "/v1/config", id)).status).toBe(401);
    expect((await call("DELETE", "/v1/config", id, { token: intruder })).status).toBe(401);
    expect(await peekRowCount(id)).toBe(2);

    const erased = await call("DELETE", "/v1/config", id, { token: owner });
    expect(erased.status).toBe(204);

    const row = await configRow(id);
    expect(row?.payload).toBe("{}");
    expect(row?.erased_at).not.toBeNull();
    expect(row?.token_hash).toBe(await sha256Hex(owner));
    expect(await peekRowCount(id)).toBe(0);

    // Reads treat it as unpublished, and peek writes are no longer admitted.
    expect((await call("GET", "/v1/config", id)).status).toBe(404);
    const peek = await call("PUT", "/v1/peek", id, {
      body: JSON.stringify({ value: "5", entryID: "e1" }),
    });
    expect(peek.status).toBe(404);

    // The id cannot be claimed by someone who scans an old tag.
    const squat = await call("PUT", "/v1/config", id, {
      token: intruder,
      body: JSON.stringify({ forceNumber: 7 }),
    });
    expect(squat.status).toBe(401);
    expect((await configRow(id))?.payload).toBe("{}");
  });

  it("is undone by the owner's next publish", async () => {
    const id = freshId();
    const owner = freshToken();
    await publishWithPeek(id, owner);
    expect((await call("DELETE", "/v1/config", id, { token: owner })).status).toBe(204);

    const settings = JSON.stringify({ forceNumber: 8, livePeekEnabled: false });
    const republish = await call("PUT", "/v1/config", id, { token: owner, body: settings });
    expect(republish.status).toBe(204);

    const row = await configRow(id);
    expect(row?.erased_at).toBeNull();
    expect(row?.payload).toBe(settings);
    const read = await call("GET", "/v1/config", id);
    expect(read.status).toBe(200);
    expect(await read.text()).toBe(settings);
  });

  it("refuses an id that was never claimed", async () => {
    const response = await call("DELETE", "/v1/config", freshId(), { token: freshToken() });
    expect(response.status).toBe(401);
  });
});

describe("the retention sweep", () => {
  it("erases configs a year unused, leaves the rest, and keeps ids bound", async () => {
    const now = Date.now();
    const staleToken = freshToken();
    const stale = freshId();
    const recent = freshId();
    const alreadyErased = freshId();
    const legacy = freshId();
    const earlier = now - 2 * CONFIG_RETENTION_MS;

    await insertRow({
      id: stale,
      payload: JSON.stringify({ forceNumber: 1, livePeekEnabled: true }),
      updated_at: now - CONFIG_RETENTION_MS - DAY_MS,
      token_hash: await sha256Hex(staleToken),
    });
    await env.DB.prepare(
      "INSERT INTO peek_entry (id, entry_id, value, op, created_at) VALUES (?, ?, ?, ?, ?)",
    )
      .bind(stale, "e1", "42", null, now)
      .run();
    await insertRow({
      id: recent,
      payload: JSON.stringify({ forceNumber: 2 }),
      updated_at: now - CONFIG_RETENTION_MS + DAY_MS,
      token_hash: await sha256Hex(freshToken()),
    });
    await insertRow({
      id: alreadyErased,
      payload: "{}",
      updated_at: earlier,
      erased_at: earlier,
      token_hash: await sha256Hex(freshToken()),
    });
    await insertRow({
      id: legacy,
      payload: JSON.stringify({ forceNumber: 3 }),
      updated_at: earlier,
      token_hash: null,
    });

    await eraseUnusedConfigs(env);

    const staleRow = await configRow(stale);
    expect(staleRow?.payload).toBe("{}");
    expect(staleRow?.erased_at).toBeGreaterThanOrEqual(now);
    expect(staleRow?.token_hash).toBe(await sha256Hex(staleToken));
    expect(await peekRowCount(stale)).toBe(0);
    expect((await call("GET", "/v1/config", stale)).status).toBe(404);

    const recentRow = await configRow(recent);
    expect(recentRow?.erased_at).toBeNull();
    expect(JSON.parse(recentRow?.payload ?? "")).toEqual({ forceNumber: 2 });

    // Already erased rows are not touched again, so `erased_at` records the first sweep.
    expect((await configRow(alreadyErased))?.erased_at).toBe(earlier);

    const legacyRow = await configRow(legacy);
    expect(legacyRow?.payload).toBe("{}");
    expect(legacyRow?.token_hash).toBeNull();

    // The stale id still belongs to its install: another token cannot take it, and the
    // owner's next publish revives it.
    const squat = await call("PUT", "/v1/config", stale, {
      token: freshToken(),
      body: JSON.stringify({ forceNumber: 9 }),
    });
    expect(squat.status).toBe(401);
    const revive = await call("PUT", "/v1/config", stale, {
      token: staleToken,
      body: JSON.stringify({ forceNumber: 9 }),
    });
    expect(revive.status).toBe(204);
    expect((await configRow(stale))?.erased_at).toBeNull();
  });

  it("runs from the cron alongside the peek prune", async () => {
    const now = Date.now();
    const stale = freshId();
    await insertRow({
      id: stale,
      payload: JSON.stringify({ forceNumber: 1 }),
      updated_at: now - CONFIG_RETENTION_MS - DAY_MS,
      token_hash: await sha256Hex(freshToken()),
    });

    await runScheduled();

    expect((await configRow(stale))?.erased_at).not.toBeNull();
  });

  it("does nothing when there is nothing to erase", async () => {
    const id = freshId();
    await insertRow({ id, updated_at: Date.now(), token_hash: await sha256Hex(freshToken()) });
    await eraseUnusedConfigs(env);
    expect((await configRow(id))?.erased_at).toBeNull();
  });
});
