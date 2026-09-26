# Screenshot capture tools

Regenerates App Store screenshots from a simulator. Everything here drives a booted
simulator from the shell, so a release only needs the steps below re-run rather than a
set of screens captured by hand.

## Why these exist

The app has no accessibility identifiers, so XCUITest could not address its controls
without changes to the app itself. These tools tap by device-point coordinate instead,
after measuring where the simulator is drawing the device screen. If accessibility
identifiers are added later, an XCUITest screenshot plan would be the better home for
this and these can be retired.

## Requirements

- Xcode simulators for the sizes Apple requires: iPhone 6.9" (1320x2868) and,
  while the app ships for iPad, iPad 13" (2064x2752).
- The Simulator app must be frontmost while tapping; `screencapture` needs the
  terminal's screen-recording grant, which a freshly built binary does not have.

## Build

```bash
swiftc -O simclick.swift -o /tmp/simclick
swiftc -O flatten.swift -o /tmp/flatten
```

`simdrive.sh` and `keys.sh` expect `/tmp/simclick`; adjust `BIN`/`DRIVE` to relocate.

## Capture

```bash
UDID=<simulator udid>

# Put the app in a presentable state: force number set, features on. Launch the
# app once first so its App Group container exists, and quit it before seeding.
# Pass a force number, and `peek` as a third argument to turn Live Peek on in a
# build that offers it.
python3 seed_force.py $UDID 4556325

# Freeze the status bar the way Apple's own marketing shots look.
xcrun simctl status_bar $UDID override --time "9:41" \
  --batteryState charged --batteryLevel 100 --wifiMode active --wifiBars 3

xcrun simctl launch $UDID com.mobleypro.mobley.Force

# Measure where the device screen sits inside the simulator window. Run this while a
# light screen is showing: the detector finds the screen as the lit band inside the
# bezel, and the all-black calculator gives it nothing to find.
./simdrive.sh calibrate "iPhone 17 Pro Max"

# Drive the UI. Coordinates are device points; keys.sh names the calculator keys.
./simdrive.sh tap 440 956 220 864          # Open Force Calculator
./keys.sh ac 1 2 add 3 4 eq eq eq          # runs the force
./simdrive.sh drag 440 956 220 700 220 330 # scroll a form

xcrun simctl io $UDID screenshot shot.png
```

## Before uploading

App Store Connect rejects screenshots carrying an alpha channel, which simulator
captures always have.

```bash
/tmp/flatten ../Screenshots/iPhone-6.9/*.png
```

## Gotchas

- The calculator's top-right control is the covert mode switcher, not a menu. Tapping
  it flips Force Number to Date and Time and the change persists. The way out of the
  calculator is a long press on the clock at top left: `./simdrive.sh tap 440 956 36 85 0.8`.
- `screencapture` refuses to write to dot-prefixed paths.
