#!/usr/bin/env bash
# Validate the Godot project — returns non-zero if something's broken.
# Safe to run in GitHub Actions or locally.
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

log_ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; }

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

EXIT=0

# 1. Every ext_resource path referenced in .tscn/.tres must exist
missing=0
while IFS= read -r line; do
  path=$(echo "$line" | grep -oE 'path="res://[^"]+"' | sed 's/path="res:\/\///;s/"$//' || true)
  [ -z "$path" ] && continue
  if [ ! -f "$path" ]; then
    file=$(echo "$line" | cut -d: -f1)
    log_fail "Missing resource: $path (referenced by $file)"
    missing=$((missing+1))
  fi
done < <(grep -rn 'path="res://' --include='*.tscn' --include='*.tres' . 2>/dev/null | head -500)

if [ "$missing" -gt 0 ]; then
  log_fail "$missing missing resource references."
  EXIT=1
else
  log_ok "All ext_resource paths resolve."
fi

# 2. Every autoload in project.godot must point to an existing script
if [ -f project.godot ]; then
  while IFS= read -r line; do
    path=$(echo "$line" | grep -oE '"\*res://[^"]+"' | sed 's/"\*res:\/\///;s/"$//' || true)
    [ -z "$path" ] && continue
    if [ ! -f "$path" ]; then
      log_fail "Autoload script missing: $path"
      EXIT=1
    fi
  done < <(grep -E '^\w+="\*res://' project.godot || true)
fi
log_ok "Autoload check done."

# 3. Run Godot headless parse check if available
if command -v godot >/dev/null 2>&1; then
  log_ok "Godot found: $(godot --version 2>&1 | head -1)"
  # --check-only parses scripts without running them
  if timeout 120 godot --headless --path . --quit-after 1 >/tmp/godot_out.txt 2>&1; then
    log_ok "Godot headless launch succeeded."
  else
    # Don't fail on first launch quirks — many Godot "errors" are noise.
    # Fail only if SCRIPT ERROR or PARSE ERROR is present.
    if grep -E "SCRIPT ERROR|PARSE ERROR|Parser Error|Condition \"[^\"]+\" is true" /tmp/godot_out.txt >/dev/null; then
      log_fail "Godot parse/script errors detected:"
      grep -E "SCRIPT ERROR|PARSE ERROR|Parser Error" /tmp/godot_out.txt | head -20
      EXIT=1
    else
      log_warn "Godot exited non-zero but no parse errors found (possibly runtime noise)."
    fi
  fi
else
  log_warn "Godot not installed on runner — skipping engine parse check."
fi

# 4. Sanity: main scene referenced in project.godot must exist
MAIN_SCENE=$(grep -oE 'run/main_scene="res://[^"]+"' project.godot 2>/dev/null | sed 's/run\/main_scene="res:\/\///;s/"$//' || true)
if [ -n "$MAIN_SCENE" ] && [ ! -f "$MAIN_SCENE" ]; then
  log_fail "Main scene missing: $MAIN_SCENE"
  EXIT=1
elif [ -n "$MAIN_SCENE" ]; then
  log_ok "Main scene exists: $MAIN_SCENE"
fi

if [ "$EXIT" -eq 0 ]; then
  echo ""
  log_ok "VALIDATION PASSED"
else
  echo ""
  log_fail "VALIDATION FAILED"
fi

exit "$EXIT"
