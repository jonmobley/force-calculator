#!/usr/bin/env python3
"""Seed the Force app-group settings so screenshots show a configured app.

Written through `defaults` inside the simulator rather than straight into the plist:
cfprefsd owns that file and caches it, and a direct write gets silently clobbered the
next time the app saves.
"""
import json
import subprocess
import sys

UDID = sys.argv[1]
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
    "livePeekEnabled": len(sys.argv) <= 3 or sys.argv[3] != "nopeek",
}

payload = json.dumps(settings).encode()
subprocess.run(
    ["xcrun", "simctl", "spawn", UDID, "defaults", "write", GROUP, KEY,
     "-data", payload.hex()],
    check=True,
)
print(f"seeded forceNumber={settings['forceNumber']} livePeek={settings['livePeekEnabled']}")
