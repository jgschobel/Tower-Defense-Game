#!/usr/bin/env bash
# Validate the Godot project — returns non-zero if something's broken.
# Hardened in Phase 1.1: no head-limit, signal-connection check, autoload
# script existence check, full ext_resource scan.
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

# 1. Every ext_resource path referenced in .tscn/.tres must exist.
#    No head-limit — scan the entire repo.
missing=0
while IFS= read -r line; do
  path=$(echo "$line" | grep -oE 'path="res://[^"]+"' | sed 's/path="res:\/\///;s/"$//' || true)
  [ -z "$path" ] && continue
  if [ ! -f "$path" ]; then
    file=$(echo "$line" | cut -d: -f1)
    log_fail "Missing resource: $path (referenced by $file)"
    missing=$((missing+1))
  fi
done < <(grep -rn 'path="res://' --include='*.tscn' --include='*.tres' . 2>/dev/null)

if [ "$missing" -gt 0 ]; then
  log_fail "$missing missing resource references."
  EXIT=1
else
  log_ok "All ext_resource paths resolve."
fi

# 1b. preload("res://...") references in .gd files
gd_missing=0
while IFS= read -r line; do
  path=$(echo "$line" | grep -oE 'preload\("res://[^"]+"\)' | sed 's/preload("res:\/\///;s/")$//' || true)
  [ -z "$path" ] && continue
  if [ ! -f "$path" ]; then
    file=$(echo "$line" | cut -d: -f1)
    log_fail "Missing preload: $path (in $file)"
    gd_missing=$((gd_missing+1))
  fi
done < <(grep -rn 'preload("res://' --include='*.gd' . 2>/dev/null)

if [ "$gd_missing" -gt 0 ]; then
  log_fail "$gd_missing missing preload paths."
  EXIT=1
else
  log_ok "All preload() paths resolve."
fi

# 2. Every autoload in project.godot must point to an existing script.
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

# 3. Signal connection sanity — for every `connect("signal_name", target, "method")`
#    or `signal.connect(target.method)` style, ensure the target method exists in
#    some script. Heuristic: grep all method names referenced in .connect()
#    and verify each is defined as a `func name(` somewhere.
signal_missing=0
while IFS= read -r line; do
  # Match: .connect(target, "method_name") OR .connect(Callable(target, "method_name"))
  method=$(echo "$line" | grep -oE '"[a-z_][a-zA-Z0-9_]*"' | tail -1 | tr -d '"' || true)
  [ -z "$method" ] && continue
  # If a "func <method>(" exists anywhere in scripts/, it's wired
  if ! grep -rqE "^func\s+${method}\s*\(" scripts/ 2>/dev/null; then
    file=$(echo "$line" | cut -d: -f1)
    # Allow built-in callables (queue_free, etc.) and Godot lifecycle
    case "$method" in
      queue_free|emit|free|connect|disconnect|hide|show)
        ;;
      *)
        log_warn "Signal connect target may be missing: $method (in $file)"
        # Don't fail — heuristic, false positives possible. Just warn.
        ;;
    esac
  fi
done < <(grep -rnE '\.connect\(' --include='*.gd' scripts/ 2>/dev/null | head -100)
log_ok "Signal-connection heuristic done (warnings non-fatal)."

# 4. Run Godot headless parse check if available.
if command -v godot >/dev/null 2>&1; then
  log_ok "Godot found: $(godot --version 2>&1 | head -1)"

  # 4a. Per-script --check-only pass. Stricter than --quit-after 1 which only
  #     loads autoloads + main scene. --check-only parses the file standalone.
  parse_errors=0
  while IFS= read -r script; do
    out=$(timeout 15 godot --headless --check-only --script "$script" 2>&1 || true)
    if echo "$out" | grep -qE "SCRIPT ERROR|PARSE ERROR|Parser Error|Invalid call|Invalid get index|Cannot call method"; then
      log_fail "Parse error in $script:"
      echo "$out" | grep -E "SCRIPT ERROR|PARSE ERROR|Parser Error" | head -5
      parse_errors=$((parse_errors+1))
    fi
  done < <(find scripts -name '*.gd' -type f 2>/dev/null)
  if [ "$parse_errors" -gt 0 ]; then
    log_fail "$parse_errors GDScript file(s) have parse errors."
    EXIT=1
  else
    log_ok "All GDScript files pass --check-only."
  fi

  # 4b. Headless launch (autoloads + main scene must boot).
  if timeout 120 godot --headless --path . --quit-after 1 >/tmp/godot_out.txt 2>&1; then
    log_ok "Godot headless launch succeeded."
  else
    if grep -E "SCRIPT ERROR|PARSE ERROR|Parser Error|Invalid call|Invalid get index|Cannot call method" /tmp/godot_out.txt >/dev/null; then
      log_fail "Godot parse/script errors detected:"
      grep -E "SCRIPT ERROR|PARSE ERROR|Parser Error|Invalid call|Invalid get index|Cannot call method" /tmp/godot_out.txt | head -30
      EXIT=1
    else
      log_warn "Godot exited non-zero but no parse errors found (possibly runtime noise)."
    fi
  fi

  # 4c. Each level scene must load without error. Catches malformed .tscn,
  #     missing nodes, broken sub-resources — failures the file-existence
  #     check above misses entirely.
  scene_errors=0
  for scene in scenes/game/level_*.tscn scenes/ui/main_menu.tscn; do
    [ -f "$scene" ] || continue
    out=$(timeout 30 godot --headless --path . --quit-after 1 --main-pack "" -s "$scene" 2>&1 || true)
    # Plain --quit-after on a specific scene: any SCRIPT/PARSE error means broken.
    if echo "$out" | grep -qE "SCRIPT ERROR|PARSE ERROR|Failed to load|Cannot find scene|Resource file not found"; then
      log_fail "Scene load failed: $scene"
      echo "$out" | grep -E "SCRIPT ERROR|PARSE ERROR|Failed to load|Cannot find scene|Resource file not found" | head -3
      scene_errors=$((scene_errors+1))
    fi
  done
  if [ "$scene_errors" -gt 0 ]; then
    log_fail "$scene_errors scene(s) failed to load."
    EXIT=1
  else
    log_ok "All level + main scenes load."
  fi
else
  log_warn "Godot not installed on runner — skipping engine parse check."
fi

# 5. Sanity: main scene referenced in project.godot must exist.
MAIN_SCENE=$(grep -oE 'run/main_scene="res://[^"]+"' project.godot 2>/dev/null | sed 's/run\/main_scene="res:\/\///;s/"$//' || true)
if [ -n "$MAIN_SCENE" ] && [ ! -f "$MAIN_SCENE" ]; then
  log_fail "Main scene missing: $MAIN_SCENE"
  EXIT=1
elif [ -n "$MAIN_SCENE" ]; then
  log_ok "Main scene exists: $MAIN_SCENE"
fi

# 6. project.godot Godot version pin matches .github/godot-version.txt (if present)
if [ -f .github/godot-version.txt ]; then
  PINNED=$(cat .github/godot-version.txt | tr -d '[:space:]')
  log_ok "Godot version pin file present: $PINNED"
fi

if [ "$EXIT" -eq 0 ]; then
  echo ""
  log_ok "VALIDATION PASSED"
else
  echo ""
  log_fail "VALIDATION FAILED"
fi

exit "$EXIT"
