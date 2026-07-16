#!/usr/bin/env python3
# Claude Code statusline: model/effort/branch + context + 5h / weekly limit usage
import json, sys, time, subprocess

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

# 256-color palette — soft, readable tones
def c(n):      return f"\033[38;5;{n}m"
GREEN    = c(114)   # soft green
AMBER    = c(179)   # warm amber
RED      = c(174)   # soft red
LABEL    = c(245)   # labels: light gray
MUTED    = c(240)   # durations: faint gray
SEP      = c(238)   # separator: very faint
MODEL_C  = c(110)   # model: soft blue
BRANCH_C = c(108)   # branch: soft green-gray
RESET    = "\033[0m"

def color(pct):
    return RED if pct >= 90 else AMBER if pct >= 70 else GREEN

def pct_str(pct):
    return f"{color(pct)}{pct}%{RESET}"

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

model = data.get("model", {}).get("display_name", "?")
prefix = f"{MODEL_C}{model}{RESET}"

effort = data.get("effort", {}).get("level")
if effort:
    prefix += f" {MUTED}{effort}{RESET}"

cwd = data.get("workspace", {}).get("current_dir") or data.get("cwd")
branch = git_branch(cwd)
if branch:
    prefix += f"  {SEP}|{RESET} {BRANCH_C}{branch}{RESET}"

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
