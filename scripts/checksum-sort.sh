#!/usr/bin/env bash

# checksum-sort.sh - Sort and add checksums to filter files
# Usage: ./checksum-sort.sh [--keep-backup] <filter-file>

set -euo pipefail # Exit on error, undefined vars, and pipe failures

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly REQUIRED_PERL_MODULES=("Path::Tiny")
readonly BACKUP_DIR="$SCRIPT_DIR/backup"
readonly MAX_BACKUPS=10
TEMP_DIR=$(mktemp -d)
readonly TEMP_DIR

# Global variables to track backup file for cleanup
BACKUP_FILE_PATH=""
KEEP_BACKUP=false
PROCESSING_FILE=""

# Cleanup function
cleanup() {
  local exit_code=$?
  echo "🧹 Cleaning up temporary files..."
  [[ -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"

  # Clean up any temporary files left by sorter.pl
  if [[ -n "${PROCESSING_FILE:-}" ]]; then
    # Clean up new-style temporary files (.tmp.PID)
    local temp_pattern="$PROCESSING_FILE.tmp.*"
    # shellcheck disable=SC2066
    for temp_file in "$temp_pattern"; do
      if [[ -f "$temp_file" ]]; then
        echo "🗑️  Removing temporary sorter file: $temp_file"
        rm -f "$temp_file" || echo "⚠️  Warning: Failed to remove temporary file $temp_file"
      fi
    done

    # Clean up legacy .out files (for backward compatibility)
    local out_file="$PROCESSING_FILE.out"
    if [[ -f "$out_file" ]]; then
      echo "🗑️  Removing legacy temporary file: $out_file"
      rm -f "$out_file" || echo "⚠️  Warning: Failed to remove temporary file $out_file"
    fi
  fi

  # Only clean CPAN cache if we installed modules in this session
  if [[ "${INSTALLED_MODULES:-}" == "true" ]]; then
    echo "🧹 Cleaning CPAN cache..."
    rm -rf ~/.cpan ~/.perl 2>/dev/null || true
  fi

  # Remove backup file if script completed successfully (exit code 0) and --keep-backup not specified
  if [[ $exit_code -eq 0 && -n "$BACKUP_FILE_PATH" && -f "$BACKUP_FILE_PATH" && "$KEEP_BACKUP" == "false" ]]; then
    echo "🗑️  Removing backup file (successful completion): $BACKUP_FILE_PATH"
    rm -f "$BACKUP_FILE_PATH" || echo "⚠️  Warning: Failed to remove backup file"

    # Check if backup directory is empty and remove it if so
    if [[ -d "$BACKUP_DIR" ]]; then
      # Count files in backup directory (excluding . and ..)
      local file_count
      file_count=$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 | wc -l)
      if [[ $file_count -eq 0 ]]; then
        echo "🗑️  Removing empty backup directory: $BACKUP_DIR"
        rmdir "$BACKUP_DIR" 2>/dev/null || echo "⚠️  Warning: Failed to remove backup directory"
      fi
    fi
  elif [[ $exit_code -eq 0 && -n "$BACKUP_FILE_PATH" && -f "$BACKUP_FILE_PATH" && "$KEEP_BACKUP" == "true" ]]; then
    echo "💾 Keeping backup file as requested: $BACKUP_FILE_PATH"
  fi

  exit "$exit_code"
}

# Set up cleanup trap
trap cleanup EXIT INT TERM

# Logging functions
log_info() {
  echo "ℹ️  [INFO] $*" >&2
}

log_error() {
  echo "❌ [ERROR] $*" >&2
}

log_warning() {
  echo "⚠️  [WARNING] $*" >&2
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

# Check if Perl module is installed
check_perl_module() {
  local module="$1"
  perl -M"$module" -e 'exit 0' 2>/dev/null
}

# Install required Perl modules
install_perl_dependencies() {
  local needs_install=false

  for module in "${REQUIRED_PERL_MODULES[@]}"; do
    if ! check_perl_module "$module"; then
      log_info "Perl module '$module' not found, will install..."
      needs_install=true
    else
      log_info "Perl module '$module' already installed"
    fi
  done

  if [[ "$needs_install" == "true" ]]; then
    log_info "Installing required Perl modules..."

    # Use local::lib to avoid system-wide installation if possible
    if command -v cpanm >/dev/null 2>&1; then
      # Use cpanminus if available (faster and more reliable)
      cpanm --quiet --local-lib="$TEMP_DIR/perl5" "${REQUIRED_PERL_MODULES[@]}" || {
        log_error "Failed to install Perl modules with cpanminus"
        exit 1
      }
      export PERL5LIB="$TEMP_DIR/perl5/lib/perl5:${PERL5LIB:-}"
    else
      # Fallback to cpan
      cpan install "${REQUIRED_PERL_MODULES[@]}" || {
        log_error "Failed to install Perl modules with cpan"
        exit 1
      }
      INSTALLED_MODULES="true"
    fi

    log_info "Perl modules installed successfully"
  fi
}

# Validate Perl scripts exist and are executable
validate_perl_scripts() {
  local sorter_script="$SCRIPT_DIR/sorter.pl"
  local checksum_script="$SCRIPT_DIR/addChecksum.pl"

  for script in "$sorter_script" "$checksum_script"; do
    if [[ ! -f "$script" ]]; then
      log_error "Required script '$script' not found"
      exit 1
    fi

    if [[ ! -r "$script" ]]; then
      log_error "Script '$script' is not readable"
      exit 1
    fi
  done
}

# Get file checksum for integrity verification
get_file_checksum() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | cut -d' ' -f1
  else
    # Fallback to md5 if sha256 is not available
    if command -v md5sum >/dev/null 2>&1; then
      md5sum "$file" | cut -d' ' -f1
    elif command -v md5 >/dev/null 2>&1; then
      md5 -q "$file"
    else
      log_warning "No checksum utility found, skipping integrity verification"
      echo "no-checksum"
    fi
  fi
}

# Verify backup integrity
verify_backup_integrity() {
  local original_file="$1"
  local backup_file="$2"

  if [[ ! -f "$backup_file" ]]; then
    log_error "Backup file '$backup_file' does not exist"
    return 1
  fi

  local original_checksum backup_checksum
  original_checksum=$(get_file_checksum "$original_file")
  backup_checksum=$(get_file_checksum "$backup_file")

  if [[ "$original_checksum" != "no-checksum" && "$backup_checksum" != "no-checksum" ]]; then
    if [[ "$original_checksum" == "$backup_checksum" ]]; then
      log_info "Backup integrity verified"
      return 0
    else
      log_error "Backup integrity check failed - checksums don't match"
      return 1
    fi
  fi

  # Fallback to size comparison if checksums unavailable
  local original_size backup_size
  original_size=$(stat -f%z "$original_file" 2>/dev/null || stat -c%s "$original_file" 2>/dev/null)
  backup_size=$(stat -f%z "$backup_file" 2>/dev/null || stat -c%s "$backup_file" 2>/dev/null)

  if [[ "$original_size" == "$backup_size" ]]; then
    log_info "Backup size verification passed"
    return 0
  else
    log_error "Backup size verification failed"
    return 1
  fi
}

# Clean old backups to prevent disk space issues
cleanup_old_backups() {
  local file="$1"
  local backup_dir="$2"
  local filename
  filename=$(basename "$file")

  # Find and sort backup files by modification time (newest first)
  local backup_files backup_count

  # Use a more compatible approach for older bash versions
  if command -v mapfile >/dev/null 2>&1; then
    mapfile -t backup_files < <(find "$backup_dir" -name "$filename.backup.*" -type f -print0 | xargs -0 ls -t 2>/dev/null || true)
    backup_count=${#backup_files[@]}
  else
    # Fallback for systems without mapfile - use while read loop
    backup_files=()
    while IFS= read -r -d '' file; do
      backup_files+=("$file")
    done < <(find "$backup_dir" -name "$filename.backup.*" -type f -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null || true)
    backup_count=${#backup_files[@]}
  fi

  if [[ $backup_count -gt $MAX_BACKUPS ]]; then
    log_info "Found $backup_count backups, keeping only $MAX_BACKUPS most recent"

    # Remove old backups (keep only MAX_BACKUPS)
    for ((i = MAX_BACKUPS; i < backup_count; i++)); do
      local old_backup="${backup_files[i]}"
      log_info "Removing old backup: $old_backup"
      rm -f "$old_backup" || log_warning "Failed to remove old backup: $old_backup"
    done
  fi
}

# Create backup of original file with improved error handling and organization
create_backup() {
  local file="$1"
  local filename backup_file backup_dir

  filename=$(basename "$file")

  # Create backup directory if it doesn't exist
  backup_dir="$BACKUP_DIR"
  if [[ ! -d "$backup_dir" ]]; then
    log_info "Creating backup directory: $backup_dir"
    mkdir -p "$backup_dir" || {
      log_error "Failed to create backup directory '$backup_dir'"
      exit 1
    }
  fi

  # Generate backup filename with timestamp
  backup_file="$backup_dir/$filename.backup.$(date +%Y%m%d_%H%M%S)"

  log_info "Creating backup: $backup_file"

  # Create backup with error handling
  if ! cp "$file" "$backup_file"; then
    log_error "Failed to create backup of '$file'"
    exit 1
  fi

  # Verify backup integrity
  if ! verify_backup_integrity "$file" "$backup_file"; then
    log_error "Backup verification failed, removing corrupted backup"
    rm -f "$backup_file"
    exit 1
  fi

  # Set appropriate permissions on backup
  chmod 644 "$backup_file" 2>/dev/null || log_warning "Could not set permissions on backup file"

  # Clean up old backups
  cleanup_old_backups "$file" "$backup_dir"

  echo "$backup_file"
}

# Restore from backup with verification
restore_from_backup() {
  local original_file="$1"
  local backup_file="$2"

  log_info "Restoring from backup: $backup_file"

  if [[ ! -f "$backup_file" ]]; then
    log_error "Backup file '$backup_file' not found"
    return 1
  fi

  # Create a temporary copy for safety
  local temp_restore="$TEMP_DIR/restore_temp"
  if ! cp "$backup_file" "$temp_restore"; then
    log_error "Failed to create temporary restore file"
    return 1
  fi

  # Restore the file
  if ! cp "$temp_restore" "$original_file"; then
    log_error "Failed to restore file from backup"
    return 1
  fi

  log_info "Successfully restored '$original_file' from backup"
  return 0
}

# Process the filter file with improved error handling and rollback
process_file() {
  local file="$1"
  local backup_file
  local operation_failed=false

  log_info "🔄 Processing file: $file"

  # Set global processing file path for cleanup function
  PROCESSING_FILE="$file"

  # Create backup
  backup_file=$(create_backup "$file")

  # Set global backup file path for cleanup function
  BACKUP_FILE_PATH="$backup_file"

  # Sort the file
  log_info "🔀 Sorting filter entries..."
  if ! perl "$SCRIPT_DIR/sorter.pl" "$file"; then
    log_error "Failed to sort file '$file'"
    operation_failed=true
  fi

  # Add checksum only if sorting succeeded
  if [[ "$operation_failed" == "false" ]]; then
    log_info "🔐 Adding checksum..."
    if ! perl "$SCRIPT_DIR/addChecksum.pl" "$file"; then
      log_error "Failed to add checksum to file '$file'"
      operation_failed=true
    fi
  fi

  # Handle failure with proper rollback
  if [[ "$operation_failed" == "true" ]]; then
    if ! restore_from_backup "$file" "$backup_file"; then
      log_error "Critical error: Failed to restore from backup"
      log_error "Manual intervention required. Backup location: $backup_file"
      exit 1
    fi
    exit 1
  fi

  log_info "✅ Successfully processed '$file'"
  if [[ "$KEEP_BACKUP" == "true" ]]; then
    log_info "💾 Backup will be preserved as requested: $backup_file"
  else
    log_info "🗑️  Backup will be automatically removed on successful completion"
  fi
}

# List available backups for a file
list_backups() {
  local file="$1"
  local filename backup_dir

  filename=$(basename "$file")
  backup_dir="$BACKUP_DIR"

  if [[ ! -d "$backup_dir" ]]; then
    log_info "No backup directory found"
    return 0
  fi

  log_info "Available backups for '$filename':"
  find "$backup_dir" -name "$filename.backup.*" -type f -exec ls -lh {} \; 2>/dev/null | sort -k9 || {
    log_info "No backups found for '$filename'"
  }
}

# Remove all backups for a file
remove_all_backups() {
  local file="$1"
  local filename backup_dir

  filename=$(basename "$file")
  backup_dir="$BACKUP_DIR"

  if [[ ! -d "$backup_dir" ]]; then
    log_info "No backup directory found"
    return 0
  fi

  # Find all backup files for this filter
  local backup_files backup_count

  # Use a more compatible approach for older bash versions
  if command -v mapfile >/dev/null 2>&1; then
    mapfile -t backup_files < <(find "$backup_dir" -name "$filename.backup.*" -type f -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null || true)
    backup_count=${#backup_files[@]}
  else
    # Fallback for systems without mapfile - use while read loop
    backup_files=()
    while IFS= read -r -d '' file; do
      backup_files+=("$file")
    done < <(find "$backup_dir" -name "$filename.backup.*" -type f -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null || true)
    backup_count=${#backup_files[@]}
  fi

  if [[ $backup_count -eq 0 ]]; then
    log_info "No backups found for '$filename'"
    return 0
  fi

  log_info "Found $backup_count backup(s) for '$filename'"

  # Ask for confirmation
  echo "⚠️  This will permanently delete all $backup_count backup(s) for '$filename'."
  echo "Backups to be deleted:"
  for backup_file in "${backup_files[@]}"; do
    echo "  - $(basename "$backup_file")"
  done
  echo ""
  read -p "Are you sure you want to delete all these backups? (y/N): " -r

  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Operation cancelled by user"
    return 0
  fi

  # Remove all backup files
  local removed_count=0
  for backup_file in "${backup_files[@]}"; do
    if [[ -f "$backup_file" ]]; then
      log_info "Removing backup: $(basename "$backup_file")"
      if rm -f "$backup_file"; then
        ((removed_count++))
      else
        log_warning "Failed to remove backup: $backup_file"
      fi
    fi
  done

  log_info "Successfully removed $removed_count out of $backup_count backup(s)"

  # Check if backup directory is empty and remove it if so
  if [[ -d "$backup_dir" ]]; then
    local file_count
    file_count=$(find "$backup_dir" -mindepth 1 -maxdepth 1 | wc -l)
    if [[ $file_count -eq 0 ]]; then
      log_info "Removing empty backup directory: $backup_dir"
      rmdir "$backup_dir" 2>/dev/null || log_warning "Failed to remove backup directory"
    fi
  fi
}

# Main function
main() {
  local file=""

  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --keep-backup)
        KEEP_BACKUP=true
        shift
        ;;
      --list-backups)
        if [[ $# -lt 2 ]]; then
          log_error "Usage: $0 --list-backups <filter-file>"
          exit 1
        fi
        list_backups "$2"
        exit 0
        ;;
      --remove-all-backups)
        if [[ $# -lt 2 ]]; then
          log_error "Usage: $0 --remove-all-backups <filter-file>"
          exit 1
        fi
        remove_all_backups "$2"
        exit 0
        ;;
      --help | -h)
        echo "Usage: $0 [--keep-backup] <filter-file>"
        echo "       $0 --list-backups <filter-file>"
        echo "       $0 --remove-all-backups <filter-file>"
        echo ""
        echo "Options:"
        echo "  --keep-backup           Keep backup file after successful completion"
        echo "  --list-backups          List available backups for the specified file"
        echo "  --remove-all-backups    Remove all backups for the specified file"
        echo "  --help, -h              Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0 filters/combined-filters.txt"
        echo "  $0 --keep-backup filters/combined-filters.txt"
        echo "  $0 --list-backups filters/combined-filters.txt"
        echo "  $0 --remove-all-backups filters/combined-filters.txt"
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
    log_error "Usage: $0 [--keep-backup] <filter-file>"
    log_error "Use --help for more information"
    exit 1
  fi

  log_info "🚀 Starting checksum-sort process for: $file"

  # Validate input
  validate_input "$file"

  # Validate Perl scripts
  validate_perl_scripts

  # Install dependencies
  install_perl_dependencies

  # Process the file
  process_file "$file"

  if [[ "$KEEP_BACKUP" == "true" ]]; then
    log_info "✅ Done! '$file' has been sorted and checksums have been added."
    log_info "💾 Backup preserved as requested: $BACKUP_FILE_PATH"
  else
    log_info "✅ Done! '$file' has been sorted and checksums have been added."
    log_info "🗑️  Backup was automatically removed after successful completion."
  fi
  log_info "📋 Use '$0 --list-backups $file' to see available backups"
}

# Run main function with all arguments
main "$@"
