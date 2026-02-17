#!/usr/bin/env bash
# checksum-sort.sh - Sort and add checksums to filter files
# Usage: ./checksum-sort.sh <filter-file>

set -euo pipefail # Exit on error, undefined vars, and pipe failures

# Logging functions
log_info() {
  echo "$*" >&2
}

log_error() {
  echo "❌ $*" >&2
}

log_warning() {
  echo "⚠️ $*" >&2
}

# Validate input arguments
validate_input() {
  if [[ $# -eq 0 ]]; then
    log_error "Usage: $0 <filter-file>"
    log_error "Example: $0 filters/combined-filters.txt"
    exit 1
  fi

  local file="$1"

  if [[ ! -f "$file" ]]; then
    log_error "File '$file' does not exist or is not a regular file"
    exit 1
  fi

  if [[ ! -r "$file" ]]; then
    log_error "File '$file' is not readable"
    exit 1
  fi

  if [[ ! -w "$file" ]]; then
    log_error "File '$file' is not writable"
    exit 1
  fi
}

# Calculate checksum (MD5 base64, excluding checksum line itself)
calculate_checksum() {
  local file="$1"
  # Remove existing checksum line and calculate MD5, then encode as base64
  grep -v '^! Checksum:' "$file" | md5sum | cut -d' ' -f1 | xxd -r -p | base64 | tr -d '=' | tr '+/' '-_'
}

# Get current timestamp in various formats
get_timestamp() {
  local format="$1"
  case "$format" in
    "datetime")
      date -u +"%Y-%m-%d %H:%M UTC"
      ;;
    "version")
      date -u +"%Y%m%d%H%M"
      ;;
    *)
      date -u +"%Y-%m-%d %H:%M UTC"
      ;;
  esac
}

# Update date and version headers, and add checksum after Title
update_headers() {
  local file="$1"
  local temp_file="$file.tmp.$$"
  local datetime version checksum

  datetime=$(get_timestamp "datetime")
  version=$(get_timestamp "version")

  # Calculate checksum after we process everything
  local found_last_modified=false
  local found_version=false

  # First pass: find the title line and update headers
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^'! Title:' ]]; then
      echo "$line"
    elif [[ "$line" =~ ^'! Checksum:' ]]; then
      # Skip old checksum line - will be recalculated and added after title
      continue
    elif [[ "$line" =~ ^'! Last modified:' ]]; then
      echo "! Last modified: $datetime"
      found_last_modified=true
    elif [[ "$line" =~ ^'! Version:' ]]; then
      echo "! Version: $version"
      found_version=true
    else
      echo "$line"
    fi
  done <"$file" >"$temp_file"

  # If Last modified or Version headers weren't found, add them after Title/Checksum
  if [[ "$found_last_modified" == "false" ]] || [[ "$found_version" == "false" ]]; then
    local temp_file2="$file.tmp2.$$"

    while IFS= read -r line || [[ -n "$line" ]]; do
      echo "$line"
      # After Title line, add Checksum (placeholder), then missing headers
      if [[ "$line" =~ ^'! Title:' ]]; then
        # Checksum will be added in next pass
        if [[ "$found_last_modified" == "false" ]]; then
          echo "! Last modified: $datetime"
        fi
        if [[ "$found_version" == "false" ]]; then
          echo "! Version: $version"
        fi
      fi
    done <"$temp_file" >"$temp_file2"

    mv "$temp_file2" "$temp_file"
  fi

  mv "$temp_file" "$file"
}

# Add checksum after the Title line
add_checksum() {
  local file="$1"
  local checksum temp_file

  # Calculate checksum after updating headers
  checksum=$(calculate_checksum "$file")
  temp_file="$file.tmp.$$"

  # Find Title line and insert Checksum right after it
  local title_found=false
  while IFS= read -r line || [[ -n "$line" ]]; do
    echo "$line"
    if [[ "$line" =~ ^'! Title:' ]]; then
      # Insert Checksum right after Title
      echo "! Checksum: $checksum"
      title_found=true
    fi
  done <"$file" >"$temp_file"

  # If no Title line was found, prepend checksum
  if [[ "$title_found" == "false" ]]; then
    echo "! Checksum: $checksum" >"$temp_file"
    cat "$file" >>"$temp_file"
  fi

  mv "$temp_file" "$file"

  log_info "📝 Checksum: $checksum"
}

# Sort the filter file using FOP CLI
sort_filter() {
  local file="$1"

  log_info "🔀 Using FOP CLI to sort filter rules..."

  # Use the Rust-based FOP CLI (required)
  if command -v fop >/dev/null 2>&1; then
    log_info "🔀 Using Rust-based FOP CLI"
    if fop "$file" >/dev/null 2>&1; then
      log_info "✅ FOP CLI sorting completed successfully"
      return
    else
      log_error "❌ FOP CLI encountered errors while processing the file"
      log_error "❌ Please check the FOP CLI installation and try again"
      exit 1
    fi
  elif command -v fop-cli >/dev/null 2>&1; then
    log_info "🔀 Using FOP CLI (fop-cli)"
    if fozp-cli "$file" >/dev/null 2>&1; then
      log_info "✅ FOP CLI sorting completed successfully"
      return
    else
      log_error "❌ FOP CLI encountered errors while processing the file"
      log_error "❌ Please check the FOP CLI installation and try again"
      exit 1
    fi
  else
    log_error "❌ FOP CLI not found"
    log_error "❌ Please install the Rust-based FOP CLI from https://github.com/ryanbr/fop-rs"
    log_error "❌ This script requires FOP CLI and will not fall back to other sorting methods"
    exit 1
  fi
}

# Process the filter file
process_file() {
  local file="$1"

  log_info "🔄 Processing file: $file"

  # Step 1: Update date and version headers
  log_info "📅 Updating date and version headers..."
  update_headers "$file"

  # Step 2: Sort filter rules
  log_info "🔀 Sorting filter rules..."
  sort_filter "$file"

  # Step 3: Add checksum after Title
  log_info "🔐 Calculating and adding checksum..."
  add_checksum "$file"

  log_info "✅ Successfully processed '$file'"
}

# Main function
main() {
  local file=""

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
        echo "  $0 filters/combined-filters.txt"
        exit 0
        ;;
      -*)
        log_error "Unknown option: $1"
        log_error "Use --help for usage information"
        exit 1
        ;;
      *)
        if [[ -z "$file" ]]; then
          file="$1"
        else
          log_error "Multiple files specified. Only one file can be processed at a time."
          exit 1
        fi
        shift
        ;;
    esac
  done

  # Check if file was provided
  if [[ -z "$file" ]]; then
    log_error "Usage: $0 <filter-file>"
    log_error "Use --help for more information"
    exit 1
  fi

  log_info "🚀 Starting checksum-sort process for: $file"

  # Validate input
  validate_input "$file"

  # Process the file
  process_file "$file"

  log_info "✅ Done! '$file' has been sorted and checksums have been added."
}

# Run main function with all arguments
main "$@"
