#!/bin/bash
# Create the Force App Store Connect record and upload a build.
#
# Requires:
#   export APP_STORE_CONNECT_API_KEY_ID=RMTQJ69QZD   # or F94A5D2R25
#   export APP_STORE_CONNECT_API_ISSUER_ID=<uuid from Users and Access → Keys>
#   Auth key at ~/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8
#
# Usage: ./AppStore/asc-ship.sh

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KEY_ID="${APP_STORE_CONNECT_API_KEY_ID:?set APP_STORE_CONNECT_API_KEY_ID}"
ISSUER="${APP_STORE_CONNECT_API_ISSUER_ID:?set APP_STORE_CONNECT_API_ISSUER_ID}"
KEY_PATH="${HOME}/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8"
test -f "$KEY_PATH" || { echo "missing $KEY_PATH"; exit 1; }

python3 - <<'PY' "$KEY_ID" "$ISSUER" "$KEY_PATH" "$ROOT"
import json, pathlib, sys, time, urllib.request, urllib.error, jwt

kid, issuer, key_path, root = sys.argv[1:5]
private = pathlib.Path(key_path).read_text()

def token():
    return jwt.encode(
        {"iss": issuer, "iat": int(time.time()), "exp": int(time.time()) + 20 * 60,
         "aud": "appstoreconnect-v1"},
        private, algorithm="ES256", headers={"kid": kid, "typ": "JWT"},
    )

def api(method, path, body=None):
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(
        f"https://api.appstoreconnect.apple.com{path}",
        data=data, method=method,
        headers={
            "Authorization": f"Bearer {token()}",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            raw = r.read()
            return r.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        print(e.read().decode()[:800], file=sys.stderr)
        raise

# Resolve bundle id resource
status, bundles = api("GET", "/v1/bundleIds?filter[identifier]=com.mobleypro.mobley.Force&limit=1")
if bundles.get("data"):
    bundle_id = bundles["data"][0]["id"]
    print("bundle id exists:", bundle_id)
else:
    status, created = api("POST", "/v1/bundleIds", {
        "data": {
            "type": "bundleIds",
            "attributes": {
                "identifier": "com.mobleypro.mobley.Force",
                "name": "Force",
                "platform": "IOS",
            },
        }
    })
    bundle_id = created["data"]["id"]
    print("created bundle id:", bundle_id)

status, apps = api("GET", "/v1/apps?filter[bundleId]=com.mobleypro.mobley.Force&limit=1")
if apps.get("data"):
    app_id = apps["data"][0]["id"]
    print("app exists:", app_id)
else:
    status, created = api("POST", "/v1/apps", {
        "data": {
            "type": "apps",
            "attributes": {
                "bundleId": "com.mobleypro.mobley.Force",
                "name": "Force",
                "primaryLocale": "en-US",
                "sku": "force-calculator",
            },
        }
    })
    app_id = created["data"]["id"]
    print("created app:", app_id)

print("APP_ID=" + app_id)
pathlib.Path(root, "AppStore", ".app_id").write_text(app_id + "\n")
print("Next: archive with Apple Distribution, then:")
print(f"  xcrun altool --upload-app -f Force.ipa -t ios --apiKey {kid} --apiIssuer {issuer}")
PY

ARCHIVE=/tmp/ForceDist.xcarchive
EXPORT=/tmp/ForceExport
echo "Archiving Release with automatic signing…"
xcodebuild -scheme Force -project "$ROOT/Force.xcodeproj" -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=2YBTPD32DW \
  CODE_SIGN_STYLE=Automatic \
  archive

echo "Exporting / uploading to App Store Connect…"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT" \
  -exportOptionsPlist "$ROOT/AppStore/ExportOptions.plist" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY_PATH" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER"

echo "Done. IPA/export at $EXPORT"
echo "Paste AppStore/REVIEW-NOTES.md into App Review Notes and attach a performance video."
