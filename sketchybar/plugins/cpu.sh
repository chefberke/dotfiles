#!/bin/bash
# Current CPU usage (user + sys). Uses top's 2nd sample (the accurate one).
CPU=$(top -l 2 -n 0 | awk '/CPU usage/ {u=$3; s=$5} END {gsub(/%/,"",u); gsub(/%/,"",s); printf "%.0f", u+s}')
sketchybar --set "$NAME" label="${CPU}%"
