#!/bin/bash
# Drives an iOS Simulator window by device-point coordinates.
#
#   simdrive.sh calibrate "<window title fragment>"
#   simdrive.sh tap <devW> <devH> <xPt> <yPt> [holdSeconds]
#   simdrive.sh shot <udid> <outfile>
#
# Calibration is cached in /tmp/.simdrive-cal so taps stay cheap.

set -euo pipefail
CAL=/tmp/simdrive-cal
BIN=/tmp/simclick

case "$1" in
calibrate)
  TITLE="$2"
  # Raised and pinned to a known spot first. Region capture sees whatever is actually on
  # screen, so a Simulator sitting behind another window calibrates against that window
  # instead, and a window that has drifted invalidates a cached calibration.
  GEO=$(osascript <<EOF
tell application "Simulator" to activate
delay 1.5
tell application "System Events" to tell process "Simulator"
  set frontmost to true
  set w to first window whose name contains "$TITLE"
  perform action "AXRaise" of w
  set position of w to {100, 40}
  delay 0.8
  set p to position of w
  set s to size of w
  return (item 1 of p as text) & " " & (item 2 of p as text) & " " & (item 1 of s as text) & " " & (item 2 of s as text)
end tell
EOF
)
  read -r WX WY WW WH <<<"$GEO"
  screencapture -x -o -R"$WX,$WY,$WW,$WH" /tmp/simdrive-cap.png
  "$BIN" calibrate /tmp/simdrive-cap.png "$WX" "$WY" "$WW" "$WH" >"$CAL"
  echo "window $WX,$WY ${WW}x${WH} -> screen $(cat $CAL)"
  ;;
tap)
  read -r SX SY SW SH <"$CAL"
  "$BIN" tap "$SX" "$SY" "$SW" "$SH" "$2" "$3" "$4" "$5" "${6:-0}"
  ;;
drag)
  read -r SX SY SW SH <"$CAL"
  "$BIN" drag "$SX" "$SY" "$SW" "$SH" "$2" "$3" "$4" "$5" "$6" "$7"
  ;;
scroll)
  read -r SX SY SW SH <"$CAL"
  "$BIN" scroll "$SX" "$SY" "$SW" "$SH" "$2" "$3" "$4" "$5" "${6:--10}"
  ;;
shot)
  xcrun simctl io "$2" screenshot "$3" >/dev/null 2>&1
  echo "wrote $3"
  ;;
*)
  echo "unknown command $1" >&2
  exit 2
  ;;
esac
