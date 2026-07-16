#!/bin/bash
# RAM usage percentage (100 - free percentage).
FREE=$(memory_pressure 2>/dev/null | awk -F: '/free percentage/ {gsub(/[ %]/,"",$2); print $2}')
if [ -n "$FREE" ]; then
  USED=$((100 - FREE))
  sketchybar --set "$NAME" label="${USED}%"
fi
