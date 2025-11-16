#!/bin/bash

# Claude Universal Installer - Security Module
# Provides security hardening features including encrypted storage and validation

set -eo pipefail

# Source core utilities
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Security configuration
readonly SECURITY_DIR="$CONFIG_DIR/security"
readonly KEYCHAIN_SERVICE="claude-universal-installer"
readonly ENCRYPTION_ALGORITHM="AES-256-CBC"
readonly CHECKSUM_ALGORITHM="sha256"

# Security state
declare -A SECURITY_STATE=(
    ["encryption_enabled"]="false"
    ["keychain_available"]="false"
    ["secure_temp_enabled"]="true"
    ["checksum_validation"]="true"
)

# Platform-specific security detection
detect_security_capabilities() {
    log "Detecting platform security capabilities..."

    local os=$(detect_os)
    local keychain_available=false

    case "$os" in
        "macos")
            # Check for macOS Keychain
            if command -v security >/dev/null 2>&1; then
                if security -v >/dev/null 2>&1; then
                    keychain_available=true
                    log "macOS Keychain detected"
                fi
            fi
            ;;
        "linux")
            # Check for Linux keyring support
            if command -v gnome-keyring-daemon >/dev/null 2>&1; then
                keychain_available=true
                log "GNOME Keyring detected"
            elif command -v kwallet-query >/dev/null 2>&1; then
                keychain_available=true
                log "KWallet detected"
            elif [[ -f "$HOME/.local/share/keyrings/default.keyring" ]]; then
                keychain_available=true
                log "Linux keyring files detected"
            fi
            ;;
    esac

    SECURITY_STATE["keychain_available"]="$keychain_available"

    # Check for OpenSSL
    if command -v openssl >/dev/null 2>&1; then
        log "OpenSSL available for encryption"
        SECURITY_STATE["openssl_available"]="true"
    else
        warn "OpenSSL not available, encryption disabled"
        SECURITY_STATE["openssl_available"]="false"
    fi

    # Check for shasum (for checksums)
    if command -v shasum >/dev/null 2>&1; then
        log "shasum available for checksums"
        SECURITY_STATE["shasum_available"]="true"
    else
        warn "shasum not available, using fallback checksum method"
        SECURITY_STATE["shasum_available"]="false"
    fi

    # Create security directory
    safe_mkdir "$SECURITY_DIR"
    chmod 700 "$SECURITY_DIR" 2>/dev/null || true

    log "Security capabilities detection completed"
}

# Generate secure encryption key
generate_encryption_key() {
    local key_length=32  # 256 bits for AES-256
    local key_file="$SECURITY_DIR/.encryption_key"

    # Check if key already exists
    if [[ -f "$key_file" ]]; then
        local existing_key
        existing_key=$(cat "$key_file" 2>/dev/null)
        if [[ -n "$existing_key" && ${#existing_key} -eq $key_length ]]; then
            echo "$existing_key"
            return 0
        fi
    fi

    log "Generating new encryption key..."

    # Generate key using available methods
    local new_key=""
    if [[ "${SECURITY_STATE[openssl_available]}" == "true" ]]; then
        new_key=$(openssl rand -hex $key_length 2>/dev/null)
    elif [[ -f "/dev/urandom" ]]; then
        new_key=$(dd if=/dev/urandom bs=$key_length count=1 2>/dev/null | hexdump -v -e '/1 "%02x"' | tr -d '\n ')
    fi

    # Fallback to less secure method if needed
    if [[ -z "$new_key" || ${#new_key} -lt $key_length ]]; then
        warn "Using fallback key generation method"
        new_key=$(date +%s%N | sha256sum | cut -d' ' -f1)
        new_key="${new_key:0:$key_length}"
    fi

    if [[ -n "$new_key" && ${#new_key} -eq $key_length ]]; then
        # Store key securely
        echo "$new_key" > "$key_file"
        chmod 600 "$key_file" 2>/dev/null || true
        log "Encryption key generated and stored securely"
        echo "$new_key"
    else
        error "Failed to generate encryption key"
        return 1
    fi
}

# Get encryption key
get_encryption_key() {
    generate_encryption_key
}

# Encrypt data using OpenSSL
encrypt_data() {
    local data="$1"
    local key="$2"
    local output_file="$3"

    if [[ "${SECURITY_STATE[openssl_available]}" != "true" ]]; then
        warn "OpenSSL not available, using base64 encoding instead"
        echo "$data" | base64 > "$output_file"
        return 0
    fi

    log "Encrypting data to: $output_file"

    # Generate random IV
    local iv
    iv=$(openssl rand -hex 16 2>/dev/null)

    # Encrypt data
    local encrypted_data
    encrypted_data=$(echo "$data" | openssl enc -"$ENCRYPTION_ALGORITHM" -K "$key" -iv "$iv" 2>/dev/null | base64 -w 0)

    if [[ -n "$encrypted_data" ]]; then
        # Store IV and encrypted data
        echo "${iv}:${encrypted_data}" > "$output_file"
        chmod 600 "$output_file" 2>/dev/null || true
        success "Data encrypted successfully"
        return 0
    else
        error "Failed to encrypt data"
        return 1
    fi
}

# Decrypt data using OpenSSL
decrypt_data() {
    local input_file="$1"
    local key="$2"

    if [[ ! -f "$input_file" ]]; then
        error "Encrypted file not found: $input_file"
        return 1
    fi

    if [[ "${SECURITY_STATE[openssl_available]}" != "true" ]]; then
        warn "OpenSSL not available, using base64 decoding instead"
        base64 -d "$input_file" 2>/dev/null
        return $?
    fi

    log "Decrypting data from: $input_file"

    # Read IV and encrypted data
    local encrypted_content
    encrypted_content=$(cat "$input_file")

    local iv="${encrypted_content%%:*}"
    local encrypted_data="${encrypted_content#*:}"

    if [[ -z "$iv" || -z "$encrypted_data" ]]; then
        error "Invalid encrypted file format"
        return 1
    fi

    # Decrypt data
    local decrypted_data
    decrypted_data=$(echo "$encrypted_data" | base64 -d | openssl enc -d -"$ENCRYPTION_ALGORITHM" -K "$key" -iv "$iv" 2>/dev/null)

    if [[ -n "$decrypted_data" ]]; then
        echo "$decrypted_data"
        return 0
    else
        error "Failed to decrypt data"
        return 1
    fi
}

# Store API token securely
store_api_token() {
    local api_token="$1"
    local token_type="${2:-anthropic}"

    if [[ -z "$api_token" ]]; then
        error "API token cannot be empty"
        return 1
    fi

    log "Storing API token securely..."

    # Validate token format
    if [[ ! "$api_token" =~ ^sk-ant-[a-zA-Z0-9_-]+$ ]]; then
        warn "API token format may be invalid"
        warn "Expected format: sk-ant-xxxxxxxxxxxxxxxxxxxxxxxx"
    fi

    # Try platform-specific secure storage first
    if [[ "${SECURITY_STATE[keychain_available]}" == "true" ]]; then
        if store_api_token_keychain "$api_token" "$token_type"; then
            success "API token stored securely in system keychain"
            return 0
        fi
        warn "Keychain storage failed, using encrypted file storage"
    fi

    # Fallback to encrypted file storage
    local token_file="$SECURITY_DIR/${token_type}_token.enc"
    local encryption_key
    encryption_key=$(get_encryption_key)

    if encrypt_data "$api_token" "$encryption_key" "$token_file"; then
        success "API token stored securely in encrypted file"
        return 0
    else
        error "Failed to store API token securely"
        return 1
    fi
}

# Retrieve API token securely
retrieve_api_token() {
    local token_type="${1:-anthropic}"

    # Try platform-specific secure storage first
    if [[ "${SECURITY_STATE[keychain_available]}" == "true" ]]; then
        local token
        token=$(retrieve_api_token_keychain "$token_type")
        if [[ -n "$token" ]]; then
            echo "$token"
            return 0
        fi
    fi

    # Fallback to encrypted file storage
    local token_file="$SECURITY_DIR/${token_type}_token.enc"

    if [[ ! -f "$token_file" ]]; then
        return 1
    fi

    local encryption_key
    encryption_key=$(get_encryption_key)

    local token
    token=$(decrypt_data "$token_file" "$encryption_key")

    if [[ -n "$token" ]]; then
        echo "$token"
        return 0
    else
        error "Failed to retrieve API token"
        return 1
    fi
}

# Store API token in system keychain (macOS)
store_api_token_keychain() {
    local api_token="$1"
    local token_type="$2"

    local os=$(detect_os)
    case "$os" in
        "macos")
            if security add-generic-password \
                -a "$USER" \
                -s "$KEYCHAIN_SERVICE-$token_type" \
                -w "$api_token" \
                -T "$(command -v claude 2>/dev/null || echo "")" \
                -U 2>/dev/null; then
                return 0
            fi
            ;;
        "linux")
            # Try GNOME Keyring
            if command -v secret-tool >/dev/null 2>&1; then
                if echo "$api_token" | secret-tool store --label="Claude $token_type Token" "$KEYCHAIN_SERVICE-$token_type" 2>/dev/null; then
                    return 0
                fi
            fi
            ;;
    esac

    return 1
}

# Retrieve API token from system keychain
retrieve_api_token_keychain() {
    local token_type="$1"

    local os=$(detect_os)
    case "$os" in
        "macos")
            security find-generic-password \
                -a "$USER" \
                -s "$KEYCHAIN_SERVICE-$token_type" \
                -w 2>/dev/null
            return $?
            ;;
        "linux")
            # Try GNOME Keyring
            if command -v secret-tool >/dev/null 2>&1; then
                secret-tool lookup "$KEYCHAIN_SERVICE-$token_type" 2>/dev/null
                return $?
            fi
            ;;
    esac

    return 1
}

# Calculate file checksum
calculate_checksum() {
    local file_path="$1"
    local algorithm="${2:-$CHECKSUM_ALGORITHM}"

    if [[ ! -f "$file_path" ]]; then
        error "File not found for checksum calculation: $file_path"
        return 1
    fi

    local checksum=""
    case "$algorithm" in
        "sha256")
            if [[ "${SECURITY_STATE[shasum_available]}" == "true" ]]; then
                checksum=$(shasum -a 256 "$file_path" 2>/dev/null | cut -d' ' -f1)
            elif command -v openssl >/dev/null 2>&1; then
                checksum=$(openssl dgst -sha256 "$file_path" 2>/dev/null | cut -d' ' -f2)
            else
                # Fallback method
                checksum=$(cksum "$file_path" 2>/dev/null | cut -d' ' -f1)
            fi
            ;;
        "sha1")
            if [[ "${SECURITY_STATE[shasum_available]}" == "true" ]]; then
                checksum=$(shasum -a 1 "$file_path" 2>/dev/null | cut -d' ' -f1)
            elif command -v openssl >/dev/null 2>&1; then
                checksum=$(openssl dgst -sha1 "$file_path" 2>/dev/null | cut -d' ' -f2)
            fi
            ;;
        "md5")
            if command -v md5 >/dev/null 2>&1; then
                checksum=$(md5 -q "$file_path" 2>/dev/null)
            elif command -v openssl >/dev/null 2>&1; then
                checksum=$(openssl dgst -md5 "$file_path" 2>/dev/null | cut -d' ' -f2)
            fi
            ;;
        *)
            error "Unsupported checksum algorithm: $algorithm"
            return 1
            ;;
    esac

    if [[ -n "$checksum" ]]; then
        echo "$checksum"
        return 0
    else
        error "Failed to calculate checksum for: $file_path"
        return 1
    fi
}

# Validate file checksum
validate_file_checksum() {
    local file_path="$1"
    local expected_checksum="$2"
    local algorithm="${3:-$CHECKSUM_ALGORITHM}"

    if [[ -z "$expected_checksum" ]]; then
        warn "No expected checksum provided for validation"
        return 0
    fi

    if [[ ! -f "$file_path" ]]; then
        error "File not found for checksum validation: $file_path"
        return 1
    fi

    local actual_checksum
    actual_checksum=$(calculate_checksum "$file_path" "$algorithm")

    if [[ "$actual_checksum" == "$expected_checksum" ]]; then
        success "Checksum validation passed for: $(basename "$file_path")"
        return 0
    else
        error "Checksum validation failed for: $(basename "$file_path")"
        error "Expected: $expected_checksum"
        error "Actual:   $actual_checksum"
        return 1
    fi
}

# Download with checksum validation
download_with_checksum_validation() {
    local url="$1"
    local output_file="$2"
    local expected_checksum="$3"
    local algorithm="${4:-$CHECKSUM_ALGORITHM}"
    local max_attempts="${5:-3}"

    log "Downloading file with checksum validation: $(basename "$output_file")"

    # Download file
    if ! download_with_retry "$url" "$output_file" "$max_attempts" "$(basename "$output_file")"; then
        error "Download failed, cannot validate checksum"
        return 1
    fi

    # Validate checksum if provided
    if [[ -n "$expected_checksum" ]]; then
        if validate_file_checksum "$output_file" "$expected_checksum" "$algorithm"; then
            success "Download and checksum validation passed"
            return 0
        else
            # Remove corrupted file
            rm -f "$output_file"
            error "Downloaded file failed checksum validation, file removed"
            return 1
        fi
    else
        warn "No checksum provided for validation"
        return 0
    fi
}

# Create secure temporary file
create_secure_temp_file() {
    local prefix="${1:-claude-secure}"
    local temp_file

    # Try to create secure temp file
    if command -v mktemp >/dev/null 2>&1; then
        temp_file=$(mktemp -t "${prefix}.XXXXXXXXXX") || {
            warn "mktemp failed, using fallback temp file creation"
        }
    fi

    # Fallback method
    if [[ -z "$temp_file" ]]; then
        temp_file="/tmp/${prefix}.$(date +%s).$$"
        touch "$temp_file" 2>/dev/null || {
            error "Failed to create temporary file"
            return 1
        }
    fi

    # Set secure permissions
    chmod 600 "$temp_file" 2>/dev/null || true

    # Add to cleanup tracking
    TEMP_FILES="${TEMP_FILES:-} $temp_file"

    echo "$temp_file"
}

# Sanitize user input
sanitize_input() {
    local input="$1"
    local input_type="${2:-general}"

    case "$input_type" in
        "filename")
            # Remove dangerous characters for filenames
            echo "$input" | sed 's/[<>:"|?*]//g' | sed 's/[^a-zA-Z0-9._-]//g'
            ;;
        "path")
            # Remove dangerous path traversal attempts
            echo "$input" | sed 's/\.\.//g' | sed 's|^/||'
            ;;
        "url")
            # Basic URL validation
            if [[ "$input" =~ ^https?://[a-zA-Z0-9.-]+[a-zA-Z0-9._/-]*$ ]]; then
                echo "$input"
            else
                echo ""
            fi
            ;;
        "api_key")
            # Only allow valid API key format
            if [[ "$input" =~ ^sk-ant-[a-zA-Z0-9_-]+$ ]]; then
                echo "$input"
            else
                echo ""
            fi
            ;;
        *)
            # General sanitization - remove control characters
            echo "$input" | tr -d '\000-\010\013\014\016-\037\177-\377'
            ;;
    esac
}

# Validate and sanitize API endpoint
validate_api_endpoint() {
    local endpoint="$1"

    # Basic URL validation
    if [[ ! "$endpoint" =~ ^https?:// ]]; then
        error "API endpoint must start with http:// or https://"
        return 1
    fi

    # Sanitize and validate
    local sanitized_endpoint
    sanitized_endpoint=$(sanitize_input "$endpoint" "url")

    if [[ -z "$sanitized_endpoint" ]]; then
        error "Invalid API endpoint format"
        return 1
    fi

    # Additional validation for known endpoints
    local known_endpoints=(
        "api.anthropic.com"
        "api.z.ai"
        "openrouter.ai/api"
    )

    local domain="${sanitized_endpoint#*://}"
    domain="${domain%%/*}"

    for known_endpoint in "${known_endpoints[@]}"; do
        if [[ "$domain" == *"$known_endpoint"* ]]; then
            echo "$sanitized_endpoint"
            return 0
        fi
    done

    warn "Unknown API endpoint: $domain"
    echo "$sanitized_endpoint"
    return 0
}

# Security audit of installation
perform_security_audit() {
    header "Performing Security Audit"

    log "Auditing installation security..."

    local audit_issues=()
    local audit_warnings=()

    # Check file permissions
    if [[ -d "$CONFIG_DIR" ]]; then
        local config_perms
        config_perms=$(stat -f "%A" "$CONFIG_DIR" 2>/dev/null || stat -c "%a" "$CONFIG_DIR" 2>/dev/null)

        if [[ "$config_perms" =~ ^[0-9]+$ ]]; then
            if [[ $config_perms -gt 755 ]]; then
                audit_issues+=("Configuration directory has permissive permissions: $config_perms")
            fi
        fi
    fi

    # Check for plaintext API tokens
    local config_file="$CONFIG_DIR/config.json"
    if [[ -f "$config_file" ]]; then
        if grep -q "sk-ant-" "$config_file" 2>/dev/null; then
            audit_issues+=("API token found in plaintext configuration file")
        fi
    fi

    # Check for secure storage
    if [[ "${SECURITY_STATE[encryption_enabled]}" == "false" ]]; then
        audit_warnings+=("Encryption is not enabled")
    fi

    # Check for temporary files with sensitive data
    local temp_files_pattern="/tmp/claude-* /tmp/*claude*"
    for pattern in $temp_files_pattern; do
        if ls $pattern 1> /dev/null 2>&1; then
            audit_warnings+=("Temporary files found that may contain sensitive data")
            break
        fi
    done

    # Generate audit report
    echo ""
    echo "Security Audit Results:"
    echo "======================="

    if [[ ${#audit_issues[@]} -eq 0 && ${#audit_warnings[@]} -eq 0 ]]; then
        success "✅ No security issues found"
    else
        if [[ ${#audit_issues[@]} -gt 0 ]]; then
            echo -e "\n${RED}Security Issues:${NC}"
            for issue in "${audit_issues[@]}"; do
                echo "  ❌ $issue"
            done
        fi

        if [[ ${#audit_warnings[@]} -gt 0 ]]; then
            echo -e "\n${YELLOW}Security Warnings:${NC}"
            for warning in "${audit_warnings[@]}"; do
                echo "  ⚠️  $warning"
            done
        fi
    fi

    echo ""
    echo "Security Status:"
    echo "  Encryption: ${SECURITY_STATE[encryption_enabled]}"
    echo "  Keychain Available: ${SECURITY_STATE[keychain_available]}"
    echo "  OpenSSL Available: ${SECURITY_STATE[openssl_available]}"
    echo "  Checksum Validation: ${SECURITY_STATE[checksum_validation]}"

    # Return appropriate exit code
    if [[ ${#audit_issues[@]} -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}

# Initialize security module
init_security() {
    log "Initializing security module..."

    # Detect security capabilities
    detect_security_capabilities

    # Set secure umask
    umask 077

    # Initialize security state
    if [[ "${SECURITY_STATE[openssl_available]}" == "true" ]]; then
        SECURITY_STATE["encryption_enabled"]="true"
    fi

    # Create security directory
    safe_mkdir "$SECURITY_DIR"
    chmod 700 "$SECURITY_DIR" 2>/dev/null || true

    success "Security module initialized"
}

# Export functions
export -f detect_security_capabilities generate_encryption_key get_encryption_key
export -f encrypt_data decrypt_data store_api_token retrieve_api_token
export -f store_api_token_keychain retrieve_api_token_keychain
export -f calculate_checksum validate_file_checksum download_with_checksum_validation
export -f create_secure_temp_file sanitize_input validate_api_endpoint
export -f perform_security_audit init_security

# Export variables
export SECURITY_DIR KEYCHAIN_SERVICE ENCRYPTION_ALGORITHM CHECKSUM_ALGORITHM

# Export security state
for key in "${!SECURITY_STATE[@]}"; do
    export SECURITY_STATE_$key="${SECURITY_STATE[$key]}"
done