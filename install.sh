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
link "$DOTFILES/claude/statusline.sh" "$HOME/.claude/statusline.sh"
# lazygit: config.yml only — lazygit writes state.yml next to it, leave that alone
link "$DOTFILES/lazygit/config.yml"   "$HOME/Library/Application Support/lazygit/config.yml"

echo "Done."
