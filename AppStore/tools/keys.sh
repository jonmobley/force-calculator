#!/bin/bash
# Taps Force calculator keys by name, in device points for a 440x956 pt iPhone screen.
set -eu
DRIVE=/tmp/simdrive.sh
W=440
H=956

for name in "$@"; do
  case "$name" in
    back)  C="64.5 412"  ;; ac)   C="168 412" ;; pct) C="272 412" ;; div) C="376.5 412" ;;
    7)     C="64.5 515"  ;; 8)    C="168 515" ;; 9)   C="272 515" ;; mul) C="376.5 515" ;;
    4)     C="64.5 619"  ;; 5)    C="168 619" ;; 6)   C="272 619" ;; sub) C="376.5 619" ;;
    1)     C="64.5 723"  ;; 2)    C="168 723" ;; 3)   C="272 723" ;; add) C="376.5 723" ;;
    sign)  C="64.5 827"  ;; 0)    C="168 827" ;; dot) C="272 827" ;; eq)  C="376.5 827" ;;
    clock) C="36 85"     ;; menu) C="402 85"  ;;
    pause) sleep 1; continue ;;
    *) echo "unknown key: $name" >&2; exit 1 ;;
  esac
  "$DRIVE" tap $W $H $C 2>/dev/null
  sleep 0.35
done
