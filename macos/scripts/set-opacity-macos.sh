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
"$NODE" "$SCRIPT_DIR/set-opacity-macos.mjs" "$THEME_PATH" "$value"
