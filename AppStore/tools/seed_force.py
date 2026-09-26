#!/usr/bin/env python3
"""Seed the Force app-group settings so screenshots show a configured app.

Written through `defaults` inside the simulator rather than straight into the plist:
cfprefsd owns that file and caches it, and a direct write gets silently clobbered the
next time the app saves. The domain is the plist inside the App Group container, named by
path: `defaults write <group id>` from `simctl spawn` writes a domain of that name in the
simulator's home instead, which the app never reads. The app must have been launched once
so the container exists.
"""
import json
import subprocess
import sys

UDID = sys.argv[1]
APP = "com.mobleypro.mobley.Force"
GROUP = "group.com.mobleypro.mobley.Force"
KEY = "calculatorSettings"

settings = {
    "theme": "dark",
    "forceNumber": int(sys.argv[2]) if len(sys.argv) > 2 else 4556325,
    "activationCount": 3,
    "currentCount": 0,
    "magicTrickMode": "Force Number",
    "buttonTheme": "Orange",
    "openToCalculator": False,
    "dateTimeFormat": "MMDDYYXXXX",
    "plusPerfectEnabled": True,
    "plusPerfectHapticsEnabled": True,
    "startWithScreenshot": False,
    "livePeekEnabled": len(sys.argv) > 3 and sys.argv[3] == "peek",
}

container = subprocess.run(
    ["xcrun", "simctl", "get_app_container", UDID, APP, GROUP],
    check=True, capture_output=True, text=True,
).stdout.strip()
domain = f"{container}/Library/Preferences/{GROUP}"

payload = json.dumps(settings).encode()
subprocess.run(
    ["xcrun", "simctl", "spawn", UDID, "defaults", "write", domain, KEY,
     "-data", payload.hex()],
    check=True,
)
print(f"seeded forceNumber={settings['forceNumber']} livePeek={settings['livePeekEnabled']}")
