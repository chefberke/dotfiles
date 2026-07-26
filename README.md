# dotfiles

My macOS config files.

| Directory | Purpose | Target location |
|---|---|---|
| `ghostty/` | Ghostty terminal | `~/.config/ghostty` |
| `sketchybar/` | SketchyBar menu bar (+ plugins) | `~/.config/sketchybar` |
| `yabai/` | yabai tiling window manager | `~/.config/yabai` |
| `skhd/` | skhd hotkeys (used together with yabai) | `~/.config/skhd` |
| `claude/` | Claude Code statusline script | `~/.claude/statusline.sh` |
| `lazygit/` | lazygit (Vesper theme, delta pagers) | `~/Library/Application Support/lazygit/config.yml` |

> lazygit renders diffs with [delta](https://github.com/dandavison/delta), configured in the `[delta]`
> block of `~/.gitconfig` — that file is **not** part of this repo, so a new machine needs it copied over
> by hand.

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
