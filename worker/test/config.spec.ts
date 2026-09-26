import { describe, expect, it } from "vitest";
import { storeConfig } from "../src/config";
import { authorize, sha256Hex } from "../src/peek";
import {
  call,
  configRow,
  env,
  freshId,
  freshIp,
  freshToken,
  insertRow,
} from "./helpers";

const SETTINGS = JSON.stringify({ forceNumber: 1234, livePeekEnabled: false });
const OTHER_SETTINGS = JSON.stringify({ forceNumber: 99, livePeekEnabled: false });

describe("ownership", () => {
  it("binds the id to the first token and refuses every other", async () => {
    const id = freshId();
    const owner = freshToken();
    const intruder = freshToken();

    expect((await call("GET", "/v1/config", id)).status).toBe(404);

    const claim = await call("PUT", "/v1/config", id, { token: owner, body: SETTINGS });
    expect(claim.status).toBe(204);
    expect((await configRow(id))?.token_hash).toBe(await sha256Hex(owner));

    const stolen = await call("PUT", "/v1/config", id, {
      token: intruder,
      body: OTHER_SETTINGS,
    });
    expect(stolen.status).toBe(401);
    expect(await stolen.json()).toEqual({ error: "Unauthorized" });

    const read = await call("GET", "/v1/config", id);
    expect(read.status).toBe(200);
    expect(read.headers.get("cache-control")).toBe("no-store");
    expect(await read.text()).toBe(SETTINGS);

    const again = await call("PUT", "/v1/config", id, {
      token: owner,
      body: OTHER_SETTINGS,
    });
    expect(again.status).toBe(204);
    expect(await (await call("GET", "/v1/config", id)).text()).toBe(OTHER_SETTINGS);
  });

  it("requires a bearer token and a JSON body", async () => {
    const id = freshId();
    expect((await call("PUT", "/v1/config", id, { body: SETTINGS })).status).toBe(401);
    const notJson = await call("PUT", "/v1/config", id, {
      token: freshToken(),
      body: "not json",
    });
    expect(notJson.status).toBe(400);
    expect(await configRow(id)).toBeNull();
  });

  it("rejects ids outside the allowlist", async () => {
    const response = await call("GET", "/v1/config", "not%20ok");
    expect(response.status).toBe(400);
  });
});

describe("the claim race", () => {
  it("lets exactly one of many simultaneous first writers claim the id", async () => {
    const id = freshId();
    const tokens = Array.from({ length: 12 }, freshToken);

    const responses = await Promise.all(
      tokens.map((token, index) =>
        call("PUT", "/v1/config", id, {
          token,
          body: JSON.stringify({ forceNumber: index }),
        }),
      ),
    );
    const statuses = responses.map((response) => response.status);
    expect(statuses.filter((status) => status === 204)).toHaveLength(1);
    expect(statuses.filter((status) => status === 401)).toHaveLength(11);

    const winner = statuses.indexOf(204);
    const row = await configRow(id);
    expect(row?.token_hash).toBe(await sha256Hex(tokens[winner]));
    expect(JSON.parse(row?.payload ?? "")).toEqual({ forceNumber: winner });
  });

  it("refuses a stale claim once another token has taken the id", async () => {
    const id = freshId();
    const owner = freshToken();
    const loser = freshToken();

    // Both were told `claim` before either wrote; the owner lands first.
    expect(await authorize(env, id, loser)).toBe("claim");
    expect(await storeConfig(env, id, SETTINGS, owner, "claim")).toBe(true);

    expect(await storeConfig(env, id, OTHER_SETTINGS, loser, "claim")).toBe(false);

    const row = await configRow(id);
    expect(row?.payload).toBe(SETTINGS);
    expect(row?.token_hash).toBe(await sha256Hex(owner));
  });

  it("lets the same install publishing twice at once land both writes", async () => {
    const id = freshId();
    const owner = freshToken();

    expect(await storeConfig(env, id, SETTINGS, owner, "claim")).toBe(true);
    expect(await storeConfig(env, id, OTHER_SETTINGS, owner, "claim")).toBe(true);
    expect((await configRow(id))?.payload).toBe(OTHER_SETTINGS);
  });
});

describe("the legacy token", () => {
  it("serves a row with no hash to the service-wide token only", async () => {
    const id = freshId();
    await insertRow({ id, payload: SETTINGS, token_hash: null });

    expect(await authorize(env, id, env.WRITE_TOKEN)).toBe("matched");
    expect(await authorize(env, id, freshToken())).toBe("denied");

    const write = await call("PUT", "/v1/config", id, {
      token: env.WRITE_TOKEN,
      body: OTHER_SETTINGS,
    });
    expect(write.status).toBe(204);

    const row = await configRow(id);
    expect(row?.payload).toBe(OTHER_SETTINGS);
    expect(row?.token_hash).toBe(await sha256Hex(env.WRITE_TOKEN));
  });

  it("keeps a bound legacy row working after the secret is rotated", async () => {
    const id = freshId();
    const oldSecret = env.WRITE_TOKEN;
    await insertRow({ id, payload: SETTINGS, token_hash: null });
    const bind = await call("PUT", "/v1/config", id, { token: oldSecret, body: SETTINGS });
    expect(bind.status).toBe(204);

    const rotated = { ...env, WRITE_TOKEN: "rotated-service-token" };
    expect(await authorize(rotated, id, oldSecret)).toBe("matched");
    expect(await authorize(rotated, id, rotated.WRITE_TOKEN)).toBe("denied");

    // An unbound row follows the secret: the old one stops working the moment it rotates.
    const unbound = freshId();
    await insertRow({ id: unbound, token_hash: null });
    expect(await authorize(rotated, unbound, oldSecret)).toBe("denied");
    expect(await authorize(rotated, unbound, rotated.WRITE_TOKEN)).toBe("matched");
  });

  it("binds only the hash of the token that wrote, never a racing writer's", async () => {
    const id = freshId();
    await insertRow({ id, token_hash: null });
    const outcomes = await Promise.all([
      call("PUT", "/v1/config", id, { token: env.WRITE_TOKEN, body: SETTINGS }),
      call("PUT", "/v1/config", id, { token: freshToken(), body: OTHER_SETTINGS }),
    ]);
    expect(outcomes.map((response) => response.status)).toEqual([204, 401]);
    const row = await configRow(id);
    expect(row?.token_hash).toBe(await sha256Hex(env.WRITE_TOKEN));
    expect(row?.payload).toBe(SETTINGS);
  });

  it("does not open a claimed row to the service-wide token", async () => {
    const id = freshId();
    await insertRow({ id, token_hash: await sha256Hex(freshToken()) });

    expect(await authorize(env, id, env.WRITE_TOKEN)).toBe("denied");
    const write = await call("PUT", "/v1/config", id, {
      token: env.WRITE_TOKEN,
      body: SETTINGS,
    });
    expect(write.status).toBe(401);
  });

  it("does not match a token of the same length as the secret", async () => {
    const id = freshId();
    await insertRow({ id, token_hash: null });
    const sameLength = "x".repeat(env.WRITE_TOKEN.length);
    expect(await authorize(env, id, sameLength)).toBe("denied");
  });
});

describe("the config write limit", () => {
  it("returns 429 after thirty writes a minute from one client", async () => {
    const id = freshId();
    const owner = freshToken();
    const ip = freshIp();

    for (let attempt = 0; attempt < 30; attempt += 1) {
      const response = await call("PUT", "/v1/config", id, {
        token: owner,
        body: SETTINGS,
        ip,
      });
      expect(response.status, `write ${attempt + 1}`).toBe(204);
    }

    const limited = await call("PUT", "/v1/config", id, {
      token: owner,
      body: SETTINGS,
      ip,
    });
    expect(limited.status).toBe(429);

    // Another client is unaffected.
    const other = await call("PUT", "/v1/config", id, { token: owner, body: SETTINGS });
    expect(other.status).toBe(204);
  });

  it("is checked before the token, so bulk squatting cannot even be attempted", async () => {
    const ip = freshIp();

    for (let attempt = 0; attempt < 30; attempt += 1) {
      await call("PUT", "/v1/config", freshId(), { token: freshToken(), body: SETTINGS, ip });
    }

    const id = freshId();
    const noToken = await call("PUT", "/v1/config", id, { body: SETTINGS, ip });
    expect(noToken.status).toBe(429);
    expect(await configRow(id)).toBeNull();
  });

  it("does not gate reads", async () => {
    const id = freshId();
    const ip = freshIp();
    for (let attempt = 0; attempt < 40; attempt += 1) {
      expect((await call("GET", "/v1/config", id, { ip })).status).toBe(404);
    }
  });
});
