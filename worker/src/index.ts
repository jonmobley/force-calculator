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
 *   DELETE /v1/config?id=<performer>  -> erase settings and peeks, requires that id's token
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
 *
 * Settings the app has not published to in a year are erased by the cron, and the owner
 * can erase them sooner. The id stays bound to its token either way, so a tag printed
 * with it can never be claimed by someone else.
 */

import { readConfig, writeConfig, type ConfigEnv } from "./config";
import {
  clearPeek,
  json,
  problem,
  pruneExpiredPeeks,
  readPeek,
  writePeek,
} from "./peek";
import { eraseConfig, eraseUnusedConfigs } from "./retention";

const DEFAULT_ID = "default";

/** Ids are used directly as primary keys, so keep them boring. */
const ID_PATTERN = /^[A-Za-z0-9_-]{1,64}$/;

interface Env extends ConfigEnv {}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/health") {
      return json({ ok: true });
    }

    if (url.pathname === "/" || url.pathname === "") {
      return homePage();
    }

    if (url.pathname === "/privacy" || url.pathname === "/privacy/") {
      return movedTo("https://moxieapps.io/force/privacy");
    }

    if (url.pathname === "/support" || url.pathname === "/support/") {
      return movedTo("https://moxieapps.io/force/support");
    }

    if (url.pathname !== "/v1/config" && url.pathname !== "/v1/peek") {
      return problem(404, "Not found");
    }

    const id = url.searchParams.get("id") ?? DEFAULT_ID;
    if (!ID_PATTERN.test(id)) {
      return problem(400, "Invalid id");
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
      case "DELETE":
        return eraseConfig(request, env, id);
      default:
        return problem(405, "Method not allowed");
    }
  },

  async scheduled(
    _controller: ScheduledController,
    env: Env,
    _ctx: ExecutionContext,
  ): Promise<void> {
    await pruneExpiredPeeks(env);
    await eraseUnusedConfigs(env);
  },
} satisfies ExportedHandler<Env>;

/** Brand landing for forcemagic.app — points reviewers and buyers to support. */
function homePage(): Response {
  const body = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Force — Calculator prop for magicians</title>
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
    @media (prefers-color-scheme: dark) { body { color: #eee; } }
    h1 { font-size: 1.75rem; margin-bottom: 0.35rem; }
    .meta { color: #666; font-size: 0.95rem; margin-bottom: 1.5rem; }
    @media (prefers-color-scheme: dark) { .meta { color: #aaa; } }
    a { color: inherit; }
    ul { padding-left: 1.25rem; }
  </style>
</head>
<body>
  <h1>Force</h1>
  <p class="meta">Calculator prop for magicians</p>
  <p>
    Force is a working calculator that, at a moment you choose, lands on the number
    you set in advance. Share it with a spectator via QR or NFC App Clip.
  </p>
  <ul>
    <li><a href="https://moxieapps.io/force/support">Support</a></li>
    <li><a href="https://moxieapps.io/force/privacy">Privacy policy</a></li>
  </ul>
</body>
</html>`;

  return new Response(body, {
    status: 200,
    headers: {
      "content-type": "text/html; charset=utf-8",
      "cache-control": "public, max-age=300",
    },
  });
}

/** The human pages now live on the Moxie site; keep the old URLs working. */
function movedTo(location: string): Response {
  return new Response(null, { status: 301, headers: { location } });
}

