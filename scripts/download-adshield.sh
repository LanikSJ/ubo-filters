#!/usr/bin/env bash
# download-adshield.sh - Download and update the AdShield domains filter list
# Usage: ./download-adshield.sh <filter-file>
#
# Downloads the AdShield list from the primary GitHub source, falling back
# to the GitLab mirror if the primary source fails. Preserves the header
# (first 15 lines) of the existing filter file and appends new domains.

set -euo pipefail

log_info() {
  echo "ℹ️  $*"
}

log_error() {
  echo "❌  $*" >&2
}

log_warning() {
  echo "⚠️  $*" >&2
}

# Primary and fallback sources for the AdShield list
GITHUB_SOURCE="https://raw.githubusercontent.com/hagezi/dns-blocklists/refs/heads/main/share/ad-shield.txt"
GITLAB_MIRROR="https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/share/ad-shield.txt"

# Number of header lines to preserve from the existing filter file
HEADER_LINES=15

# Unique prefix matching custom rules that must be preserved across updates.
# These rules are hand-added (not part of the upstream list) and must be
# retained when the filter file is regenerated from the source. A fixed
# string (grep -F) is used since the upstream '$third-party' rules never
# contain this prefix.
PRESERVE_PREFIX='||*/session/obe*'

main() {
  local filter_file=""
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --help | -h)
        echo "Usage: $0 <filter-file>"
        echo ""
        echo "Options:"
        echo "  --help, -h              Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0 filters/adshield-domains.txt"
        exit 0
        ;;
      -*)
        log_error "Unknown option: $1"
        log_error "Use --help for usage information"
        exit 1
        ;;
      *)
        if [[ -z "$filter_file" ]]; then
          filter_file="$1"
        else
          log_error "Multiple files specified. Only one file can be processed at a time."
          exit 1
        fi
        shift
        ;;
    esac
  done

  # Check if file was provided
  if [[ -z "$filter_file" ]]; then
    log_error "Usage: $0 <filter-file>"
    log_error "Use --help for more information"
    exit 1
  fi

  # Resolve the filter file path (relative to script dir or current dir)
  local resolved_file=""
  if [[ -f "$filter_file" ]]; then
    resolved_file="$filter_file"
  elif [[ -f "$script_dir/../$filter_file" ]]; then
    resolved_file="$script_dir/../$filter_file"
  else
    log_error "File '$filter_file' does not exist."
    log_error "Attempted paths:"
    log_error "  - Current directory: $PWD/$filter_file"
    log_error "  - Relative sibling: $script_dir/../$filter_file"
    exit 1
  fi

  echo "🚀 Downloading AdShield list for: $resolved_file"

  # Extract custom rules that must be preserved across updates (e.g.
  # ||*/session/obe*...*$document rules which are not part of the
  # upstream list). These are re-appended after the downloaded content.
  local tmp_file="${resolved_file}.tmp"
  local preserved_file
  preserved_file="$(mktemp)"
  grep -F "$PRESERVE_PREFIX" "$resolved_file" >"$preserved_file" || true

  # Preserve header (first N lines) and append new domains
  "$script_dir/remove-lines.sh" "$resolved_file" "$HEADER_LINES" >"$tmp_file"

  # Try GitHub primary source, fall back to GitLab mirror on failure
  # (-s silences curl's own error output; the script logs its own messages)
  local source_file
  source_file=$(mktemp)
  if curl -fsL --fail "$GITHUB_SOURCE" -o "$source_file"; then
    log_info "Downloaded AdShield list from GitHub"
  else
    log_warning "GitHub source failed, falling back to GitLab mirror..."
    if ! curl -fsL --fail "$GITLAB_MIRROR" -o "$source_file"; then
      log_error "Both GitHub and GitLab sources failed."
      rm -f "$source_file" "$tmp_file"
      exit 1
    fi
    log_info "Downloaded AdShield list from GitLab mirror"
  fi

  # Transform domains to uBO filter rules and append
  # (escaped '$' in double quotes so shellcheck doesn't flag the
  #  intentional literal '$third-party' for sed)
  local sed_expr="s/^/||/; s/\$/^\$third-party/"
  sed "$sed_expr" "$source_file" >>"$tmp_file"

  # Re-append the custom rules that must be preserved across updates
  if [[ -s "$preserved_file" ]]; then
    cat "$preserved_file" >>"$tmp_file"
  fi

  # Clean up and atomically replace the original file
  rm -f "$source_file" "$preserved_file"
  mv -f "$tmp_file" "$resolved_file"

  echo "✅ Successfully updated '$resolved_file'"
}

main "$@"
