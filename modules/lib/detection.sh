#!/bin/bash

# Claude Universal Installer - Installation Detection Module
# Detects existing Claude installations and SDK components

set -euo pipefail

# Source core utilities
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Detection result structure
declare -a DETECTED_INSTALLATIONS=()
declare -a DETECTION_DETAILS=()

# Detection functions for different components
detect_claude_code_cli() {
    if command -v claude >/dev/null 2>&1; then
        local claude_path
        claude_path=$(command -v claude)
        local claude_version
        claude_version=$(claude --version 2>/dev/null || echo "unknown version")

        DETECTED_INSTALLATIONS+=("claude-code-cli")
        DETECTION_DETAILS+=("Claude Code CLI: $claude_path ($claude_version)")

        log "Detected Claude Code CLI: $claude_path"
        return 0
    fi
    return 1
}

detect_python_sdk() {
    local python_env_dir="$CONFIG_DIR/claude-python-env"

    if [[ -d "$python_env_dir" ]]; then
        local python_version=""
        if [[ -f "$python_env_dir/bin/python" ]]; then
            python_version=$("$python_env_dir/bin/python" --version 2>/dev/null || echo "unknown version")
        fi

        DETECTED_INSTALLATIONS+=("claude-python-sdk")
        DETECTION_DETAILS+=("Claude Python SDK: $python_env_dir ($python_version)")

        log "Detected Python SDK: $python_env_dir"
        return 0
    fi
    return 1
}

detect_typescript_sdk() {
    local ts_projects_dir="$CONFIG_DIR/claude-typescript-projects"

    if [[ -d "$ts_projects_dir" ]]; then
        local node_version=""
        if command -v node >/dev/null 2>&1; then
            node_version=$(node --version 2>/dev/null || echo "unknown version")
        fi

        DETECTED_INSTALLATIONS+=("claude-typescript-sdk")
        DETECTION_DETAILS+=("Claude TypeScript SDK: $ts_projects_dir ($node_version)")

        log "Detected TypeScript SDK: $ts_projects_dir"
        return 0
    fi
    return 1
}

detect_configuration_files() {
    local config_files=()

    # Check for universal installer config
    if [[ -f "$CONFIG_DIR/config.json" ]]; then
        config_files+=("$CONFIG_DIR/config.json")
    fi

    # Check for Claude CLI config
    if [[ -d "$HOME/.claude" ]]; then
        local claude_configs=$(find "$HOME/.claude" -name "*.json" 2>/dev/null || true)
        if [[ -n "$claude_configs" ]]; then
            while IFS= read -r config; do
                config_files+=("$config")
            done <<< "$claude_configs"
        fi

        DETECTED_INSTALLATIONS+=("claude-cli-config")
        DETECTION_DETAILS+=("Claude CLI config: $HOME/.claude")

        log "Detected Claude CLI configuration: $HOME/.claude"
    fi

    # Count configuration files
    if [[ ${#config_files[@]} -gt 0 ]]; then
        DETECTED_INSTALLATIONS+=("configuration-files")
        DETECTION_DETAILS+=("Configuration files: $CONFIG_DIR (${#config_files[@]} files)")

        log "Detected ${#config_files[@]} configuration files"
        return 0
    fi

    return 1
}

detect_docker_images() {
    if command_exists docker; then
        local docker_images
        docker_images=$(docker images --filter "reference=*claude*" --format "{{.Repository}}:{{.Tag}}" 2>/dev/null || true)

        if [[ -n "$docker_images" ]]; then
            while IFS= read -r image; do
                DETECTED_INSTALLATIONS+=("docker-image")
                DETECTION_DETAILS+=("Docker image: $image")
                log "Detected Docker image: $image"
            done <<< "$docker_images"
            return 0
        fi
    fi
    return 1
}

detect_system_integration() {
    local integration_found=false

    # Check PATH modifications
    if [[ -f "$HOME/.bashrc" ]] && grep -q "claude" "$HOME/.bashrc" 2>/dev/null; then
        DETECTED_INSTALLATIONS+=("bash-integration")
        DETECTION_DETAILS+=("Bash integration: PATH modifications in ~/.bashrc")
        integration_found=true
        log "Detected bash integration"
    fi

    if [[ -f "$HOME/.zshrc" ]] && grep -q "claude" "$HOME/.zshrc" 2>/dev/null; then
        DETECTED_INSTALLATIONS+=("zsh-integration")
        DETECTION_DETAILS+=("Zsh integration: PATH modifications in ~/.zshrc")
        integration_found=true
        log "Detected zsh integration"
    fi

    # Check for systemd services (if applicable)
    if command_exists systemctl && systemctl list-unit-files --type=service 2>/dev/null | grep -q claude; then
        DETECTED_INSTALLATIONS+=("systemd-services")
        DETECTION_DETAILS+=("Systemd services: Claude-related services found")
        integration_found=true
        log "Detected systemd services"
    fi

    if [[ "$integration_found" = true ]]; then
        return 0
    fi
    return 1
}

detect_package_installations() {
    local package_found=false

    # Check if Claude was installed via package manager
    if command_exists brew && brew list --formula 2>/dev/null | grep -q claude; then
        DETECTED_INSTALLATIONS+=("brew-package")
        DETECTION_DETAILS+=("Homebrew package: Claude installed via brew")
        package_found=true
        log "Detected Homebrew installation"
    fi

    if command_exists apt && dpkg -l 2>/dev/null | grep -q claude; then
        DETECTED_INSTALLATIONS+=("apt-package")
        DETECTION_DETAILS+=("APT package: Claude installed via apt")
        package_found=true
        log "Detected APT package installation"
    fi

    if command_exists yum && rpm -qa 2>/dev/null | grep -q claude; then
        DETECTED_INSTALLATIONS+=("yum-package")
        DETECTION_DETAILS+=("YUM package: Claude installed via yum")
        package_found=true
        log "Detected YUM package installation"
    fi

    if [[ "$package_found" = true ]]; then
        return 0
    fi
    return 1
}

detect_custom_installations() {
    # Check for common installation locations
    local common_paths=(
        "/usr/local/bin/claude"
        "/usr/bin/claude"
        "/opt/claude"
        "$HOME/.local/bin/claude"
        "$HOME/bin/claude"
    )

    for path in "${common_paths[@]}"; do
        if [[ -f "$path" ]] && [[ -x "$path" ]]; then
            # Check if this is different from the one in PATH
            local path_in_cli
            path_in_cli=$(command -v claude 2>/dev/null || echo "")

            if [[ "$path" != "$path_in_cli" ]]; then
                DETECTED_INSTALLATIONS+=("custom-installation")
                DETECTION_DETAILS+=("Custom installation: $path")
                log "Detected custom Claude installation: $path"
                return 0
            fi
        fi
    done

    return 1
}

# Main detection functions
detect_all_installations() {
    # Reset detection results
    DETECTED_INSTALLATIONS=()
    DETECTION_DETAILS=()

    log "Starting comprehensive installation detection..."

    # Run all detection functions
    detect_claude_code_cli
    detect_python_sdk
    detect_typescript_sdk
    detect_configuration_files
    detect_docker_images
    detect_system_integration
    detect_package_installations
    detect_custom_installations

    log "Detection complete. Found ${#DETECTED_INSTALLATIONS[@]} installation(s)"
}

detect_existing_installations() {
    header "Existing Claude Installations"

    detect_all_installations

    # Display results
    if [[ ${#DETECTED_INSTALLATIONS[@]} -gt 0 ]]; then
        echo -e "${GREEN}Found the following Claude installations:${NC}"
        echo ""
        for detail in "${DETECTION_DETAILS[@]}"; do
            echo -e "${CYAN}✓${NC} $detail"
        done
        echo ""
    else
        echo -e "${YELLOW}No existing Claude installations found.${NC}"
        echo ""
    fi
}

# Get specific installation information
get_installation_info() {
    local installation_type="$1"

    case "$installation_type" in
        "claude-code-cli")
            detect_claude_code_cli
            ;;
        "claude-python-sdk")
            detect_python_sdk
            ;;
        "claude-typescript-sdk")
            detect_typescript_sdk
            ;;
        "configuration-files")
            detect_configuration_files
            ;;
        "docker-images")
            detect_docker_images
            ;;
        "system-integration")
            detect_system_integration
            ;;
        "package-installations")
            detect_package_installations
            ;;
        "custom-installations")
            detect_custom_installations
            ;;
        *)
            error "Unknown installation type: $installation_type"
            return 1
            ;;
    esac
}

# Check if specific installation type exists
installation_exists() {
    local installation_type="$1"

    # Reset detection results
    DETECTED_INSTALLATIONS=()

    get_installation_info "$installation_type"

    # Check if installation was detected
    for detected in "${DETECTED_INSTALLATIONS[@]}"; do
        if [[ "$detected" == "$installation_type" ]] || \
           [[ "$installation_type" == "claude-code-cli" && "$detected" == "claude-code-cli" ]] || \
           [[ "$installation_type" == "claude-python-sdk" && "$detected" == "claude-python-sdk" ]] || \
           [[ "$installation_type" == "claude-typescript-sdk" && "$detected" == "claude-typescript-sdk" ]]; then
            return 0
        fi
    done

    return 1
}

# Get installation paths for a specific type
get_installation_paths() {
    local installation_type="$1"
    local paths=()

    case "$installation_type" in
        "claude-code-cli")
            if command -v claude >/dev/null 2>&1; then
                paths+=("$(command -v claude)")
            fi
            ;;
        "claude-python-sdk")
            if [[ -d "$CONFIG_DIR/claude-python-env" ]]; then
                paths+=("$CONFIG_DIR/claude-python-env")
            fi
            ;;
        "claude-typescript-sdk")
            if [[ -d "$CONFIG_DIR/claude-typescript-projects" ]]; then
                paths+=("$CONFIG_DIR/claude-typescript-projects")
            fi
            ;;
        "configuration-files")
            if [[ -f "$CONFIG_DIR/config.json" ]]; then
                paths+=("$CONFIG_DIR/config.json")
            fi
            if [[ -d "$HOME/.claude" ]]; then
                paths+=("$HOME/.claude")
            fi
            ;;
    esac

    printf '%s\n' "${paths[@]}"
}

# Validate installation state
validate_installation_state() {
    local installation_type="$1"

    local validation_errors=()

    case "$installation_type" in
        "claude-code-cli")
            if ! command -v claude >/dev/null 2>&1; then
                validation_errors+=("Claude CLI not found in PATH")
            else
                # Test if CLI works
                if ! claude --version >/dev/null 2>&1; then
                    validation_errors+=("Claude CLI failed to execute")
                fi
            fi
            ;;
        "claude-python-sdk")
            if [[ ! -d "$CONFIG_DIR/claude-python-env" ]]; then
                validation_errors+=("Python SDK virtual environment not found")
            elif [[ ! -f "$CONFIG_DIR/claude-python-env/bin/python" ]]; then
                validation_errors+=("Python SDK virtual environment is incomplete")
            fi
            ;;
        "claude-typescript-sdk")
            if [[ ! -d "$CONFIG_DIR/claude-typescript-projects" ]]; then
                validation_errors+=("TypeScript SDK projects directory not found")
            fi
            ;;
    esac

    if [[ ${#validation_errors[@]} -gt 0 ]]; then
        error "Installation validation failed for $installation_type:"
        for error in "${validation_errors[@]}"; do
            error "  - $error"
        done
        return 1
    fi

    log "Installation validation passed for $installation_type"
    return 0
}

# Generate detection report
generate_detection_report() {
    local report_file="${1:-$CONFIG_DIR/detection-report.txt}"

    detect_all_installations

    {
        echo "Claude Installation Detection Report"
        echo "Generated: $(date)"
        echo "System: $(detect_os) $(detect_arch)"
        echo ""
        echo "Summary:"
        echo "  Total installations found: ${#DETECTED_INSTALLATIONS[@]}"
        echo ""
        echo "Detailed findings:"
        for detail in "${DETECTION_DETAILS[@]}"; do
            echo "  - $detail"
        done
        echo ""
        echo "Detection completed successfully."
    } > "$report_file"

    success "Detection report generated: $report_file"
}

# Export functions
export -f detect_claude_code_cli detect_python_sdk detect_typescript_sdk
export -f detect_configuration_files detect_docker_images
export -f detect_system_integration detect_package_installations detect_custom_installations
export -f detect_all_installations detect_existing_installations
export -f get_installation_info installation_exists get_installation_paths
export -f validate_installation_state generate_detection_report

# Export variables for use in other modules
export DETECTED_INSTALLATIONS DETECTION_DETAILS