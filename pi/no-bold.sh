#!/usr/bin/env bash
# Remove the ANSI bold (SGR 1) from pi's TUI theme.
#
# pi renders markdown **bold** and every heading with chalk.bold. With
# "Hack Nerd Font Mono" + font-thicken in Ghostty that weight is too heavy,
# so this patch makes Theme.bold() a pass-through. Colors stay unchanged.
#
# A pi upgrade replaces dist/, so run this script again after each upgrade.
set -euo pipefail

THEME="$HOME/.local/lib/node_modules/@earendil-works/pi-coding-agent/dist/modes/interactive/theme/theme.js"

if [ ! -f "$THEME" ]; then
  echo "theme.js not found: $THEME" >&2
  exit 1
fi

if grep -q "Local patch: no SGR 1" "$THEME"; then
  echo "already patched: $THEME"
  exit 0
fi

if ! grep -q "return chalk.bold(text);" "$THEME"; then
  echo "pattern 'return chalk.bold(text);' not found - pi changed, patch by hand" >&2
  exit 1
fi

perl -0pi -e 's/    bold\(text\) \{\n        return chalk\.bold\(text\);\n    \}/    bold(text) {\n        \/\/ Local patch: no SGR 1. The bold face of the terminal font is too heavy,\n        \/\/ so bold markdown keeps the normal weight. Re-apply with ~\/.pi\/no-bold.sh\n        return text;\n    }/' "$THEME"

if grep -q "Local patch: no SGR 1" "$THEME"; then
  echo "patched: $THEME"
else
  echo "patch failed" >&2
  exit 1
fi
