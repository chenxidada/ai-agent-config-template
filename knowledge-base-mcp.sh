#!/usr/bin/env bash

set -euo pipefail

KB_API_URL="${KB_API_URL:-http://localhost:4000/api/v1}"

detect_knownbase_root() {
  local candidates=()
  local script_dir

  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  if [[ -n "${KNOWNBASE_ROOT:-}" ]]; then
    candidates+=("${KNOWNBASE_ROOT}")
  fi

  candidates+=(
    "/Volumes/HP/workspace/code/knownbase/AI-Chat"
    "$script_dir/../knownbase/AI-Chat"
    "$script_dir/knownbase/AI-Chat"
    "$HOME/workspace/code/knownbase/AI-Chat"
    "$HOME/code/knownbase/AI-Chat"
    "$PWD/../knownbase/AI-Chat"
    "$PWD/knownbase/AI-Chat"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate/packages/mcp-server/dist/index.js" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

KNOWNBASE_ROOT_RESOLVED="$(detect_knownbase_root || true)"

if [[ -z "$KNOWNBASE_ROOT_RESOLVED" ]]; then
  echo "[knowledge-base-mcp] Could not locate Knownbase root." >&2
  echo "Set KNOWNBASE_ROOT to your AI-Chat project root, for example:" >&2
  echo "  export KNOWNBASE_ROOT=/path/to/knownbase/AI-Chat" >&2
  exit 1
fi

export KB_API_URL
exec node "$KNOWNBASE_ROOT_RESOLVED/packages/mcp-server/dist/index.js"
