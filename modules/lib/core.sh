#!/bin/bash

# Claude Universal Installer - Core Utilities Module
# This module contains common functions, error handling, and utilities

set -euo pipefail

# Color definitions for output formatting
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Global variables
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly CONFIG_DIR="${CONFIG_DIR:-$HOME/.claude-universal}"
readonly LOG_FILE="${CONFIG_DIR}/install.log"

# Logging functions
log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[INFO]${NC} $message"
    echo "[$timestamp] [INFO] $message" >> "$LOG_FILE" 2>/dev/null || true
}

warn() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[WARN]${NC} $message"
    echo "[$timestamp] [WARN] $message" >> "$LOG_FILE" 2>/dev/null || true
}

error() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[ERROR]${NC} $message" >&2
    echo "[$timestamp] [ERROR] $message" >> "$LOG_FILE" 2>/dev/null || true
}

success() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[SUCCESS]${NC} $message"
    echo "[$timestamp] [SUCCESS] $message" >> "$LOG_FILE" 2>/dev/null || true
}

header() {
    local title="$1"
    echo -e "${BLUE}=== $title ===${NC}"
    echo "=== $title ===" >> "$LOG_FILE" 2>/dev/null || true
}

# Error handling and cleanup
cleanup_on_exit() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        error "Script exited with error code $exit_code"
        error "Check log file for details: $LOG_FILE"
    fi
    # Cleanup temporary files
    cleanup_temp_files
}

cleanup_temp_files() {
    if [[ -n "${TEMP_FILES:-}" ]]; then
        for temp_file in $TEMP_FILES; do
            if [[ -f "$temp_file" ]]; then
                rm -f "$temp_file" || warn "Failed to remove temp file: $temp_file"
            fi
        done
    fi
}

# Trap cleanup
trap cleanup_on_exit EXIT
trap 'exit 130' INT

# Input validation
validate_input() {
    local input="$1"
    local pattern="$2"
    local field_name="$3"

    if [[ ! "$input" =~ $pattern ]]; then
        error "Invalid $field_name: $input"
        return 1
    fi
}

validate_url() {
    local url="$1"
    local field_name="${2:-URL}"

    if [[ ! "$url" =~ ^https?:// ]]; then
        error "Invalid $field_name: must start with http:// or https://"
        return 1
    fi
}

validate_nonempty() {
    local value="$1"
    local field_name="$2"

    if [[ -z "$value" ]]; then
        error "$field_name cannot be empty"
        return 1
    fi
}

# Safe file operations
safe_mkdir() {
    local dir_path="$1"
    if [[ ! -d "$dir_path" ]]; then
        mkdir -p "$dir_path" || {
            error "Failed to create directory: $dir_path"
            return 1
        }
        log "Created directory: $dir_path"
    fi
}

safe_write_file() {
    local file_path="$1"
    local content="$2"
    local description="${3:-file}"

    # Create directory if needed
    local dir_path
    dir_path="$(dirname "$file_path")"
    safe_mkdir "$dir_path"

    # Write file with error handling
    if echo "$content" > "$file_path"; then
        log "Created $description: $file_path"
    else
        error "Failed to create $description: $file_path"
        return 1
    fi
}

# Network operations with retry
download_with_retry() {
    local url="$1"
    local output="$2"
    local max_attempts="${3:-3}"
    local description="${4:-file}"

    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        log "Downloading $description (attempt $attempt/$max_attempts): $url"

        if curl -fsSL --connect-timeout 10 --max-time 300 "$url" -o "$output"; then
            success "Downloaded $description"
            return 0
        else
            warn "Download failed (attempt $attempt/$max_attempts)"
            if [[ $attempt -lt $max_attempts ]]; then
                sleep $((attempt * 2))
            fi
        fi

        ((attempt++))
    done

    error "Failed to download $description after $max_attempts attempts"
    return 1
}

# Checksum validation
validate_checksum() {
    local file_path="$1"
    local expected_checksum="$2"
    local algorithm="${3:-sha256}"

    if [[ -z "$expected_checksum" ]]; then
        warn "No checksum provided for validation"
        return 0
    fi

    if [[ ! -f "$file_path" ]]; then
        error "File not found for checksum validation: $file_path"
        return 1
    fi

    local actual_checksum
    case "$algorithm" in
        sha256)
            actual_checksum=$(shasum -a 256 "$file_path" | cut -d' ' -f1)
            ;;
        sha1)
            actual_checksum=$(shasum -a 1 "$file_path" | cut -d' ' -f1)
            ;;
        md5)
            actual_checksum=$(md5 -q "$file_path" 2>/dev/null || md5sum "$file_path" | cut -d' ' -f1)
            ;;
        *)
            error "Unsupported checksum algorithm: $algorithm"
            return 1
            ;;
    esac

    if [[ "$actual_checksum" == "$expected_checksum" ]]; then
        success "Checksum validation passed"
        return 0
    else
        error "Checksum validation failed"
        error "Expected: $expected_checksum"
        error "Actual:   $actual_checksum"
        return 1
    fi
}

# System detection
detect_os() {
    case "$(uname -s)" in
        Darwin*)
            echo "macos"
            ;;
        Linux*)
            echo "linux"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            echo "windows"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)
            echo "x64"
            ;;
        arm64|aarch64)
            echo "arm64"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Progress indication
show_progress() {
    local current="$1"
    local total="$2"
    local description="${3:-Processing}"

    local percentage=$((current * 100 / total))
    local filled=$((percentage / 2))
    local empty=$((50 - filled))

    printf "\r${CYAN}[%s%s]${NC} %d%% - %s" \
        "$(printf "%*s" $filled | tr ' ' '=')" \
        "$(printf "%*s" $empty | tr ' ' '-')" \
        "$percentage" \
        "$description"

    if [[ $current -eq $total ]]; then
        echo
    fi
}

# Secure temporary file creation
create_temp_file() {
    local prefix="${1:-claude-installer}"
    local temp_file
    temp_file=$(mktemp -t "${prefix}.XXXXXXXXXX") || {
        error "Failed to create temporary file"
        return 1
    }

    # Track for cleanup
    TEMP_FILES="${TEMP_FILES:-} $temp_file"
    echo "$temp_file"
}

# Configuration management helpers
load_config() {
    local config_file="$1"

    if [[ ! -f "$config_file" ]]; then
        warn "Configuration file not found: $config_file"
        return 1
    fi

    # Source configuration with safety checks
    if [[ -r "$config_file" ]]; then
        source "$config_file" || {
            error "Failed to load configuration: $config_file"
            return 1
        }
        log "Loaded configuration: $config_file"
    else
        error "Configuration file is not readable: $config_file"
        return 1
    fi
}

# Version comparison
version_compare() {
    local version1="$1"
    local version2="$2"

    # Simple version comparison (works for semantic versions)
    if [[ "$version1" == "$version2" ]]; then
        echo "equal"
    elif [[ "$(printf '%s\n' "$version1" "$version2" | sort -V | head -n1)" == "$version1" ]]; then
        echo "older"
    else
        echo "newer"
    fi
}

# Export functions for use in other modules
export -f log warn error success header
export -f cleanup_on_exit cleanup_temp_files
export -f validate_input validate_url validate_nonempty
export -f safe_mkdir safe_write_file
export -f download_with_retry validate_checksum
export -f detect_os detect_arch command_exists
export -f show_progress create_temp_file load_config
export -f version_compare

# Export constants
export RED GREEN YELLOW BLUE PURPLE CYAN NC
export SCRIPT_DIR PROJECT_ROOT CONFIG_DIR LOG_FILE