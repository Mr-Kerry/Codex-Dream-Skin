#!/bin/bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
. "$SCRIPT_DIR/common-macos.sh"
ensure_node_runtime
THEME_PATH="$THEME_DIR/theme.json"
value=""
for candidate in "$@"; do
  case "$candidate" in
    ''|*[!0-9]*) ;;
    *) value="$candidate" ;;
  esac
done
[ -n "$value" ] || exit 2
ensure_state_root
[ -f "$THEME_PATH" ] || fail "Active theme metadata is missing."
acquire_theme_write_lock || fail "Timed out waiting to update theme opacity."
trap release_theme_write_lock EXIT
"$NODE" "$SCRIPT_DIR/set-opacity-macos.mjs" "$THEME_PATH" "$value"
