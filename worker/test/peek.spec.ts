import { describe, expect, it } from "vitest";
import { ENTRY_TTL_MS, pruneExpiredPeeks } from "../src/peek";
import {
  call,
  env,
  freshId,
  freshToken,
  peekRowCount,
  publishWithPeek,
} from "./helpers";

interface PeekEntry {
  value: string;
  op?: string;
  at: number;
}

function report(id: string, entry: { value: string; entryID?: string; op?: string }) {
  return call("PUT", "/v1/peek", id, { body: JSON.stringify(entry) });
}

async function readEntries(id: string, token: string): Promise<PeekEntry[]> {
  const response = await call("GET", "/v1/peek", id, { token });
  expect(response.status).toBe(200);
  const body = (await response.json()) as { entries: PeekEntry[] };
  return body.entries;
}

describe("peek gating", () => {
  it("admits writes only once the id has Live Peek published on", async () => {
    const id = freshId();
    const owner = freshToken();

    expect((await report(id, { value: "1", entryID: "e1" })).status).toBe(404);

    const off = await call("PUT", "/v1/config", id, {
      token: owner,
      body: JSON.stringify({ forceNumber: 1, livePeekEnabled: false }),
    });
    expect(off.status).toBe(204);
    expect((await report(id, { value: "1", entryID: "e1" })).status).toBe(404);
    expect(await peekRowCount(id)).toBe(0);

    await publishWithPeek(id, owner);
    expect((await report(id, { value: "1", entryID: "e1" })).status).toBe(204);
    expect(await peekRowCount(id)).toBe(1);
  });

  it("accepts only calculator display text and known operators", async () => {
    const id = freshId();
    await publishWithPeek(id, freshToken());

    expect((await report(id, { value: "1,234.5", entryID: "a" })).status).toBe(204);
    expect((await report(id, { value: "Error", entryID: "b" })).status).toBe(204);
    expect((await report(id, { value: "-1e+10", entryID: "c" })).status).toBe(204);
    expect((await report(id, { value: "DROP", entryID: "d" })).status).toBe(400);
    expect((await report(id, { value: "", entryID: "e" })).status).toBe(400);
    expect((await report(id, { value: "1", entryID: "f", op: "+" })).status).toBe(204);
    expect((await report(id, { value: "1", entryID: "g", op: "plus" })).status).toBe(400);
    expect((await report(id, { value: "1", entryID: "bad id!" })).status).toBe(400);

    const notJson = await call("PUT", "/v1/peek", id, { body: "{" });
    expect(notJson.status).toBe(400);
  });
});

describe("peek reads", () => {
  it("are only for the owner and show the calculation oldest first", async () => {
    const id = freshId();
    const owner = freshToken();
    await publishWithPeek(id, owner);

    expect((await call("GET", "/v1/peek", id, { token: owner })).status).toBe(404);

    expect((await report(id, { value: "123", entryID: "e1" })).status).toBe(204);
    expect((await report(id, { value: "123", entryID: "e1", op: "+" })).status).toBe(204);
    expect((await report(id, { value: "456", entryID: "e2", op: "=" })).status).toBe(204);
    expect((await report(id, { value: "579", entryID: "e3" })).status).toBe(204);

    expect((await call("GET", "/v1/peek", id)).status).toBe(401);
    expect((await call("GET", "/v1/peek", id, { token: freshToken() })).status).toBe(401);

    const entries = await readEntries(id, owner);
    expect(entries.map((entry) => [entry.value, entry.op])).toEqual([
      ["123", "+"],
      ["456", "="],
      ["579", undefined],
    ]);
  });

  it("refuse an unclaimed id even with a fresh token", async () => {
    const response = await call("GET", "/v1/peek", freshId(), { token: freshToken() });
    expect(response.status).toBe(401);
  });

  it("hide entries past the ten-minute lifetime, and the cron removes them", async () => {
    const id = freshId();
    const owner = freshToken();
    await publishWithPeek(id, owner);
    await env.DB.prepare(
      "INSERT INTO peek_entry (id, entry_id, value, op, created_at) VALUES (?, ?, ?, ?, ?)",
    )
      .bind(id, "old", "7", null, Date.now() - ENTRY_TTL_MS - 1000)
      .run();

    expect((await call("GET", "/v1/peek", id, { token: owner })).status).toBe(404);
    expect(await peekRowCount(id)).toBe(1);

    await pruneExpiredPeeks(env);
    expect(await peekRowCount(id)).toBe(0);
  });
});

describe("peek clears", () => {
  it("wipe the calculation for the owner only", async () => {
    const id = freshId();
    const owner = freshToken();
    await publishWithPeek(id, owner);
    expect((await report(id, { value: "1", entryID: "e1" })).status).toBe(204);
    expect((await report(id, { value: "2", entryID: "e2" })).status).toBe(204);

    expect((await call("DELETE", "/v1/peek", id)).status).toBe(401);
    expect((await call("DELETE", "/v1/peek", id, { token: freshToken() })).status).toBe(401);
    expect(await peekRowCount(id)).toBe(2);

    expect((await call("DELETE", "/v1/peek", id, { token: owner })).status).toBe(204);
    expect(await peekRowCount(id)).toBe(0);
    expect((await call("GET", "/v1/peek", id, { token: owner })).status).toBe(404);

    // The next spectator starts on a clean readout.
    expect((await report(id, { value: "3", entryID: "e3" })).status).toBe(204);
    expect((await readEntries(id, owner)).map((entry) => entry.value)).toEqual(["3"]);
  });
});
