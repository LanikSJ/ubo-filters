#!/usr/bin/env bash
# checksum-sort.sh - Sort and add checksums to filter files
# Usage: ./checksum-sort.sh [--fop-args="..."] <filter-file>

set -euo pipefail # Exit on error, undefined vars, and pipe failures

# Extra fop-rs arguments collected from --fop-args (see --help)
FOP_EXTRA_ARGS=()

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
      local sibling="$script_dir/../filters/$arg"
      if [[ -f "$sibling" ]]; then
        candidate="$sibling"
      fi
    fi
  fi

  if [[ -z "$candidate" ]]; then
    log_error "File '$arg' does not exist or is not a regular file."
    log_error "Attempted paths:"
    log_error "  - Current directory: \$(pwd)/$arg"
    log_error "  - Relative sibling: $script_dir/../filters/$arg"
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
  tmp=$(mktemp "$file.tmp.XXXX") || {
    log_error "Failed to create temporary file"
    exit 1
  }

  {
    # Preserve comment lines starting with '!'
    grep '^!' "$file" || true
    # Sort rule lines by hostname (field before first '#')
    if grep -q -v '^!' "$file"; then
      grep -v '^!' "$file" | sort -t'#' -k1,1
    fi
  } >"$tmp"

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
    elif [[ "$line" =~ ^'! Last '[Mm]'odified:' ]]; then
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

  local tmp
  tmp=$(mktemp "$file.tmp.XXXX") || {
    log_error "Failed to create temporary file for checksum"
    exit 1
  }

  local inserted=false
  while IFS= read -r line || [[ -n "$line" ]]; do
    echo "$line"
    if [[ "$line" =~ ^'! Title:' ]]; then
      echo "! Checksum: $checksum"
      inserted=true
    fi
  done <"$file" >"$tmp"

  if [[ "$inserted" == "false" ]]; then
    # No Title line; prepend checksum at the beginning of the file
    {
      echo "! Checksum: $checksum"
      cat "$file"
    } >"$tmp"
  fi

  mv "$tmp" "$file"
  log_info "📝 Checksum: $checksum"
}

# Run fop-rs after custom sort
run_fop() {
  local file="$1"
  local file_name
  file_name="$(basename "$file")"
  local file_dir
  file_dir="$(dirname "$file")"

  if ! command -v fop >/dev/null 2>&1; then
    log_error "fop not found. Please install it first."
    log_error "You can install it via Homebrew:"
    log_error "  brew install laniksj/tap/fop-rs"
    log_error "Or using Cargo: cargo install fop-rs"
    exit 1
  fi

  # Flags shared by both fop modes below. --auto-fix and --remove-bad-rules
  # are the fop-rs clean-up options; --remove-bad-rules judges lines added in
  # the git diff, which fop only does in repository mode (see below).
  # --no-large-warning keeps fop fully non-interactive so CI and pre-commit
  # runs can never hang on a prompt.
  local -a fop_args=(
    --no-commit
    --no-sort
    --no-large-warning
    --auto-fix
    --remove-bad-rules
  )

  # Extra arguments from --fop-args come last (e.g. --parse-adguard)
  if [[ ${#FOP_EXTRA_ARGS[@]} -gt 0 ]]; then
    fop_args+=("${FOP_EXTRA_ARGS[@]}")
  fi

  # fop emits ANSI colors even when piped; drop them off-terminal
  if [[ ! -t 1 ]]; then
    fop_args+=(--no-color)
  fi

  # Repository root for the file, if it is inside one
  local git_root=""
  if command -v git >/dev/null 2>&1; then
    git_root="$(git -C "$file_dir" rev-parse --show-toplevel 2>/dev/null || true)"
  fi

  local abs_dir=""
  local root_abs=""
  if [[ -n "$git_root" ]]; then
    abs_dir="$(cd "$file_dir" 2>/dev/null && pwd -P)" || abs_dir=""
    root_abs="$(cd "$git_root" 2>/dev/null && pwd -P)" || root_abs=""
  fi

  # Repository mode needs fop pointed at the repository root, because that is
  # where fop looks for .git before running the --remove-bad-rules rule
  # checks. fop's directory walk skips dot-files and dot-directories and
  # refuses symlinks, so those targets fall back to --check-file mode, where
  # the git-based rule checks cannot run at all.
  local rel_dir="${abs_dir#"$root_abs"}"
  local repo_mode=false
  if [[ -n "$git_root" && -n "$abs_dir" && ! -L "$file" ]] &&
    [[ "$file_name" != .* && "${root_abs##*/}" != .* &&
      "$rel_dir" != *"/."* ]]; then
    repo_mode=true
  fi

  if [[ "$repo_mode" == "true" ]]; then
    # --ignore-all-but matches the file NAME as a substring, so a sibling
    # like getadmiral-domains.txt would match admiral-domains.txt too.
    # Collect those colliders and exclude them via --ignorefiles so only the
    # requested file is processed and rule-checked. An empty --ignorefiles=
    # makes fop ignore every file, so it is only passed when a collider
    # actually exists.
    local -a colliders=()
    local candidate=""
    local base=""
    while IFS= read -r -d '' candidate; do
      base="${candidate##*/}"
      if [[ "$base" == *"$file_name"* && "$base" != "$file_name" ]]; then
        colliders+=("$base")
      fi
    done < <(find "$root_abs" -mindepth 1 \
      \( -type d -name '.*' -prune \) -o \( -type f -print0 \) 2>/dev/null)

    local -a mode_args=(--limited-quiet "--ignore-all-but=$file_name")
    if [[ ${#colliders[@]} -gt 0 ]]; then
      local joined=""
      joined="$(
        IFS=,
        printf '%s' "${colliders[*]}"
      )"
      mode_args+=("--ignorefiles=$joined")
      log_info "Sibling files excluded from processing: $joined"
    fi

    log_info "🧪 fop-rs repository mode (git rule checks active)"
    (
      # Change to the repository root so fop finds .git and reads the repo
      # .fopconfig, matching how maintainers run fop by hand
      cd "$root_abs" || {
        log_error "Failed to change directory to $root_abs"
        exit 1
      }
      fop "${fop_args[@]}" "${mode_args[@]}" .
    )
  else
    if [[ -z "$git_root" ]]; then
      log_warning "No git repository found for '$file'; using fop single-file mode."
      log_warning "The --remove-bad-rules rule checks need a repository and are skipped."
    else
      log_info "Target is a symlink or dot-path; using fop single-file mode."
    fi
    (
      # Change directory to the file's location so fop can locate the file correctly
      cd "$file_dir" || {
        log_error "Failed to change directory to $file_dir"
        exit 1
      }
      fop --check-file="$file_name" "${fop_args[@]}"
    )
  fi
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
  local fop_args_raw=""

  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --help | -h)
        echo "Usage: $0 [options] <filter-file>"
        echo ""
        echo "Options:"
        echo "  --help, -h              Show this help message"
        echo "  --fop-args=\"...\"        Extra arguments passed through to fop-rs"
        echo ""
        echo "fop-rs runs with --no-commit --no-sort --no-large-warning"
        echo "--auto-fix --remove-bad-rules. Inside a git repository fop is pointed"
        echo "at the repository root and limited to this file, so the"
        echo "--remove-bad-rules checks against the git diff are active. Outside a"
        echo "repository fop falls back to --check-file single-file mode and the"
        echo "rule checks are skipped."
        echo ""
        echo "Examples:"
        echo "  $0 <filter-file>"
        echo "  $0 --fop-args=\"--parse-adguard\" <filter-file>"
        exit 0
        ;;
      --fop-args=*)
        fop_args_raw="${fop_args_raw:+$fop_args_raw }${1#*=}"
        shift
        ;;
      --fop-args)
        if [[ $# -lt 2 ]]; then
          log_error "--fop-args requires a value (e.g. --fop-args=\"--quiet\")"
          exit 1
        fi
        fop_args_raw="${fop_args_raw:+$fop_args_raw }$2"
        shift 2
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

  # Split extra fop arguments on whitespace
  if [[ -n "$fop_args_raw" ]]; then
    read -r -a FOP_EXTRA_ARGS <<<"$fop_args_raw"
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
