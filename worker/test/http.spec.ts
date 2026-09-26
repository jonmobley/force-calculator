import { describe, expect, it } from "vitest";
import worker from "../src/index";
import { call, env, freshId, freshToken, ORIGIN, publishWithPeek } from "./helpers";

describe("CORS", () => {
  it("is not offered on API routes, which only native clients call", async () => {
    const id = freshId();
    const owner = freshToken();
    await publishWithPeek(id, owner);

    const responses = [
      await call("GET", "/v1/config", id),
      await call("GET", "/v1/config", freshId()),
      await call("PUT", "/v1/peek", id, { body: JSON.stringify({ value: "1", entryID: "a" }) }),
      await call("GET", "/v1/peek", id, { token: owner }),
      await call("DELETE", "/v1/peek", id, { token: owner }),
    ];
    for (const response of responses) {
      expect(response.headers.get("access-control-allow-origin")).toBeNull();
    }
  });

  it("answers a preflight with 405", async () => {
    const response = await call("OPTIONS", "/v1/config", freshId());
    expect(response.status).toBe(405);
  });

  it("leaves the public pages without CORS headers too", async () => {
    const response = await worker.fetch(new Request(`${ORIGIN}/privacy`), env);
    expect(response.status).toBe(200);
    expect(response.headers.get("access-control-allow-origin")).toBeNull();
  });
});
