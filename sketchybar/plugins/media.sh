#!/bin/bash
# Now playing: Spotify first, then Apple Music. Only shown while running and playing.
RESULT=""

if [ "$(osascript -e 'application "Spotify" is running' 2>/dev/null)" = "true" ]; then
  if [ "$(osascript -e 'tell application "Spotify" to player state' 2>/dev/null)" = "playing" ]; then
    RESULT="$(osascript -e 'tell application "Spotify" to (get artist of current track) & " - " & (name of current track)' 2>/dev/null)"
  fi
fi

if [ -z "$RESULT" ] && [ "$(osascript -e 'application "Music" is running' 2>/dev/null)" = "true" ]; then
  if [ "$(osascript -e 'tell application "Music" to player state' 2>/dev/null)" = "playing" ]; then
    RESULT="$(osascript -e 'tell application "Music" to (get artist of current track) & " - " & (name of current track)' 2>/dev/null)"
  fi
fi

if [ -n "$RESULT" ]; then
  # Truncate if too long
  if [ ${#RESULT} -gt 40 ]; then RESULT="${RESULT:0:39}…"; fi
  sketchybar --set "$NAME" label="$RESULT" drawing=on
else
  sketchybar --set "$NAME" drawing=off
fi
