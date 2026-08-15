#!/usr/bin/env bash
# Dotfiles setup: symlinks the configs in this repo to their expected locations.
# Existing real files/directories are backed up as *.bak; safe to re-run.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ]; then
    rm "$dst"
  elif [ -e "$dst" ]; then
    mv "$dst" "$dst.bak"
    echo "backed up: $dst -> $dst.bak"
  fi
  ln -s "$src" "$dst"
  echo "linked:    $dst -> $src"
}

link "$DOTFILES/ghostty"              "$HOME/.config/ghostty"
link "$DOTFILES/sketchybar"           "$HOME/.config/sketchybar"
link "$DOTFILES/skhd"                 "$HOME/.config/skhd"
link "$DOTFILES/yabai"                "$HOME/.config/yabai"
link "$DOTFILES/claude/statusline.sh"    "$HOME/.claude/statusline.sh"
link "$DOTFILES/claude/CLAUDE.md"        "$HOME/.claude/CLAUDE.md"
link "$DOTFILES/claude/agents/reviewer.md" "$HOME/.claude/agents/reviewer.md"
link "$DOTFILES/claude/skills/my-review" "$HOME/.claude/skills/my-review"

link "$DOTFILES/druk/config.json"        "$HOME/.config/druk/config.json"

# pi: file by file, never the whole ~/.pi/agent directory — auth.json,
# models-store.json and sessions/ are machine state and must stay local.
link "$DOTFILES/pi/no-bold.sh"           "$HOME/.pi/no-bold.sh"
link "$DOTFILES/pi/agent/settings.json"  "$HOME/.pi/agent/settings.json"
link "$DOTFILES/pi/agent/keybindings.json" "$HOME/.pi/agent/keybindings.json"
link "$DOTFILES/pi/agent/AGENTS.md"      "$HOME/.pi/agent/AGENTS.md"
link "$DOTFILES/pi/agent/extensions"     "$HOME/.pi/agent/extensions"
link "$DOTFILES/pi/agent/themes"         "$HOME/.pi/agent/themes"

echo "Done."
