#!/usr/bin/env bash

set -euo pipefail

log_info() {
  echo "ℹ️ $*"
}

log_error() {
  echo "❌ $*" >&2
}

main() {
  local target_dir="$HOME/.local/bin"
  local latest_tag=""
  local i
  mkdir -p "$target_dir"

  log_info "Resolving latest fop-rs release..."
  for i in {1..5}; do
    if latest_tag=$(curl -fS -L --connect-timeout 20 https://github.com/ryanbr/fop-rs/releases/latest -o /dev/null -w "%{url_effective}" | awk -F/ '{print $NF}'); then
      if [ -n "$latest_tag" ]; then
        break
      fi
    fi
    log_info "Failed to get latest release tag (attempt $i/5), retrying in 10 seconds..."
    sleep 10
  done

  if [ -z "$latest_tag" ]; then
    log_error "Could not retrieve latest release tag."
    exit 1
  fi

  local version="${latest_tag#v}"
  log_info "Downloading fop-rs version $latest_tag..."

  for i in {1..5}; do
    if curl -fS -L --connect-timeout 20 "https://github.com/ryanbr/fop-rs/releases/download/$latest_tag/fop-$version-linux-x86_64" -o "$target_dir/fop"; then
      chmod +x "$target_dir/fop"
      log_info "Successfully installed fop-rs to $target_dir/fop"

      # If running in GitHub Actions, add target_dir to GITHUB_PATH
      if [ -n "${GITHUB_PATH:-}" ]; then
        echo "$target_dir" >>"$GITHUB_PATH"
        log_info "Added $target_dir to GITHUB_PATH"
      fi
      exit 0
    fi
    log_info "Download failed (attempt $i/5), retrying in 10 seconds..."
    sleep 10
  done

  log_error "Failed to download fop-rs after 5 attempts."
  exit 1
}

main "$@"
