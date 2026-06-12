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

# Validate input arguments (enhanced)
validate_input() {
  # Resolve the provided argument to an absolute path.
  local arg="$1"
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local candidate=""

  # If the argument is an absolute path and points to a regular file, use it.
  if [[ "$arg" = /* && -f "$arg" ]]; then
    candidate="$arg"
  else
    # Try relative to current working directory.
    if [[ -f "$arg" ]]; then
      candidate="$arg"
    else
      # Try relative to the script's sibling "../filters" directory.
      local sibling="${script_dir}/../filters/${arg}"
      if [[ -f "$sibling" ]]; then
        candidate="$sibling"
      fi
    fi
  fi

  if [[ -z "$candidate" ]]; then
    log_error "File '$arg' does not exist or is not a regular file."
    log_error "Attempted paths:"
    log_error "  - Current directory: \$(pwd)/$arg"
    log_error "  - Relative sibling: ${script_dir}/../filters/${arg}"
    exit 1
  fi

  if [[ ! -r "$candidate" ]]; then
    log_error "File '$candidate' is not readable"
    exit 1
  fi

  if [[ ! -w "$candidate" ]]; then
    log_error "File '$candidate' is not writable"
    exit 1
  fi

  # Ensure the file is not empty (prevent accidental removal)
  if [[ ! -s "$candidate" ]]; then
    log_error "File '$candidate' is empty; nothing to process"
    exit 1
  fi

  # Export the resolved absolute path for later use.
  export RESOLVED_FILE="$candidate"
}

# Sort filter rules without creating stray temp files (uses mktemp then moves)
sort_filter() {
  local file="$1"
  # Create a temporary file safely; abort if creation fails
  local tmp
  tmp=$(mktemp "${file}.tmp.XXXX") || { log_error "Failed to create temporary file"; exit 1; }

  {
    # Preserve comment lines starting with '!'
    grep '^!' "$file"
    # Sort rule lines by hostname (field before first '#')
    grep -v '^!' "$file" | sort -t'#' -k1,1
  } > "$tmp"

  # Atomically replace the original file
  mv "$tmp" "$file"
  log_info "✅ Custom sorting completed successfully"
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
  local checksum

  # Calculate checksum after updating headers
  checksum=$(calculate_checksum "$file")

  # Insert checksum after Title line if present; otherwise prepend
  if grep -q '^! Title:' "$file"; then
    # Use sed to append the checksum line right after the Title line
    sed -i "/^! Title:/a ! Checksum: $checksum" "$file"
  else
    # No Title line; prepend checksum at the beginning of the file
    sed -i "1i ! Checksum: $checksum" "$file"
  fi

  log_info "📝 Checksum: $checksum"
}

# Run fop-rs after custom sort
run_fop() {
  local file="$1"
  local file_name
  file_name=$(basename "$file")
  local file_dir
  file_dir=$(dirname "$file")

  (
    # Change directory to the file's location so fop can locate the file correctly
    cd "$file_dir" || { log_error "Failed to change directory to $file_dir"; exit 1; }

    if command -v fop > /dev/null 2>&1; then
      fop --check-file="$file_name" --no-commit --no-sort
    else
      log_error "fop not found. Please install it first."
      log_error "You can install it via Homebrew:"
      log_error "  brew install laniksj/tap/fop-rs"
      log_error "Or using Cargo: cargo install fop-rs"
      exit 1
    fi
  )
  log_info "✅ fop-rs validation completed"
}

# Process the filter file
process_file() {
  local file="$1"

  log_info "🔄 Processing file: $file"

  # Step 1: Sort filter rules (before header updates)
  log_info "🔀 Sorting filter rules..."
  sort_filter "$file"
  # Run fop-rs validation after sorting
  log_info "🔀 Running fop-rs validation..."
  run_fop "$file"

  # Step 2: Update date and version headers
  log_info "📅 Updating date and version headers..."
  update_headers "$file"

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

  # Validate input and resolve absolute path
  validate_input "$file"
  file="$RESOLVED_FILE"

  # Process the file
  process_file "$file"

  log_info "✅ Done! '$file' has been sorted and checksums have been added."
}

# Run main function with all arguments
main "$@"
