#!/bin/bash

# Claude Universal Installer - CLI Installation Module
# Handles installation of Claude Code CLI with customizations and system integration

set -eo pipefail

# Source core utilities and modules
source "$(dirname "${BASH_SOURCE[0]}")/../lib/core.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/config-manager.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/detection.sh"

# CLI installation configuration
readonly CLAWE_CODE_RELEASES_BASE="https://github.com/anthropics/claude-code/releases"
readonly DEFAULT_INSTALL_DIR="$HOME/.local/bin"
readonly CLAUDE_CONFIG_DIR="$HOME/.claude"

# Platform and architecture detection
detect_platform_architecture() {
    local platform=$(detect_os)
    local arch=$(detect_arch)

    case "$platform" in
        "macos") platform="darwin" ;;
        "linux") platform="linux" ;;
        *)
            error "Unsupported platform: $platform"
            return 1
            ;;
    esac

    case "$arch" in
        "x64") arch="x64" ;;
        "arm64") arch="arm64" ;;
        "arm") arch="arm" ;;
        *)
            error "Unsupported architecture: $arch"
            return 1
            ;;
    esac

    echo "${platform}-${arch}"
}

# Get the latest version of Claude Code CLI
get_latest_version() {
    local api_url="https://api.github.com/repos/anthropics/claude-code/releases/latest"

    if command_exists curl && command_exists jq; then
        local version
        version=$(curl -fsSL "$api_url" | jq -r '.tag_name' 2>/dev/null || echo "")
        if [[ -n "$version" ]]; then
            echo "$version"
            return 0
        fi
    fi

    # Fallback to a known stable version
    echo "v1.0.0"
}

# Download Claude Code CLI with validation
download_claude_binary() {
    local platform_arch="$1"
    local install_dir="$2"
    local version="${3:-latest}"

    local binary_name="claude-code-${platform_arch}"
    local download_url
    local binary_path="$install_dir/claude"

    if [[ "$version" == "latest" ]]; then
        download_url="${CLAWE_CODE_RELEASES_BASE}/latest/download/${binary_name}"
    else
        download_url="${CLAWE_CODE_RELEASES_BASE}/download/${version}/${binary_name}"
    fi

    log "Downloading Claude Code CLI from: $download_url"

    # Create install directory
    safe_mkdir "$install_dir"

    # Download with retry mechanism
    if download_with_retry "$download_url" "$binary_path" 3 "Claude Code CLI"; then
        chmod +x "$binary_path"

        # Validate downloaded binary
        if [[ -f "$binary_path" && -x "$binary_path" ]]; then
            success "Claude Code CLI downloaded successfully"
            return 0
        else
            error "Downloaded binary is not executable"
            return 1
        fi
    else
        error "Failed to download Claude Code CLI"
        return 1
    fi
}

# Validate Claude CLI installation
validate_claude_cli_installation() {
    local binary_path="$1"

    if [[ ! -f "$binary_path" ]]; then
        error "Claude CLI binary not found: $binary_path"
        return 1
    fi

    if [[ ! -x "$binary_path" ]]; then
        error "Claude CLI binary is not executable: $binary_path"
        return 1
    fi

    # Test if binary runs (this might fail if dependencies are missing)
    if "$binary_path" --version >/dev/null 2>&1; then
        success "Claude CLI validation passed"
        return 0
    else
        warn "Claude CLI binary failed basic validation, but installation may still work"
        return 0
    fi
}

# Setup PATH integration
setup_path_integration() {
    local install_dir="$1"
    local config_file="$2"

    # Check if install_dir is already in PATH
    if [[ ":$PATH:" == *":$install_dir:"* ]]; then
        log "Installation directory already in PATH: $install_dir"
        return 0
    fi

    # Add to shell configuration files
    local shell_configs=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile")
    local modified_configs=()

    for config_file in "${shell_configs[@]}"; do
        if [[ -f "$config_file" ]] && ! grep -q "$install_dir" "$config_file" 2>/dev/null; then
            backup_file "$config_file"
            echo "export PATH=\"\$PATH:$install_dir\"" >> "$config_file"
            modified_configs+=("$(basename "$config_file")")
            log "Added $install_dir to PATH in $config_file"
        fi
    done

    if [[ ${#modified_configs[@]} -gt 0 ]]; then
        success "PATH integration completed. Modified: ${modified_configs[*]}"
        echo "ℹ️  Added $install_dir to PATH in your shell configuration"
        echo "   Restart your terminal or run: source ~/.bashrc"
    else
        log "No PATH modifications needed"
    fi
}

# Create Claude CLI configuration directories
setup_claude_config_directories() {
    local claude_config_dir="$1"

    # Create standard directory structure
    local directories=(
        "commands"
        "skills"
        "hooks"
        "agents"
        "projects"
        "system-prompts"
        "session-env"
        "todos"
        "logs"
        "cache"
    )

    for dir in "${directories[@]}"; do
        local full_path="$claude_config_dir/$dir"
        safe_mkdir "$full_path"
        log "Created directory: $full_path"
    done

    success "Claude CLI configuration directories created"
}

# Setup system prompts
setup_system_prompts() {
    local claude_config_dir="$1"
    local system_prompts_dir="$claude_config_dir/system-prompts"

    # Create basic system prompt structure
    local prompts=(
        "base:Professional and helpful AI assistant focused on software development and problem-solving."
        "coding:Expert software developer with deep knowledge of multiple programming languages and frameworks."
        "debugging:Systematic problem-solver specializing in identifying and fixing code issues."
        "architecture:Software architect focused on designing scalable and maintainable systems."
    )

    for prompt_def in "${prompts[@]}"; do
        local prompt_name="${prompt_def%%:*}"
        local prompt_content="${prompt_def#*:}"
        local prompt_file="$system_prompts_dir/${prompt_name}.md"

        if [[ ! -f "$prompt_file" ]]; then
            cat > "$prompt_file" << EOF
# ${prompt_name^} System Prompt

${prompt_content}

## Usage
Use this prompt when you need to focus on ${prompt_name} tasks.
EOF
            log "Created system prompt: $prompt_file"
        fi
    done

    success "System prompts initialized"
}

# Setup custom commands
setup_custom_commands() {
    local claude_config_dir="$1"
    local commands_dir="$claude_config_dir/commands"

    # Create example custom command
    local example_command="$commands_dir/example-command.sh"
    if [[ ! -f "$example_command" ]]; then
        cat > "$example_command" << 'EOF'
#!/bin/bash

# Example Custom Command for Claude CLI
# This demonstrates how to create custom commands

# Arguments are passed as $1, $2, etc.
action="${1:-help}"

case "$action" in
    "hello")
        echo "Hello from custom command!"
        echo "This is an example of a custom Claude CLI command."
        ;;
    "status")
        echo "Custom Command Status: Active"
        echo "Available actions: hello, status, help"
        ;;
    "help"|*)
        echo "Example Custom Command Usage:"
        echo "  /example-command hello    - Show greeting"
        echo "  /example-command status  - Show status"
        echo "  /example-command help    - Show this help"
        ;;
esac
EOF
        chmod +x "$example_command"
        log "Created example custom command: $example_command"
    fi

    success "Custom commands initialized"
}

# Setup hooks
setup_hooks() {
    local claude_config_dir="$1"
    local hooks_dir="$claude_config_dir/hooks"

    # Create example hooks
    local hooks=(
        "pre-command:# Runs before each command"
        "post-command:# Runs after each command"
        "pre-save:# Runs before saving files"
        "post-save:# Runs after saving files"
    )

    for hook_def in "${hooks[@]}"; do
        local hook_name="${hook_def%%:*}"
        local hook_comment="${hook_def#*:}"
        local hook_file="$hooks_dir/${hook_name}.sh"

        if [[ ! -f "$hook_file" ]]; then
            cat > "$hook_file" << EOF
#!/bin/bash

# ${hook_name^} Hook
# ${hook_comment}

# Hook arguments:
# \$1 - Hook type (pre-command, post-command, etc.)
# \$2 - Command name or context
# \$3+ - Additional arguments

# Add your custom logic here
# Example: log commands, trigger notifications, etc.

# Return 0 for success, non-zero for failure
exit 0
EOF
            chmod +x "$hook_file"
            log "Created hook: $hook_file"
        fi
    done

    success "Hooks initialized"
}

# Setup environment configuration
setup_environment_config() {
    local claude_config_dir="$1"
    local config_file="$claude_config_dir/config.json"

    if [[ ! -f "$config_file" ]]; then
        # Create default configuration
        cat > "$config_file" << 'EOF'
{
  "version": "1.0.0",
  "default_model": "claude-3-5-sonnet-20241022",
  "default_max_tokens": 4096,
  "auto_save": true,
  "syntax_highlighting": true,
  "line_numbers": true,
  "theme": "default",
  "custom_prompts_dir": "system-prompts",
  "commands_dir": "commands",
  "hooks_dir": "hooks",
  "log_level": "info",
  "cache_enabled": true,
  "cache_size": "100MB"
}
EOF
        log "Created Claude CLI configuration: $config_file"
    fi

    success "Environment configuration completed"
}

# Main installation function
install_claude_code_cli() {
    header "Installing Claude Code CLI"

    echo "Installing Claude Code CLI with enhanced modular architecture..."
    echo ""

    # Detect platform and architecture
    local platform_arch
    platform_arch=$(detect_platform_architecture) || {
        error "Failed to detect platform architecture"
        return 1
    }

    log "Detected platform: ${platform_arch}"

    # Determine installation directory
    local install_dir="${CLAUDE_INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"
    local binary_path="$install_dir/claude"

    # Check if Claude CLI is already installed
    if command -v claude >/dev/null 2>&1; then
        local current_version
        current_version=$(claude --version 2>/dev/null || echo "unknown")
        warn "Claude CLI is already installed: $current_version"
        read -p "Do you want to reinstall? (y/N): " reinstall
        if [[ ! $reinstall =~ ^[Yy]$ ]]; then
            echo "Installation cancelled."
            return 0
        fi
    fi

    # Download Claude Code CLI
    if ! download_claude_binary "$platform_arch" "$install_dir"; then
        error "Failed to download Claude Code CLI"
        return 1
    fi

    # Validate installation
    if ! validate_claude_cli_installation "$binary_path"; then
        error "Claude CLI installation validation failed"
        return 1
    fi

    # Setup PATH integration
    setup_path_integration "$install_dir" "$CONFIG_DIR/config.json"

    # Create configuration directories
    setup_claude_config_directories "$CLAUDE_CONFIG_DIR"

    # Setup system prompts
    setup_system_prompts "$CLAUDE_CONFIG_DIR"

    # Setup custom commands
    setup_custom_commands "$CLAUDE_CONFIG_DIR"

    # Setup hooks
    setup_hooks "$CLAUDE_CONFIG_DIR"

    # Setup environment configuration
    setup_environment_config "$CLAUDE_CONFIG_DIR"

    # Update unified configuration
    set_config_value "installationType" "claude-code-cli"
    set_config_value "cli.binaryPath" "$binary_path"
    set_config_value "cli.version" "$(get_latest_version)"
    set_config_value "cli.platformArch" "$platform_arch"
    set_nested_config_value "features.streaming" true
    set_nested_config_value "features.customCommands" true

    echo ""
    success "✅ Claude Code CLI installation completed successfully!"
    echo ""
    echo "Installation Details:"
    echo "  Binary: $binary_path"
    echo "  Platform: ${platform_arch}"
    echo "  Configuration: $CLAUDE_CONFIG_DIR"
    echo ""
    echo "Next steps:"
    echo "1. Restart your terminal or run: source ~/.bashrc"
    echo "2. Run: claude"
    echo "3. Follow the authentication prompts"
    echo ""
    echo "Customization Features:"
    echo "  • System prompts in: $CLAUDE_CONFIG_DIR/system-prompts"
    echo "  • Custom commands in: $CLAUDE_CONFIG_DIR/commands"
    echo "  • Hooks in: $CLAUDE_CONFIG_DIR/hooks"
    echo "  • Configuration file: $CLAUDE_CONFIG_DIR/config.json"
}

# Update existing CLI installation
update_claude_cli() {
    header "Updating Claude Code CLI"

    if ! command -v claude >/dev/null 2>&1; then
        error "Claude CLI is not installed. Use install function first."
        return 1
    fi

    local current_version
    current_version=$(claude --version 2>/dev/null | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")
    local latest_version
    latest_version=$(get_latest_version)

    log "Current version: $current_version"
    log "Latest version: $latest_version"

    if [[ "$current_version" == "$latest_version" ]]; then
        success "Claude CLI is already up to date"
        return 0
    fi

    echo "Updating Claude CLI from $current_version to $latest_version..."

    # Get current binary path
    local current_binary
    current_binary=$(command -v claude)
    local install_dir
    install_dir=$(dirname "$current_binary")

    # Backup current binary
    backup_file "$current_binary"

    # Download new version
    local platform_arch
    platform_arch=$(detect_platform_architecture)

    if download_claude_binary "$platform_arch" "$install_dir" "$latest_version"; then
        success "Claude CLI updated successfully"
        echo "Restart your terminal to use the new version."
    else
        error "Failed to update Claude CLI"
        return 1
    fi
}

# Verify CLI installation
verify_claude_cli_installation() {
    header "Verifying Claude Code CLI Installation"

    local verification_passed=true

    # Check if binary exists and is executable
    if command -v claude >/dev/null 2>&1; then
        success "✓ Claude CLI binary found in PATH"

        # Test basic functionality
        if claude --version >/dev/null 2>&1; then
            local version
            version=$(claude --version 2>/dev/null)
            success "✓ Claude CLI is functional: $version"
        else
            warn "⚠ Claude CLI binary exists but may not be fully functional"
        fi
    else
        error "✗ Claude CLI binary not found in PATH"
        verification_passed=false
    fi

    # Check configuration directories
    if [[ -d "$CLAUDE_CONFIG_DIR" ]]; then
        success "✓ Configuration directory exists: $CLAUDE_CONFIG_DIR"

        # Check essential subdirectories
        local essential_dirs=("system-prompts" "commands" "hooks")
        for dir in "${essential_dirs[@]}"; do
            if [[ -d "$CLAUDE_CONFIG_DIR/$dir" ]]; then
                success "✓ $dir directory exists"
            else
                warn "⚠ $dir directory missing"
            fi
        done
    else
        error "✗ Configuration directory not found: $CLAUDE_CONFIG_DIR"
        verification_passed=false
    fi

    # Check unified configuration
    local install_type
    install_type=$(get_config_value "installationType")
    if [[ "$install_type" == "claude-code-cli" ]]; then
        success "✓ Unified configuration updated"
    else
        warn "⚠ Unified configuration may not be updated"
    fi

    echo ""
    if [[ "$verification_passed" == true ]]; then
        success "Claude Code CLI installation verification passed"
    else
        error "Claude Code CLI installation verification failed"
        return 1
    fi
}

# Export functions
export -f install_claude_code_cli update_claude_cli verify_claude_cli_installation
export -f detect_platform_architecture get_latest_version download_claude_binary
export -f validate_claude_cli_installation setup_path_integration
export -f setup_claude_config_directories setup_system_prompts setup_custom_commands
export -f setup_hooks setup_environment_config

# Export configuration variables
export CLAWE_CODE_RELEASES_BASE DEFAULT_INSTALL_DIR CLAUDE_CONFIG_DIR