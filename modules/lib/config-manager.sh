#!/bin/bash

# Claude Universal Installer - Configuration Management Module
# Handles unified configuration across all installation types

set -euo pipefail

# Source core utilities
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Default configuration values
DEFAULT_CONFIG='{
    "installationType": "",
    "apiToken": "",
    "apiEndpoint": "https://api.anthropic.com",
    "model": "claude-3-5-sonnet-20241022",
    "version": "1.0.0",
    "installedAt": "",
    "os": "",
    "architecture": "",
    "features": {
        "streaming": true,
        "contextManagement": true,
        "customCommands": true,
        "autoUpdate": false
    },
    "paths": {
        "configDir": "",
        "binaryDir": "",
        "dataDir": "",
        "logDir": ""
    },
    "security": {
        "tokenEncryption": false,
        "checksumValidation": true,
        "secureTemp": true
    },
    "preferences": {
        "defaultSdk": "claude-code-cli",
        "logLevel": "info",
        "autoBackup": true,
        "telemetry": false
    }
}'

# Configuration file paths
get_config_file() {
    echo "${CONFIG_DIR}/config.json"
}

get_backup_config_file() {
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    echo "${CONFIG_DIR}/config.backup.${timestamp}.json"
}

# Initialize configuration directory and files
init_config() {
    local config_file
    config_file="$(get_config_file)"

    # Create config directory
    safe_mkdir "$CONFIG_DIR"

    # Initialize log file
    touch "$LOG_FILE"

    # Create default configuration if it doesn't exist
    if [[ ! -f "$config_file" ]]; then
        create_default_config
    fi

    # Validate existing configuration
    validate_config_structure "$config_file"
}

# Create default configuration
create_default_config() {
    local config_file
    config_file="$(get_config_file)"

    # Create default config with detected system info
    local config="$DEFAULT_CONFIG"

    # Update with detected system information
    config=$(echo "$config" | jq --arg os "$(detect_os)" '.os = $os')
    config=$(echo "$config" | jq --arg arch "$(detect_arch)" '.architecture = $arch')
    config=$(echo "$config" | jq --arg config_dir "$CONFIG_DIR" '.paths.configDir = $config_dir')
    config=$(echo "$config" | jq --arg log_file "$LOG_FILE" '.paths.logDir = $log_file')

    # Write configuration
    if echo "$config" | jq '.' > "$config_file"; then
        success "Created default configuration: $config_file"
    else
        error "Failed to create default configuration"
        return 1
    fi
}

# Comprehensive configuration validation schema
readonly CONFIG_SCHEMA='{
    "installationType": {
        "type": "string",
        "required": true,
        "enum": ["claude-code-cli", "claude-python-sdk", "claude-typescript-sdk"],
        "description": "Type of Claude installation"
    },
    "apiToken": {
        "type": "string",
        "required": true,
        "pattern": "^sk-ant-[a-zA-Z0-9_-]+$",
        "description": "Anthropic API token"
    },
    "apiEndpoint": {
        "type": "string",
        "required": true,
        "pattern": "^https?://[a-zA-Z0-9.-]+[a-zA-Z0-9._/-]*$",
        "description": "API endpoint URL"
    },
    "model": {
        "type": "string",
        "required": true,
        "enum": ["claude-3-opus-20240229", "claude-3-sonnet-20240229", "claude-3-5-sonnet-20241022", "claude-3-haiku-20240307"],
        "description": "Claude model to use"
    },
    "version": {
        "type": "string",
        "required": true,
        "pattern": "^\\d+\\.\\d+\\.\\d+$",
        "description": "Configuration version"
    },
    "os": {
        "type": "string",
        "required": false,
        "enum": ["linux", "macos", "windows", "unknown"]
    },
    "architecture": {
        "type": "string",
        "required": false,
        "enum": ["x64", "arm64", "arm", "unknown"]
    },
    "features": {
        "type": "object",
        "required": false,
        "properties": {
            "streaming": {"type": "boolean"},
            "contextManagement": {"type": "boolean"},
            "customCommands": {"type": "boolean"},
            "autoUpdate": {"type": "boolean"},
            "asyncSupport": {"type": "boolean"},
            "projectTemplates": {"type": "boolean"},
            "typeScript": {"type": "boolean"},
            "tokenEncryption": {"type": "boolean"},
            "checksumValidation": {"type": "boolean"},
            "secureTemp": {"type": "boolean"}
        }
    },
    "paths": {
        "type": "object",
        "required": false,
        "properties": {
            "configDir": {"type": "string"},
            "binaryDir": {"type": "string"},
            "dataDir": {"type": "string"},
            "logDir": {"type": "string"}
        }
    },
    "security": {
        "type": "object",
        "required": false,
        "properties": {
            "tokenEncryption": {"type": "boolean"},
            "checksumValidation": {"type": "boolean"},
            "secureTemp": {"type": "boolean"},
            "auditLogging": {"type": "boolean"}
        }
    },
    "preferences": {
        "type": "object",
        "required": false,
        "properties": {
            "defaultSdk": {"type": "string"},
            "logLevel": {"type": "string", "enum": ["debug", "info", "warn", "error"]},
            "autoBackup": {"type": "boolean"},
            "telemetry": {"type": "boolean"}
        }
    }
}'

# Validate configuration value against schema rules
validate_config_value() {
    local key="$1"
    local value="$2"
    local schema_info="$3"

    local field_type=$(echo "$schema_info" | jq -r '.type')
    local required=$(echo "$schema_info" | jq -r '.required // false')
    local description=$(echo "$schema_info" | jq -r '.description // ""')

    log "Validating configuration field: $key (type: $field_type, required: $required)"

    # Check if value exists when required
    if [[ "$required" == "true" && (-z "$value" || "$value" == "null") ]]; then
        error "Required configuration field is missing: $key"
        return 1
    fi

    # Skip validation if value is empty and not required
    if [[ -z "$value" || "$value" == "null" ]]; then
        return 0
    fi

    # Type validation
    case "$field_type" in
        "string")
            if [[ "$(echo "$value" | jq -r 'type')" != "string" ]]; then
                error "Configuration field $key must be a string"
                return 1
            fi
            ;;
        "boolean")
            if [[ "$(echo "$value" | jq -r 'type')" != "boolean" ]]; then
                error "Configuration field $key must be a boolean (true/false)"
                return 1
            fi
            ;;
        "object")
            if [[ "$(echo "$value" | jq -r 'type')" != "object" ]]; then
                error "Configuration field $key must be an object"
                return 1
            fi
            ;;
    esac

    # Pattern validation
    local pattern
    pattern=$(echo "$schema_info" | jq -r '.pattern // empty')
    if [[ -n "$pattern" && "$value" =~ $pattern ]]; then
        error "Configuration field $key does not match required pattern: $pattern"
        return 1
    fi

    # Enum validation
    local enum_values
    enum_values=$(echo "$schema_info" | jq -r '.enum[]? // empty')
    if [[ -n "$enum_values" ]]; then
        local valid_value=false
        while IFS= read -r enum_val; do
            if [[ "$value" == "$enum_val" ]]; then
                valid_value=true
                break
            fi
        done <<< "$enum_values"

        if [[ "$valid_value" != "true" ]]; then
            error "Configuration field $key must be one of: $enum_values"
            error "Found: $value"
            return 1
        fi
    fi

    return 0
}

# Validate configuration structure with comprehensive checks
validate_config_structure() {
    local config_file="$1"
    local strict_mode="${2:-false}"

    if [[ ! -f "$config_file" ]]; then
        error "Configuration file not found: $config_file"
        return 1
    fi

    log "Validating configuration structure: $config_file"

    # Check if valid JSON
    if ! jq empty "$config_file" 2>/dev/null; then
        error "Configuration file is not valid JSON: $config_file"
        if [[ "$strict_mode" == "true" ]]; then
            # Show JSON error details
            local json_error
            json_error=$(jq empty "$config_file" 2>&1 | head -3)
            error "JSON error details: $json_error"
        fi
        return 1
    fi

    # Get configuration as JSON
    local config_json
    config_json=$(cat "$config_file")

    # Validate schema
    local validation_errors=0

    # Check required fields and validate each field
    while IFS= read -r field; do
        local field_name=$(echo "$field" | jq -r '.key')
        local field_schema=$(echo "$CONFIG_SCHEMA" | jq -r ".\"$field_name\" // empty")

        if [[ -n "$field_schema" && "$field_schema" != "null" ]]; then
            local field_value
            field_value=$(echo "$config_json" | jq -r ".$field_name // empty")

            if ! validate_config_value "$field_name" "$field_value" "$field_schema"; then
                ((validation_errors++))
            fi
        fi
    done < <(echo "$CONFIG_SCHEMA" | jq -r 'keys[]' | while read -r key; do echo "{\"key\": \"$key\"}"; done)

    # Additional semantic validation
    local installation_type
    installation_type=$(echo "$config_json" | jq -r '.installationType // empty')

    # Validate installation type consistency
    case "$installation_type" in
        "claude-code-cli")
            # Check for CLI-specific fields
            local cli_binary_path
            cli_binary_path=$(echo "$config_json" | jq -r '.cli.binaryPath // empty')
            if [[ -n "$cli_binary_path" && ! -f "$cli_binary_path" ]]; then
                warn "CLI binary path does not exist: $cli_binary_path"
                [[ "$strict_mode" == "true" ]] && ((validation_errors++))
            fi
            ;;
        "claude-python-sdk")
            # Check for Python-specific fields
            local python_venv_path
            python_venv_path=$(echo "$config_json" | jq -r '.python.venvPath // empty')
            if [[ -n "$python_venv_path" && ! -d "$python_venv_path" ]]; then
                warn "Python virtual environment does not exist: $python_venv_path"
                [[ "$strict_mode" == "true" ]] && ((validation_errors++))
            fi
            ;;
        "claude-typescript-sdk")
            # Check for TypeScript-specific fields
            local typescript_project_dir
            typescript_project_dir=$(echo "$config_json" | jq -r '.typescript.projectDir // empty')
            if [[ -n "$typescript_project_dir" && ! -d "$typescript_project_dir" ]]; then
                warn "TypeScript project directory does not exist: $typescript_project_dir"
                [[ "$strict_mode" == "true" ]] && ((validation_errors++))
            fi
            ;;
    esac

    # Validate API endpoint format
    local api_endpoint
    api_endpoint=$(echo "$config_json" | jq -r '.apiEndpoint // empty')
    if [[ -n "$api_endpoint" ]]; then
        if [[ ! "$api_endpoint" =~ ^https?:// ]]; then
            error "API endpoint must start with http:// or https://"
            ((validation_errors++))
        fi

        # Check endpoint accessibility (optional, may fail in restricted environments)
        if command -v curl >/dev/null 2>&1; then
            if ! curl -s --connect-timeout 5 --max-time 10 "$api_endpoint" >/dev/null 2>&1; then
                warn "API endpoint may not be accessible: $api_endpoint"
                [[ "$strict_mode" == "true" ]] && ((validation_errors++))
            fi
        fi
    fi

    # Validate paths exist
    local paths_config
    paths_config=$(echo "$config_json" | jq -r '.paths // {}')
    while IFS= read -r path_entry; do
        local path_key=$(echo "$path_entry" | jq -r '.key')
        local path_value=$(echo "$path_entry" | jq -r '.value')

        if [[ -n "$path_value" && "$path_key" != "null" ]]; then
            case "$path_key" in
                "configDir"|"dataDir"|"logDir")
                    if [[ ! -d "$path_value" ]]; then
                        warn "Path directory does not exist: $path_key -> $path_value"
                        [[ "$strict_mode" == "true" ]] && ((validation_errors++))
                    fi
                    ;;
                "binaryDir")
                    if [[ ! -d "$path_value" ]]; then
                        warn "Binary directory does not exist: $path_value"
                        [[ "$strict_mode" == "true" ]] && ((validation_errors++))
                    fi
                    ;;
            esac
        fi
    done < <(echo "$paths_config" | jq -r 'to_entries[] | "\(.key): \(.value)"' | while read -r entry; do echo "{\"key\": \"${entry%%:*}\", \"value\": \"${entry#*:}\"}"; done)

    # Log validation results
    if [[ $validation_errors -eq 0 ]]; then
        success "Configuration validation passed"
        log "Configuration file is valid: $config_file"
        return 0
    else
        error "Configuration validation failed with $validation_errors error(s)"
        if [[ "$strict_mode" == "true" ]]; then
            error "Strict mode enabled - fix validation errors before proceeding"
        fi
        return 1
    fi
}

# Read configuration value
get_config_value() {
    local key="$1"
    local default_value="${2:-}"
    local config_file
    config_file="$(get_config_file)"

    if [[ -f "$config_file" ]]; then
        jq -r ".$key // \"$default_value\"" "$config_file" 2>/dev/null || echo "$default_value"
    else
        echo "$default_value"
    fi
}

# Set configuration value
set_config_value() {
    local key="$1"
    local value="$2"
    local config_file
    config_file="$(get_config_file)"

    # Backup current configuration
    backup_config

    # Update configuration
    if jq ".$key = \"$value\"" "$config_file" > "${config_file}.tmp"; then
        mv "${config_file}.tmp" "$config_file"
        log "Updated configuration: $key = $value"
    else
        error "Failed to update configuration: $key"
        rm -f "${config_file}.tmp"
        return 1
    fi
}

# Set nested configuration value
set_nested_config_value() {
    local key_path="$1"
    local value="$2"
    local config_file
    config_file="$(get_config_file)"

    # Backup current configuration
    backup_config

    # Update nested configuration
    if jq ".$key_path = \"$value\"" "$config_file" > "${config_file}.tmp"; then
        mv "${config_file}.tmp" "$config_file"
        log "Updated nested configuration: $key_path = $value"
    else
        error "Failed to update nested configuration: $key_path"
        rm -f "${config_file}.tmp"
        return 1
    fi
}

# Backup configuration
backup_config() {
    local config_file
    config_file="$(get_config_file)"
    local backup_file
    backup_file="$(get_backup_config_file)"

    if [[ -f "$config_file" ]]; then
        cp "$config_file" "$backup_file" || {
            warn "Failed to backup configuration"
            return 1
        }
        log "Configuration backed up: $backup_file"
    fi
}

# Restore configuration from backup
restore_config() {
    local backup_file="$1"
    local config_file
    config_file="$(get_config_file)"

    if [[ ! -f "$backup_file" ]]; then
        error "Backup file not found: $backup_file"
        return 1
    fi

    # Validate backup before restoring
    if ! jq empty "$backup_file" 2>/dev/null; then
        error "Backup file is not valid JSON: $backup_file"
        return 1
    fi

    # Current backup before restore
    backup_config

    # Restore from backup
    if cp "$backup_file" "$config_file"; then
        success "Configuration restored from: $backup_file"
    else
        error "Failed to restore configuration"
        return 1
    fi
}

# List available backups
list_backups() {
    local backup_pattern="${CONFIG_DIR}/config.backup.*.json"

    if ls $backup_pattern 1> /dev/null 2>&1; then
        echo "Available configuration backups:"
        ls -lt $backup_pattern | head -10
    else
        echo "No configuration backups found"
    fi
}

# Export configuration
export_config() {
    local output_file="$1"
    local config_file
    config_file="$(get_config_file)"

    if [[ -f "$config_file" ]]; then
        # Remove sensitive information before export
        jq 'del(.apiToken) | del(.security)' "$config_file" > "$output_file"
        success "Configuration exported to: $output_file"
    else
        error "Configuration file not found"
        return 1
    fi
}

# Import configuration
import_config() {
    local input_file="$1"
    local config_file
    config_file="$(get_config_file)"

    if [[ ! -f "$input_file" ]]; then
        error "Import file not found: $input_file"
        return 1
    fi

    # Validate imported configuration
    if ! jq empty "$input_file" 2>/dev/null; then
        error "Import file is not valid JSON: $input_file"
        return 1
    fi

    # Backup current configuration
    backup_config

    # Import configuration
    if cp "$input_file" "$config_file"; then
        success "Configuration imported from: $input_file"
    else
        error "Failed to import configuration"
        return 1
    fi
}

# Reset configuration to defaults
reset_config() {
    local config_file
    config_file="$(get_config_file)"

    # Backup current configuration
    backup_config

    # Create new default configuration
    create_default_config
    success "Configuration reset to defaults"
}

# Validate API token format
validate_api_token() {
    local token="$1"

    if [[ -z "$token" ]]; then
        error "API token is required"
        return 1
    fi

    # Basic token format validation (Anthropic tokens start with sk-ant-)
    if [[ ! "$token" =~ ^sk-ant-[a-zA-Z0-9_-]+$ ]]; then
        warn "API token format may be invalid"
        warn "Expected format: sk-ant-xxxxxxxxxxxxxxxxxxxxxxxx"
    fi
}

# Validate API endpoint
validate_api_endpoint() {
    local endpoint="$1"

    validate_url "$endpoint" "API endpoint"

    # Check if endpoint is reachable
    if ! curl -s --connect-timeout 5 "$endpoint" >/dev/null 2>&1; then
        warn "API endpoint may not be reachable: $endpoint"
    fi
}

# Get configuration summary
get_config_summary() {
    local config_file
    config_file="$(get_config_file)"

    if [[ -f "$config_file" ]]; then
        echo "Configuration Summary:"
        echo "  Installation Type: $(get_config_value 'installationType')"
        echo "  API Endpoint: $(get_config_value 'apiEndpoint')"
        echo "  Model: $(get_config_value 'model')"
        echo "  Version: $(get_config_value 'version')"
        echo "  OS: $(get_config_value 'os')"
        echo "  Architecture: $(get_config_value 'architecture')"
        echo "  Config Directory: $(get_config_value 'paths.configDir')"
        echo "  Token Configured: $([ "$(get_config_value 'apiToken')" != "" ] && echo "Yes" || echo "No")"
    else
        echo "No configuration file found"
    fi
}

# Environment variable overrides
apply_env_overrides() {
    local config_file
    config_file="$(get_config_file)"

    # Apply environment variable overrides
    local env_vars=(
        "CLAUDE_API_TOKEN:apiToken"
        "CLAUDE_API_ENDPOINT:apiEndpoint"
        "CLAUDE_MODEL:model"
        "CLAUDE_LOG_LEVEL:preferences.logLevel"
        "CLAUDE_DEFAULT_SDK:preferences.defaultSdk"
    )

    for env_var in "${env_vars[@]}"; do
        local env_name="${env_var%:*}"
        local config_key="${env_var#*:}"
        local env_value="${!env_name:-}"

        if [[ -n "$env_value" ]]; then
            set_nested_config_value "$config_key" "$env_value"
            log "Applied environment override: $config_key = $env_value"
        fi
    done
}

# Export functions
export -f get_config_file get_backup_config_file
export -f init_config create_default_config validate_config_structure
export -f get_config_value set_config_value set_nested_config_value
export -f backup_config restore_config list_backups
export -f export_config import_config reset_config
export -f validate_api_token validate_api_endpoint
export -f get_config_summary apply_env_overrides