#!/usr/bin/env python3
# Claude Code statusline: dir/model/effort/branch + context + 5h / weekly limit usage
import json, os, sys, time, subprocess

data = json.load(sys.stdin)

def git_branch(cwd):
    try:
        b = subprocess.run(
            ["git", "branch", "--show-current"],
            cwd=cwd, capture_output=True, text=True, timeout=1,
        )
        return b.stdout.strip() if b.returncode == 0 else ""
    except Exception:
        return ""

# Grayscale hierarchy + a single orange accent
def c(n): return f"\033[38;5;{n}m"
ACCENT = c(173)   # percentages: Claude Code orange (~#d97757)
BRIGHT = c(251)   # directory: most prominent
FG     = c(246)   # model, branch: mid gray
LABEL  = c(243)   # labels (ctx, 5h, Weekly): dimmer gray
MUTED  = c(240)   # effort, durations: dim gray
SEP    = c(238)   # separators: faintest
RESET  = "\033[0m"

def pct_str(pct):
    return f"{ACCENT}{pct}%{RESET}"

def fmt_reset(resets_at):
    diff = max(0, int(resets_at) - int(time.time()))
    d, h, m = diff // 86400, (diff % 86400) // 3600, (diff % 3600) // 60
    if d >= 1:
        left = f"{d}d {h}h"
    elif h >= 1:
        left = f"{h}h {m}min"
    else:
        left = f"{m}min"
    return f"{MUTED}{left}{RESET}"

def limit_str(label, obj):
    p = round(obj["used_percentage"])
    s = f"{LABEL}{label}{RESET} {pct_str(p)}"
    if obj.get("resets_at"):
        s += f" {MUTED}·{RESET} {fmt_reset(obj['resets_at'])}"
    return s

lines = []

cwd = data.get("workspace", {}).get("current_dir") or data.get("cwd") or ""
home = os.path.expanduser("~")
path = "~" + cwd[len(home):] if cwd.startswith(home) else cwd
parts = [p for p in path.split("/") if p]
dir_name = "/".join(parts[-2:])  # last two components, e.g. ~/dotfiles or dev/project

model = data.get("model", {}).get("display_name", "?")
prefix = f"{FG}{model}{RESET}"
if dir_name:
    prefix = f"{BRIGHT}{dir_name}{RESET}  {SEP}|{RESET} " + prefix

effort = data.get("effort", {}).get("level")
if effort:
    prefix += f" {MUTED}{effort}{RESET}"

branch = git_branch(cwd)
if branch:
    prefix += f"  {SEP}|{RESET} {FG}{branch}{RESET}"

ctx = int(data.get("context_window", {}).get("used_percentage", 0) or 0)
lines.append(f"{prefix}  {LABEL}ctx{RESET} {pct_str(ctx)}")

rate = data.get("rate_limits", {}) or {}
limits = []

five = rate.get("five_hour")
if five and five.get("used_percentage") is not None:
    limits.append(limit_str("5h", five))

week = rate.get("seven_day")
if week and week.get("used_percentage") is not None:
    limits.append(limit_str("Weekly", week))

if limits:
    lines.append(f"  {SEP}|{RESET}  ".join(limits))

print("\n".join(lines))
