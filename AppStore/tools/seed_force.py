#!/usr/bin/env python3
"""Launch Force on a simulator with presentable settings for screenshots.

    seed_force.py <udid> [force number] [peek]

The settings go in as a launch argument (`-calculatorSettings <data>`) rather than a
write to the preferences file. Arguments are the first domain every `UserDefaults`
consults, the App Group suite included, so the app reads them however it was signed.
A file write depends on where the suite lives, which differs between a team-signed build
(the App Group container) and an ad hoc one such as CI's, and on cfprefsd not holding a
stale copy. Nothing is persisted: relaunching without the argument restores the app's own
settings.
"""
import json
import subprocess
import sys

UDID = sys.argv[1]
APP = "com.mobleypro.mobley.Force"
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

payload = json.dumps(settings).encode()
subprocess.run(["xcrun", "simctl", "terminate", UDID, APP], capture_output=True)
subprocess.run(
    ["xcrun", "simctl", "launch", UDID, APP, f"-{KEY}", f"<{payload.hex()}>"],
    check=True,
)
print(f"launched with forceNumber={settings['forceNumber']} livePeek={settings['livePeekEnabled']}")
