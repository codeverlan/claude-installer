#!/bin/bash

# Claude Universal Installer - Rollback and Recovery Module
# Provides transaction-style installation with automatic rollback capabilities

set -eo pipefail

# Source core utilities and security
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"
source "$(dirname "${BASH_SOURCE[0]}")/security.sh"

# Rollback configuration
readonly ROLLBACK_DIR="$CONFIG_DIR/rollback"
readonly ROLLBACK_LOG="$ROLLBACK_DIR/rollback.log"
readonly MAX_ROLLBACK_POINTS=50

# Transaction state
declare -a ROLLBACK_STACK=()
declare -A TRANSACTION_STATE=(
    ["active"]="false"
    ["current_operation"]=""
    ["rollback_points"]=0
    ["last_error"]=""
)

# Initialize rollback system
init_rollback_system() {
    log "Initializing rollback and recovery system..."

    # Create rollback directory
    safe_mkdir "$ROLLBACK_DIR"
    touch "$ROLLBACK_LOG"

    # Set secure permissions
    chmod 700 "$ROLLBACK_DIR" 2>/dev/null || true
    chmod 600 "$ROLLBACK_LOG" 2>/dev/null || true

    # Initialize transaction state
    TRANSACTION_STATE["active"]="false"
    TRANSACTION_STATE["rollback_points"]=0

    # Cleanup old rollback points (keep only recent ones)
    cleanup_old_rollback_points

    success "Rollback system initialized"
}

# Start a new transaction
begin_transaction() {
    local operation_name="$1"
    local description="${2:-Transaction for $operation_name}"

    if [[ "${TRANSACTION_STATE[active]}" == "true" ]]; then
        warn "Transaction already active: ${TRANSACTION_STATE[current_operation]}"
        rollback_transaction
    fi

    log "Starting transaction: $operation_name"
    log "Description: $description"

    # Initialize transaction state
    TRANSACTION_STATE["active"]="true"
    TRANSACTION_STATE["current_operation"]="$operation_name"
    TRANSACTION_STATE["rollback_points"]=0
    TRANSACTION_STATE["last_error"]=""

    # Clear rollback stack for new transaction
    ROLLBACK_STACK=()

    # Log transaction start
    echo "$(date '+%Y-%m-%d %H:%M:%S') [BEGIN] $operation_name: $description" >> "$ROLLBACK_LOG"

    success "Transaction started: $operation_name"
}

# Create a rollback point
create_rollback_point() {
    local operation_name="$1"
    local description="${2:-Rollback point for $operation_name}"
    local backup_type="${3:-file}"

    if [[ "${TRANSACTION_STATE[active]}" != "true" ]]; then
        warn "Cannot create rollback point outside of transaction"
        return 1
    fi

    local rollback_point_id="${#ROLLBACK_STACK[@]}"
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local rollback_point_dir="$ROLLBACK_DIR/point_${rollback_point_id}_${timestamp}"

    # Create rollback point directory
    safe_mkdir "$rollback_point_dir"

    # Store rollback point information
    local rollback_info="{
        \"id\": $rollback_point_id,
        \"operation\": \"$operation_name\",
        \"description\": \"$description\",
        \"type\": \"$backup_type\",
        \"timestamp\": \"$timestamp\",
        \"directory\": \"$rollback_point_dir\"
    }"

    echo "$rollback_info" > "$rollback_point_dir/info.json"

    # Add to rollback stack
    ROLLBACK_STACK+=("$rollback_point_id:$operation_name:$description:$backup_type:$rollback_point_dir")
    ((TRANSACTION_STATE[rollback_points]++))

    log "Created rollback point $rollback_point_id: $operation_name"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [POINT] $rollback_point_id: $operation_name" >> "$ROLLBACK_LOG"

    echo "$rollback_point_id"
}

# Backup file for rollback
backup_file_for_rollback() {
    local file_path="$1"
    local rollback_point_id="$2"
    local description="${3:-Backup of $(basename "$file_path")}"

    if [[ ! -f "$file_path" ]]; then
        log "File does not exist, no backup needed: $file_path"
        return 0
    fi

    # Find rollback point directory
    local rollback_point_dir=""
    for rollback_info in "${ROLLBACK_STACK[@]}"; do
        local current_id="${rollback_info%%:*}"
        if [[ "$current_id" == "$rollback_point_id" ]]; then
            rollback_point_dir="${rollback_info##*:}"
            break
        fi
    done

    if [[ -z "$rollback_point_dir" || ! -d "$rollback_point_dir" ]]; then
        error "Rollback point directory not found: $rollback_point_id"
        return 1
    fi

    # Create backup
    local backup_file="$rollback_point_dir/$(basename "$file_path").backup"
    local relative_path="${file_path#$HOME/}"

    # Store original path
    echo "$file_path" > "$rollback_point_dir/original_path.txt"

    # Copy file
    if cp "$file_path" "$backup_file"; then
        chmod 600 "$backup_file" 2>/dev/null || true
        log "File backed up for rollback: $file_path -> $backup_file"

        # Store backup metadata
        local backup_metadata="{
            \"original_path\": \"$file_path\",
            \"backup_path\": \"$backup_file\",
            \"relative_path\": \"$relative_path\",
            \"description\": \"$description\",
            \"timestamp\": \"$(date -Iseconds)\",
            \"size\": \"$(stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null || echo "unknown")\"
        }"

        echo "$backup_metadata" > "$backup_file.metadata.json"

        return 0
    else
        error "Failed to backup file for rollback: $file_path"
        return 1
    fi
}

# Backup directory for rollback
backup_directory_for_rollback() {
    local dir_path="$1"
    local rollback_point_id="$2"
    local description="${3:-Backup of $(basename "$dir_path")}"

    if [[ ! -d "$dir_path" ]]; then
        log "Directory does not exist, no backup needed: $dir_path"
        return 0
    fi

    # Find rollback point directory
    local rollback_point_dir=""
    for rollback_info in "${ROLLBACK_STACK[@]}"; do
        local current_id="${rollback_info%%:*}"
        if [[ "$current_id" == "$rollback_point_id" ]]; then
            rollback_point_dir="${rollback_info##*:}"
            break
        fi
    done

    if [[ -z "$rollback_point_dir" || ! -d "$rollback_point_dir" ]]; then
        error "Rollback point directory not found: $rollback_point_id"
        return 1
    fi

    # Create backup directory
    local backup_dir="$rollback_point_dir/$(basename "$dir_path").backup"
    local relative_path="${dir_path#$HOME/}"

    # Store original path
    echo "$dir_path" > "$rollback_point_dir/original_dir_path.txt"

    # Copy directory recursively
    if cp -r "$dir_path" "$backup_dir"; then
        # Fix permissions
        find "$backup_dir" -type f -exec chmod 600 {} \; 2>/dev/null || true
        find "$backup_dir" -type d -exec chmod 700 {} \; 2>/dev/null || true
        log "Directory backed up for rollback: $dir_path -> $backup_dir"

        # Store backup metadata
        local backup_metadata="{
            \"original_path\": \"$dir_path\",
            \"backup_path\": \"$backup_dir\",
            \"relative_path\": \"$relative_path\",
            \"description\": \"$description\",
            \"timestamp\": \"$(date -Iseconds)\",
            \"file_count\": \"$(find \"$backup_dir" -type f | wc -l | tr -d ' ')\"
        }"

        echo "$backup_metadata" > "$backup_dir.metadata.json"

        return 0
    else
        error "Failed to backup directory for rollback: $dir_path"
        return 1
    fi
}

# Backup command execution for rollback
backup_command_for_rollback() {
    local command="$1"
    local rollback_point_id="$2"
    local description="${3:-Command execution backup}"

    # Find rollback point directory
    local rollback_point_dir=""
    for rollback_info in "${ROLLBACK_STACK[@]}"; do
        local current_id="${rollback_info%%:*}"
        if [[ "$current_id" == "$rollback_point_id" ]]; then
            rollback_point_dir="${rollback_info##*:}"
            break
        fi
    done

    if [[ -z "$rollback_point_dir" || ! -d "$rollback_point_dir" ]]; then
        error "Rollback point directory not found: $rollback_point_id"
        return 1
    fi

    # Store command information
    local command_info="{
        \"command\": \"$command\",
        \"description\": \"$description\",
        \"timestamp\": \"$(date -Iseconds)\",
        \"working_directory\": \"$(pwd)\",
        \"user\": \"$USER\"
    }"

    echo "$command_info" > "$rollback_point_dir/command.json"

    # Store undo command if possible
    local undo_command=""
    case "$command" in
        "mkdir "*)
            local dir_path="${command#mkdir }"
            undo_command="rmdir \"$dir_path\" 2>/dev/null || rm -rf \"$dir_path\""
            ;;
        "cp "*)
            local source_file=$(echo "$command" | awk '{print $2}')
            local dest_file=$(echo "$command" | awk '{print $3}')
            undo_command="rm -f \"$dest_file\""
            ;;
        "mv "*)
            local source_file=$(echo "$command" | awk '{print $2}')
            local dest_file=$(echo "$command" | awk '{print $3}')
            undo_command="mv \"$dest_file\" \"$source_file\""
            ;;
        "ln "*)
            local link_target=$(echo "$command" | awk '{print $2}')
            local link_path=$(echo "$command" | awk '{print $3}')
            undo_command="rm -f \"$link_path\""
            ;;
    esac

    if [[ -n "$undo_command" ]]; then
        echo "$undo_command" > "$rollback_point_dir/undo_command.sh"
        chmod +x "$rollback_point_dir/undo_command.sh"
        log "Undo command stored for: $command"
    fi

    log "Command backed up for rollback: $command"
}

# Rollback to a specific point
rollback_to_point() {
    local rollback_point_id="$1"

    if [[ -z "$rollback_point_id" ]]; then
        error "Rollback point ID is required"
        return 1
    fi

    log "Rolling back to point: $rollback_point_id"

    # Find rollback point directory
    local rollback_point_dir=""
    local rollback_info=""
    for info in "${ROLLBACK_STACK[@]}"; do
        local current_id="${info%%:*}"
        if [[ "$current_id" == "$rollback_point_id" ]]; then
            rollback_info="$info"
            rollback_point_dir="${info##*:}"
            break
        fi
    done

    if [[ -z "$rollback_point_dir" || ! -d "$rollback_point_dir" ]]; then
        error "Rollback point not found: $rollback_point_id"
        return 1
    fi

    local rollback_errors=0

    # Restore files
    for backup_file in "$rollback_point_dir"/*.backup; do
        if [[ -f "$backup_file" ]]; then
            local original_path
            original_path=$(cat "$rollback_point_dir/original_path.txt" 2>/dev/null)

            if [[ -n "$original_path" && -f "$backup_file" ]]; then
                log "Restoring file: $backup_file -> $original_path"
                if cp "$backup_file" "$original_path"; then
                    success "File restored: $original_path"
                else
                    error "Failed to restore file: $original_path"
                    ((rollback_errors++))
                fi
            fi
        fi
    done

    # Restore directories
    for backup_dir in "$rollback_point_dir"/*.backup; do
        if [[ -d "$backup_dir" ]]; then
            local original_path
            original_path=$(cat "$rollback_point_dir/original_dir_path.txt" 2>/dev/null)

            if [[ -n "$original_path" && -d "$backup_dir" ]]; then
                log "Restoring directory: $backup_dir -> $original_path"
                if rm -rf "$original_path" 2>/dev/null && cp -r "$backup_dir" "$original_path"; then
                    success "Directory restored: $original_path"
                else
                    error "Failed to restore directory: $original_path"
                    ((rollback_errors++))
                fi
            fi
        fi
    done

    # Execute undo command if available
    local undo_command="$rollback_point_dir/undo_command.sh"
    if [[ -f "$undo_command" && -x "$undo_command" ]]; then
        log "Executing undo command"
        if "$undo_command"; then
            success "Undo command executed successfully"
        else
            error "Undo command failed"
            ((rollback_errors++))
        fi
    fi

    # Log rollback completion
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ROLLBACK] $rollback_point_id: $rollback_errors errors" >> "$ROLLBACK_LOG"

    if [[ $rollback_errors -eq 0 ]]; then
        success "Rollback to point $rollback_point_id completed successfully"
    else
        error "Rollback completed with $rollback_errors errors"
        return 1
    fi
}

# Rollback entire transaction
rollback_transaction() {
    if [[ "${TRANSACTION_STATE[active]}" != "true" ]]; then
        warn "No active transaction to rollback"
        return 0
    fi

    local operation_name="${TRANSACTION_STATE[current_operation]}"
    log "Rolling back transaction: $operation_name"

    local rollback_errors=0

    # Rollback in reverse order (LIFO)
    for ((i=${#ROLLBACK_STACK[@]}-1; i>=0; i--)); do
        local rollback_info="${ROLLBACK_STACK[$i]}"
        local rollback_point_id="${rollback_info%%:*}"

        if ! rollback_to_point "$rollback_point_id"; then
            ((rollback_errors++))
        fi
    done

    # Clear transaction state
    TRANSACTION_STATE["active"]="false"
    TRANSACTION_STATE["current_operation"]=""
    TRANSACTION_STATE["rollback_points"]=0
    ROLLBACK_STACK=()

    # Log transaction rollback
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ROLLBACK_TX] $operation_name: $rollback_errors errors" >> "$ROLLBACK_LOG"

    if [[ $rollback_errors -eq 0 ]]; then
        success "Transaction rollback completed successfully"
    else
        error "Transaction rollback completed with $rollback_errors errors"
        return 1
    fi
}

# Commit transaction (remove rollback points)
commit_transaction() {
    if [[ "${TRANSACTION_STATE[active]}" != "true" ]]; then
        warn "No active transaction to commit"
        return 0
    fi

    local operation_name="${TRANSACTION_STATE[current_operation]}"
    log "Committing transaction: $operation_name"

    # Remove rollback points
    for rollback_info in "${ROLLBACK_STACK[@]}"; do
        local rollback_point_dir="${rollback_info##*:}"
        if [[ -d "$rollback_point_dir" ]]; then
            rm -rf "$rollback_point_dir"
        fi
    done

    # Clear transaction state
    TRANSACTION_STATE["active"]="false"
    TRANSACTION_STATE["current_operation"]=""
    TRANSACTION_STATE["rollback_points"]=0
    ROLLBACK_STACK=()

    # Log transaction commit
    echo "$(date '+%Y-%m-%d %H:%M:%S') [COMMIT] $operation_name" >> "$ROLLBACK_LOG"

    success "Transaction committed successfully"
}

# Execute command with rollback capability
execute_with_rollback() {
    local command="$1"
    local rollback_point_id="$2"
    local description="${3:-Execute command with rollback}"

    log "Executing command with rollback: $command"

    # Create rollback point before execution
    backup_command_for_rollback "$command" "$rollback_point_id" "$description"

    # Execute command
    if eval "$command"; then
        success "Command executed successfully: $command"
        return 0
    else
        local exit_code=$?
        error "Command failed: $command (exit code: $exit_code)"
        TRANSACTION_STATE["last_error"]="Command failed: $command"
        return $exit_code
    fi
}

# Install with automatic rollback
install_with_rollback() {
    local source="$1"
    local destination="$2"
    local rollback_point_id="$3"
    local description="${4:-Install with rollback: $(basename "$source")}"

    log "Installing with rollback capability: $source -> $destination"

    # Create backup of destination if it exists
    if [[ -e "$destination" ]]; then
        backup_file_for_rollback "$destination" "$rollback_point_id" "$description"
    fi

    # Perform installation
    if cp "$source" "$destination"; then
        success "Installation successful: $destination"
        return 0
    else
        error "Installation failed: $destination"
        TRANSACTION_STATE["last_error"]="Installation failed: $destination"
        return 1
    fi
}

# Safe file operation with rollback
safe_file_operation() {
    local operation="$1"
    local file_path="$2"
    local content="$3"
    local rollback_point_id="$4"
    local description="${5:-Safe file operation: $operation $(basename "$file_path")}"

    case "$operation" in
        "create"|"write")
            # Backup existing file if it exists
            if [[ -f "$file_path" ]]; then
                backup_file_for_rollback "$file_path" "$rollback_point_id" "$description"
            fi

            # Create/write file
            if echo "$content" > "$file_path"; then
                success "File $operation successful: $file_path"
                return 0
            else
                error "File $operation failed: $file_path"
                TRANSACTION_STATE["last_error"]="File $operation failed: $file_path"
                return 1
            fi
            ;;
        "delete"|"remove")
            # Backup file before deletion
            if [[ -f "$file_path" ]]; then
                backup_file_for_rollback "$file_path" "$rollback_point_id" "$description"

                # Delete file
                if rm -f "$file_path"; then
                    success "File $operation successful: $file_path"
                    return 0
                else
                    error "File $operation failed: $file_path"
                    TRANSACTION_STATE["last_error"]="File $operation failed: $file_path"
                    return 1
                fi
            else
                warn "File does not exist, no deletion needed: $file_path"
                return 0
            fi
            ;;
        *)
            error "Unknown file operation: $operation"
            return 1
            ;;
    esac
}

# Get transaction status
get_transaction_status() {
    if [[ "${TRANSACTION_STATE[active]}" == "true" ]]; then
        echo "Active: ${TRANSACTION_STATE[current_operation]}"
        echo "Rollback points: ${TRANSACTION_STATE[rollback_points]}"
        if [[ -n "${TRANSACTION_STATE[last_error]}" ]]; then
            echo "Last error: ${TRANSACTION_STATE[last_error]}"
        fi
    else
        echo "No active transaction"
    fi
}

# List rollback points
list_rollback_points() {
    echo "Available Rollback Points:"
    echo "========================="

    if [[ ${#ROLLBACK_STACK[@]} -eq 0 ]]; then
        echo "No rollback points available"
        return 0
    fi

    for i in "${!ROLLBACK_STACK[@]}"; do
        local rollback_info="${ROLLBACK_STACK[$i]}"
        local rollback_id="${rollback_info%%:*}"
        local info_without_id="${rollback_info#*:}"
        local operation="${info_without_id%%:*}"
        local remaining="${info_without_id#*:}"
        local description="${remaining%%:*}"
        local backup_type="${remaining#*:}"

        echo "[$rollback_id] $operation"
        echo "        Description: $description"
        echo "        Type: $backup_type"
        echo ""
    done
}

# Cleanup old rollback points
cleanup_old_rollback_points() {
    if [[ ! -d "$ROLLBACK_DIR" ]]; then
        return 0
    fi

    # Find and remove old rollback point directories
    find "$ROLLBACK_DIR" -name "point_*" -type d -mtime +7 -exec rm -rf {} \; 2>/dev/null || true

    # Clean old log entries (keep last 1000 lines)
    if [[ -f "$ROLLBACK_LOG" ]]; then
        tail -n 1000 "$ROLLBACK_LOG" > "$ROLLBACK_LOG.tmp" 2>/dev/null
        mv "$ROLLBACK_LOG.tmp" "$ROLLBACK_LOG" 2>/dev/null || true
    fi

    log "Cleaned up old rollback points"
}

# Generate rollback report
generate_rollback_report() {
    local report_file="$ROLLBACK_DIR/rollback_report.txt"

    {
        echo "Claude Universal Installer - Rollback Report"
        echo "Generated: $(date)"
        echo "System: $(detect_os) $(detect_arch)"
        echo ""
        echo "Current Transaction Status:"
        get_transaction_status
        echo ""
        echo "Rollback Points History:"
        echo "========================"
        if [[ -f "$ROLLBACK_LOG" ]]; then
            tail -50 "$ROLLBACK_LOG"
        else
            echo "No rollback history found"
        fi
        echo ""
        echo "Rollback Directory: $ROLLBACK_DIR"
        echo "Rollback Log: $ROLLBACK_LOG"
    } > "$report_file"

    success "Rollback report generated: $report_file"
}

# Handle interruption (Ctrl+C)
handle_interruption() {
    echo ""
    warn "Installation interrupted by user"

    if [[ "${TRANSACTION_STATE[active]}" == "true" ]]; then
        echo ""
        read -p "Do you want to rollback the current operation? (y/N): " rollback_choice
        if [[ "$rollback_choice" =~ ^[Yy]$ ]]; then
            echo ""
            echo "Rolling back..."
            rollback_transaction
        else
            echo ""
            warn "Transaction left in incomplete state"
            echo "You can manually rollback later by running the rollback command"
        fi
    fi

    exit 130
}

# Set up interruption handlers
setup_interruption_handlers() {
    trap handle_interruption INT
    trap handle_interruption TERM
}

# Export functions
export -f init_rollback_system begin_transaction create_rollback_point
export -f backup_file_for_rollback backup_directory_for_rollback backup_command_for_rollback
export -f rollback_to_point rollback_transaction commit_transaction
export -f execute_with_rollback install_with_rollback safe_file_operation
export -f get_transaction_status list_rollback_points cleanup_old_rollback_points
export -f generate_rollback_report handle_interruption setup_interruption_handlers

# Export variables
export ROLLBACK_DIR ROLLBACK_LOG MAX_ROLLBACK_POINTS

# Export transaction state
for key in "${!TRANSACTION_STATE[@]}"; do
    export TRANSACTION_STATE_$key="${TRANSACTION_STATE[$key]}"
done