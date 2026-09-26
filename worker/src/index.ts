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
      return privacyPolicy();
    }

    if (url.pathname === "/support" || url.pathname === "/support/") {
      return supportPage();
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
    <li><a href="/support">Support</a></li>
    <li><a href="/privacy">Privacy policy</a></li>
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

/** Public privacy policy for App Store Connect. HTML so a browser can open it. */
function privacyPolicy(): Response {
  const body = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Force — Privacy Policy</title>
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
    @media (prefers-color-scheme: dark) {
      body { color: #eee; }
    }
    h1 { font-size: 1.6rem; margin-bottom: 0.25rem; }
    h2 { font-size: 1.15rem; margin-top: 1.75rem; }
    .meta { color: #666; font-size: 0.9rem; margin-bottom: 1.5rem; }
    @media (prefers-color-scheme: dark) { .meta { color: #aaa; } }
    ul { padding-left: 1.25rem; }
  </style>
</head>
<body>
  <h1>Force Privacy Policy</h1>
  <p class="meta">Last updated: September 26, 2026</p>

  <p>
    Force is a calculator prop for magicians. It includes an optional App Clip that a
    spectator opens from a QR code or NFC sticker. This policy covers the iOS app, the
    App Clip, and the configuration service they talk to.
  </p>

  <h2>What we collect</h2>
  <p>Force does not create accounts and does not ask for your name, email, or phone number.</p>
  <ul>
    <li>
      <strong>Performer settings.</strong> When you change your force number or related
      options, the app may upload those settings to our configuration service so a printed
      QR code or NFC sticker keeps working after you edit them. Settings are numbers and
      toggles only.
    </li>
    <li>
      <strong>Live Peek (optional, off by default).</strong> If you turn Live Peek on, the
      App Clip sends the calculation a spectator types so you can read it on your own
      phone during a performance. Entries are short numeric strings and operators. They are
      kept briefly for the performance, then expire automatically, and you can clear them
      at any time.
    </li>
    <li>
      <strong>Install identifiers.</strong> Each install generates a random performer id
      and a random write token on the device. Neither is derived from your Apple ID,
      device serial, advertising identifier, or other personal data.
    </li>
  </ul>

  <h2>What we do not collect</h2>
  <ul>
    <li>Analytics, crash reports, or advertising identifiers</li>
    <li>Location, contacts, photos (except a screenshot you optionally choose yourself
      for the “Start with Screenshot” launch screen, which stays on your device)</li>
    <li>Data from third-party SDKs — Force ships with none</li>
  </ul>

  <h2>How data is used</h2>
  <p>
    Settings and Live Peek exist only so the trick works across your phone and a
    spectator’s App Clip. We do not sell data, use it for advertising, or combine it with
    other sources to identify a person.
  </p>

  <h2>Where data is stored</h2>
  <p>
    Configuration and Live Peek are stored on a Cloudflare Worker and D1 database under
    our control. Tokens never leave the performer’s Keychain except as a bearer
    credential on publish and peek-read requests.
  </p>

  <h2>Retention</h2>
  <ul>
    <li>Settings remain until you overwrite them, and are erased after a year without the
      app being opened.</li>
    <li>Live Peek entries expire after about ten minutes and can be cleared sooner.</li>
  </ul>

  <h2>Children</h2>
  <p>Force is not directed at children under 13, and we do not knowingly collect data from them.</p>

  <h2>Contact</h2>
  <p>
    Questions about this policy: Jonathan Mobley —
    <a href="mailto:jon.mobley@me.com">jon.mobley@me.com</a>
  </p>
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

/** Support page required by App Store Connect (Guideline 1.5). */
function supportPage(): Response {
  const body = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Force — Support</title>
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
    h1 { font-size: 1.6rem; margin-bottom: 0.25rem; }
    h2 { font-size: 1.15rem; margin-top: 1.75rem; }
    .meta { color: #666; font-size: 0.9rem; margin-bottom: 1.5rem; }
    @media (prefers-color-scheme: dark) { .meta { color: #aaa; } }
    ul { padding-left: 1.25rem; }
  </style>
</head>
<body>
  <h1>Force Support</h1>
  <p class="meta">Force Calculator Magic — help for performers</p>

  <p>
    Force is a calculator prop for magicians. If something is not working during a
    show or while setting up QR / NFC sharing, email and we will help you sort it out.
  </p>

  <h2>Contact</h2>
  <p>
    Jonathan Mobley —
    <a href="mailto:jonmobley@gmail.com">jonmobley@gmail.com</a>
  </p>

  <h2>Common topics</h2>
  <ul>
    <li>App Clip QR code or NFC sticker not opening the spectator calculator</li>
    <li>Live Peek not showing the spectator’s calculation</li>
    <li>Settings not updating for spectators after you change the force number</li>
    <li>Perfect Plus / face-down behavior</li>
  </ul>

  <h2>Privacy</h2>
  <p>
    See the
    <a href="/privacy">privacy policy</a>
    for what the app sends over the network.
  </p>
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

