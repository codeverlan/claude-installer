#!/bin/bash

# Claude Universal Installer - Uninstaller Module
# Handles removal of all Claude installations and components

set -euo pipefail

# Source core utilities and detection
source "$(dirname "${BASH_SOURCE[0]}")/../lib/core.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/detection.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/config-manager.sh"

# Uninstall tracking
declare -a UNINSTALL_ACTIONS=()
declare -a UNINSTALL_RESULTS=()
declare UNINSTALL_BACKUP_DIR=""

# Create backup directory for uninstall safety
create_uninstall_backup() {
    UNINSTALL_BACKUP_DIR="${CONFIG_DIR}/uninstall-backup-$(date +%Y%m%d_%H%M%S)"
    safe_mkdir "$UNINSTALL_BACKUP_DIR"

    log "Created uninstall backup directory: $UNINSTALL_BACKUP_DIR"
}

# Backup file before removal
backup_file() {
    local source_file="$1"
    local backup_name="${2:-$(basename "$source_file")}"

    if [[ -f "$source_file" ]]; then
        local backup_path="$UNINSTALL_BACKUP_DIR/$backup_name"
        cp "$source_file" "$backup_path" || {
            warn "Failed to backup file: $source_file"
            return 1
        }
        log "Backed up file: $source_file -> $backup_path"
    fi
}

# Backup directory before removal
backup_directory() {
    local source_dir="$1"
    local backup_name="${2:-$(basename "$source_dir")}"

    if [[ -d "$source_dir" ]]; then
        local backup_path="$UNINSTALL_BACKUP_DIR/$backup_name"
        cp -r "$source_dir" "$backup_path" || {
            warn "Failed to backup directory: $source_dir"
            return 1
        }
        log "Backed up directory: $source_dir -> $backup_path"
    fi
}

# Uninstall Claude Code CLI
uninstall_claude_code_cli() {
    log "Starting Claude Code CLI uninstallation..."

    local uninstalled=false

    # Find and remove CLI binary
    if command -v claude >/dev/null 2>&1; then
        local claude_path
        claude_path=$(command -v claude)

        # Backup before removal
        backup_file "$claude_path" "claude-binary"

        # Remove binary
        if rm -f "$claude_path"; then
            UNINSTALL_ACTIONS+=("Removed CLI binary: $claude_path")
            UNINSTALL_RESULTS+=("✓ Claude Code CLI binary removed")
            uninstalled=true
        else
            UNINSTALL_RESULTS+=("✗ Failed to remove CLI binary: $claude_path")
        fi
    fi

    # Remove from PATH in shell configurations
    local shell_configs=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile" "$HOME/.bash_profile")

    for config_file in "${shell_configs[@]}"; do
        if [[ -f "$config_file" ]]; then
            # Check for Claude PATH modifications
            if grep -q "claude" "$config_file" 2>/dev/null; then
                backup_file "$config_file" "shell-config-$(basename "$config_file")"

                # Remove Claude-related lines
                if sed -i.tmp '/claude/d' "$config_file" 2>/dev/null; then
                    rm -f "$config_file.tmp"
                    UNINSTALL_ACTIONS+=("Removed Claude references from $config_file")
                    UNINSTALL_RESULTS+=("✓ Removed PATH modifications from $(basename "$config_file")")
                else
                    UNINSTALL_RESULTS+=("✗ Failed to modify $(basename "$config_file")")
                fi
            fi
        fi
    done

    # Remove Claude CLI configuration
    if [[ -d "$HOME/.claude" ]]; then
        backup_directory "$HOME/.claude" "claude-cli-config"

        if rm -rf "$HOME/.claude"; then
            UNINSTALL_ACTIONS+=("Removed Claude CLI configuration directory")
            UNINSTALL_RESULTS+=("✓ Claude CLI configuration removed")
        else
            UNINSTALL_RESULTS+=("✗ Failed to remove Claude CLI configuration")
        fi
    fi

    # Remove systemd services (if any)
    if command_exists systemctl; then
        local services=("claude.service" "claude-daemon.service")
        for service in "${services[@]}"; do
            if systemctl list-unit-files | grep -q "$service"; then
                if sudo systemctl stop "$service" 2>/dev/null; then
                    sudo systemctl disable "$service" 2>/dev/null || true
                    sudo rm -f "/etc/systemd/system/$service" 2>/dev/null || true
                    sudo systemctl daemon-reload 2>/dev/null || true
                    UNINSTALL_ACTIONS+=("Removed systemd service: $service")
                    UNINSTALL_RESULTS+=("✓ Systemd service removed: $service")
                fi
            fi
        done
    fi

    if [[ "$uninstalled" = true ]]; then
        success "Claude Code CLI uninstalled successfully"
    else
        warn "No Claude Code CLI installation found to remove"
    fi
}

# Uninstall Python SDK
uninstall_claude_python_sdk() {
    log "Starting Python SDK uninstallation..."

    local python_env_dir="$CONFIG_DIR/claude-python-env"
    local uninstalled=false

    if [[ -d "$python_env_dir" ]]; then
        backup_directory "$python_env_dir" "python-sdk-env"

        # Deactivate virtual environment if active
        if [[ "${VIRTUAL_ENV:-}" == "$python_env_dir" ]]; then
            deactivate 2>/dev/null || true
        fi

        # Remove virtual environment
        if rm -rf "$python_env_dir"; then
            UNINSTALL_ACTIONS+=("Removed Python SDK virtual environment")
            UNINSTALL_RESULTS+=("✓ Python SDK environment removed")
            uninstalled=true
        else
            UNINSTALL_RESULTS+=("✗ Failed to remove Python SDK environment")
        fi
    fi

    # Remove Python SDK activation scripts
    local activation_scripts=(
        "$CONFIG_DIR/activate-python.sh"
        "$CONFIG_DIR/claude-python-create"
    )

    for script in "${activation_scripts[@]}"; do
        if [[ -f "$script" ]]; then
            backup_file "$script" "python-sdk-script-$(basename "$script")"

            if rm -f "$script"; then
                UNINSTALL_ACTIONS+=("Removed Python SDK script: $(basename "$script")")
                UNINSTALL_RESULTS+=("✓ Removed $(basename "$script")")
            fi
        fi
    done

    # Remove Python projects created by installer
    local python_projects_dir="$CONFIG_DIR/claude-python-projects"
    if [[ -d "$python_projects_dir" ]]; then
        backup_directory "$python_projects_dir" "python-sdk-projects"

        if rm -rf "$python_projects_dir"; then
            UNINSTALL_ACTIONS+=("Removed Python SDK projects directory")
            UNINSTALL_RESULTS+=("✓ Python SDK projects removed")
        fi
    fi

    if [[ "$uninstalled" = true ]]; then
        success "Python SDK uninstalled successfully"
    else
        warn "No Python SDK installation found to remove"
    fi
}

# Uninstall TypeScript SDK
uninstall_claude_typescript_sdk() {
    log "Starting TypeScript SDK uninstallation..."

    local ts_projects_dir="$CONFIG_DIR/claude-typescript-projects"
    local uninstalled=false

    if [[ -d "$ts_projects_dir" ]]; then
        backup_directory "$ts_projects_dir" "typescript-sdk-projects"

        if rm -rf "$ts_projects_dir"; then
            UNINSTALL_ACTIONS+=("Removed TypeScript SDK projects directory")
            UNINSTALL_RESULTS+=("✓ TypeScript SDK projects removed")
            uninstalled=true
        else
            UNINSTALL_RESULTS+=("✗ Failed to remove TypeScript SDK projects")
        fi
    fi

    # Remove TypeScript project creation script
    local create_script="$ts_projects_dir/create-project.sh"
    if [[ -f "$create_script" ]]; then
        backup_file "$create_script" "typescript-create-script"

        if rm -f "$create_script"; then
            UNINSTALL_ACTIONS+=("Removed TypeScript project creation script")
            UNINSTALL_RESULTS+=("✓ Removed create-project.sh")
        fi
    fi

    if [[ "$uninstalled" = true ]]; then
        success "TypeScript SDK uninstalled successfully"
    else
        warn "No TypeScript SDK installation found to remove"
    fi
}

# Remove Docker images and containers
uninstall_docker_components() {
    log "Removing Docker components..."

    if command_exists docker; then
        # Stop and remove Claude containers
        local containers
        containers=$(docker ps -aq --filter "name=claude" 2>/dev/null || true)

        if [[ -n "$containers" ]]; then
            if docker stop $containers >/dev/null 2>&1; then
                docker rm $containers >/dev/null 2>&1 || true
                UNINSTALL_ACTIONS+=("Stopped and removed Claude containers")
                UNINSTALL_RESULTS+=("✓ Docker containers removed")
            fi
        fi

        # Remove Claude images
        local images
        images=$(docker images -q --filter "reference=*claude*" 2>/dev/null || true)

        if [[ -n "$images" ]]; then
            if docker rmi $images >/dev/null 2>&1; then
                UNINSTALL_ACTIONS+=("Removed Claude Docker images")
                UNINSTALL_RESULTS+=("✓ Docker images removed")
            fi
        fi

        # Remove Docker volumes
        local volumes
        volumes=$(docker volume ls -q --filter "name=claude" 2>/dev/null || true)

        if [[ -n "$volumes" ]]; then
            if docker volume rm $volumes >/dev/null 2>&1; then
                UNINSTALL_ACTIONS+=("Removed Claude Docker volumes")
                UNINSTALL_RESULTS+=("✓ Docker volumes removed")
            fi
        fi
    else
        UNINSTALL_RESULTS+=("- Docker not available, skipping Docker cleanup")
    fi
}

# Remove package manager installations
uninstall_package_installations() {
    log "Removing package manager installations..."

    # Homebrew
    if command_exists brew && brew list --formula 2>/dev/null | grep -q claude; then
        if brew uninstall claude 2>/dev/null; then
            UNINSTALL_ACTIONS+=("Removed Homebrew package")
            UNINSTALL_RESULTS+=("✓ Homebrew package removed")
        else
            UNINSTALL_RESULTS+=("✗ Failed to remove Homebrew package")
        fi
    fi

    # APT (Debian/Ubuntu)
    if command_exists apt && dpkg -l 2>/dev/null | grep -q claude; then
        if sudo apt remove --purge claude -y 2>/dev/null; then
            UNINSTALL_ACTIONS+=("Removed APT package")
            UNINSTALL_RESULTS+=("✓ APT package removed")
        else
            UNINSTALL_RESULTS+=("✗ Failed to remove APT package")
        fi
    fi

    # YUM/DNF (RedHat/CentOS/Fedora)
    if command_exists yum && rpm -qa 2>/dev/null | grep -q claude; then
        if sudo yum remove claude -y 2>/dev/null; then
            UNINSTALL_ACTIONS+=("Removed YUM package")
            UNINSTALL_RESULTS+=("✓ YUM package removed")
        else
            UNINSTALL_RESULTS+=("✗ Failed to remove YUM package")
        fi
    fi

    # DNF (Fedora)
    if command_exists dnf && rpm -qa 2>/dev/null | grep -q claude; then
        if sudo dnf remove claude -y 2>/dev/null; then
            UNINSTALL_ACTIONS+=("Removed DNF package")
            UNINSTALL_RESULTS+=("✓ DNF package removed")
        else
            UNINSTALL_RESULTS+=("✗ Failed to remove DNF package")
        fi
    fi
}

# Clean up common files and configurations
cleanup_common_files() {
    log "Cleaning up common files..."

    # Remove main configuration directory
    if [[ -d "$CONFIG_DIR" ]]; then
        # Backup config before removal (unless it's the uninstall backup dir itself)
        if [[ "$CONFIG_DIR" != "$UNINSTALL_BACKUP_DIR" ]]; then
            backup_directory "$CONFIG_DIR" "main-config-dir"
        fi

        # Remove all contents except uninstall backups
        find "$CONFIG_DIR" -mindepth 1 -maxdepth 1 ! -name "uninstall-backup-*" -exec rm -rf {} \; 2>/dev/null || true

        UNINSTALL_ACTIONS+=("Cleaned configuration directory")
        UNINSTALL_RESULTS+=("✓ Configuration files cleaned")
    fi

    # Remove log files
    local log_files=(
        "$HOME/.claude-universal.log"
        "$HOME/.claude-install.log"
        "$HOME/claude-installer.log"
    )

    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            backup_file "$log_file" "log-file-$(basename "$log_file")"
            rm -f "$log_file"
            UNINSTALL_ACTIONS+=("Removed log file: $(basename "$log_file")")
        fi
    done

    # Remove temporary files
    local temp_patterns=(
        "/tmp/claude-*"
        "/tmp/claude-installer-*"
        "$HOME/.claude-temp-*"
    )

    for pattern in "${temp_patterns[@]}"; do
        if ls $pattern 1> /dev/null 2>&1; then
            rm -rf $pattern 2>/dev/null || true
            UNINSTALL_ACTIONS+=("Removed temporary files")
        fi
    done
}

# Generate uninstall report
generate_uninstall_report() {
    local report_file="$UNINSTALL_BACKUP_DIR/uninstall-report.txt"

    {
        echo "Claude Uninstallation Report"
        echo "Generated: $(date)"
        echo "System: $(detect_os) $(detect_arch)"
        echo ""
        echo "Uninstall Actions Performed:"
        if [[ ${#UNINSTALL_ACTIONS[@]} -gt 0 ]]; then
            for action in "${UNINSTALL_ACTIONS[@]}"; do
                echo "  - $action"
            done
        else
            echo "  No actions performed"
        fi
        echo ""
        echo "Uninstall Results:"
        if [[ ${#UNINSTALL_RESULTS[@]} -gt 0 ]]; then
            for result in "${UNINSTALL_RESULTS[@]}"; do
                echo "  $result"
            done
        else
            echo "  No results recorded"
        fi
        echo ""
        echo "Backup Location: $UNINSTALL_BACKUP_DIR"
        echo ""
        echo "To restore any files, copy them from the backup directory."
    } > "$report_file"

    success "Uninstall report generated: $report_file"
}

# Main uninstall function
uninstall_claude() {
    header "Uninstalling Claude"

    # Detect existing installations with detailed information
    detect_all_installations

    if [[ ${#DETECTED_INSTALLATIONS[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No Claude installations found to uninstall.${NC}"
        echo ""
        echo "Checked locations:"
        echo "• Claude Code CLI binary in PATH"
        echo "• Python SDK virtual environment"
        echo "• TypeScript SDK projects"
        echo "• Configuration files in $CONFIG_DIR"
        echo "• Docker images with 'claude' in name"
        echo "• Package manager installations"
        echo ""
        echo "If you believe Claude is installed, it may be in a custom location."
        return 0
    fi

    # Display found installations
    echo -e "${GREEN}Found the following Claude installations to uninstall:${NC}"
    echo ""
    for detail in "${DETECTION_DETAILS[@]}"; do
        echo -e "${CYAN}✓${NC} $detail"
    done
    echo ""

    # Get user confirmation
    read -p "Do you want to uninstall all found installations? (y/N): " confirm_uninstall
    if [[ ! $confirm_uninstall =~ ^[Yy]$ ]]; then
        echo "Uninstall cancelled."
        return 0
    fi

    # Create backup for safety
    create_uninstall_backup

    echo ""
    echo "Starting uninstall process..."
    echo "All files will be backed up to: $UNINSTALL_BACKUP_DIR"
    echo ""

    # Perform uninstallation
    uninstall_claude_code_cli
    uninstall_claude_python_sdk
    uninstall_claude_typescript_sdk
    uninstall_docker_components
    uninstall_package_installations
    cleanup_common_files

    # Generate report
    generate_uninstall_report

    echo ""
    header "Uninstall Summary"
    echo "Total actions performed: ${#UNINSTALL_ACTIONS[@]}"
    echo "Backup location: $UNINSTALL_BACKUP_DIR"
    echo ""
    echo "Results:"
    for result in "${UNINSTALL_RESULTS[@]}"; do
        echo "  $result"
    done
    echo ""

    if [[ ${#UNINSTALL_ACTIONS[@]} -gt 0 ]]; then
        success "Claude uninstallation completed successfully"
        echo ""
        echo "Important notes:"
        echo "• All Claude components have been removed"
        echo "• Backup files are stored in: $UNINSTALL_BACKUP_DIR"
        echo "• You may need to restart your terminal or run 'source ~/.bashrc' to update PATH"
        echo "• Check the uninstall report in the backup directory for details"
    else
        warn "No components were removed during uninstallation"
    fi
}

# Selective uninstall (specific components)
uninstall_component() {
    local component="$1"

    case "$component" in
        "cli")
            uninstall_claude_code_cli
            ;;
        "python")
            uninstall_claude_python_sdk
            ;;
        "typescript")
            uninstall_claude_typescript_sdk
            ;;
        "docker")
            uninstall_docker_components
            ;;
        "packages")
            uninstall_package_installations
            ;;
        "cleanup")
            cleanup_common_files
            ;;
        *)
            error "Unknown component: $component"
            echo "Available components: cli, python, typescript, docker, packages, cleanup"
            return 1
            ;;
    esac
}

# Export functions
export -f uninstall_claude uninstall_component
export -f uninstall_claude_code_cli uninstall_claude_python_sdk uninstall_claude_typescript_sdk
export -f uninstall_docker_components uninstall_package_installations cleanup_common_files
export -f create_uninstall_backup backup_file backup_directory
export -f generate_uninstall_report

# Export variables
export UNINSTALL_ACTIONS UNINSTALL_RESULTS UNINSTALL_BACKUP_DIR