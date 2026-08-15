#!/bin/bash
# Wi-Fi STATUS (not the name). macOS 26 returns "<redacted>" for the SSID without
# Location permission, so we show a connected/off icon instead of the network name.
# Glyphs are produced via printf (UTF-8 octal): wifi=U+F1EB, wifi-off=U+F05A9
ICON_ON=$(printf '\357\207\253')
ICON_OFF=$(printf '\363\260\226\251')

DEV=$(networksetup -listallhardwareports 2>/dev/null | awk '/Wi-Fi|AirPort/{getline; print $2; exit}')
[ -z "$DEV" ] && DEV="en0"

POWER=$(networksetup -getairportpower "$DEV" 2>/dev/null | awk '{print $NF}')
ACTIVE=$(ifconfig "$DEV" 2>/dev/null | awk '/status:/{print $2}')

if [ "$POWER" = "On" ] && [ "$ACTIVE" = "active" ]; then
  sketchybar --set "$NAME" icon="$ICON_ON" label.drawing=off
else
  sketchybar --set "$NAME" icon="$ICON_OFF" label.drawing=off
fi
