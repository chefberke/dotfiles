# dotfiles

My macOS config files.

| Directory | Purpose | Target location |
|---|---|---|
| `ghostty/` | Ghostty terminal | `~/.config/ghostty` |
| `sketchybar/` | SketchyBar menu bar (+ plugins) | `~/.config/sketchybar` |
| `yabai/` | yabai tiling window manager | `~/.config/yabai` |
| `skhd/` | skhd hotkeys (used together with yabai) | `~/.config/skhd` |
| `claude/` | Claude Code statusline, global instructions, `reviewer` agent, `my-review` skill | `~/.claude/` |
| `druk/` | druk editor settings (Vesper theme, vim mode) | `~/.config/druk/config.json` |
| `pi/` | pi coding agent: settings, keybindings, Vesper theme, `cc-*` extensions | `~/.pi/` |

> `pi/` is linked file by file, never as a whole directory: `~/.pi/agent/` also holds `auth.json`,
> `models-store.json` and `sessions/`, which are machine state and stay out of this repo.
> The same applies to `~/.config/druk/` — only `config.json` is tracked; `extensions/` is downloaded
> from druk's registry and `sessions.json` is local state.
>
> `pi/no-bold.sh` patches the installed pi package, so re-run it after every pi upgrade.

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
