#!/usr/bin/env bash
# remove-lines.sh - Output first N lines of a file
# Usage: ./remove-lines.sh <file> <line-count>

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <file> <line-count>" >&2
  exit 1
fi

head -n "$2" "$1"
