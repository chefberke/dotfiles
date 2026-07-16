# dotfiles

My macOS config files.

| Directory | Purpose | Target location |
|---|---|---|
| `ghostty/` | Ghostty terminal | `~/.config/ghostty` |
| `sketchybar/` | SketchyBar menu bar (+ plugins) | `~/.config/sketchybar` |
| `yabai/` | yabai tiling window manager | `~/.config/yabai` |
| `skhd/` | skhd hotkeys (used together with yabai) | `~/.config/skhd` |
| `claude/` | Claude Code statusline script | `~/.claude/statusline.sh` |

## Setup (new machine)

```sh
git clone git@github.com:chefberke/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

The script symlinks everything into place and backs up any existing files as `.bak`.

## Updating

Since the configs are symlinked, changes are reflected in the repo directly:

```sh
cd ~/dotfiles && git add -A && git commit -m "update" && git push
```
