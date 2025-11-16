#!/bin/bash

# Claude Universal Installer - Testing Framework
# Comprehensive testing suite for all installer components

set -eo pipefail

# Source core utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core.sh"

# Test configuration
readonly TEST_DIR="${TEST_DIR:-$(mktemp -d)}"
readonly TEST_LOG="$TEST_DIR/test.log"

# Test tracking
TEST_COUNT=0
PASSED_COUNT=0
FAILED_COUNT=0

# Colors for test output
readonly TEST_GREEN='\033[1;32m'
readonly TEST_RED='\033[1;31m'
readonly TEST_YELLOW='\033[1;33m'
readonly TEST_BLUE='\033[1;34m'
readonly TEST_NC='\033[0m'

# Test utilities
start_test() {
    local name="$1"
    local description="${2:-}"

    ((TEST_COUNT++))
    echo -e "${TEST_BLUE}[TEST]${TEST_NC} $name"
    [[ -n "$description" ]] && echo -e "${TEST_BLUE}       $description${TEST_NC}"
}

end_test() {
    local status="$1"
    local error_message="${2:-}"

    case "$status" in
        "passed")
            echo -e "${TEST_GREEN}[PASS]${TEST_NC} $name"
            ((PASSED_COUNT++))
            ;;
        "failed")
            echo -e "${TEST_RED}[FAIL]${TEST_NC} $name"
            [[ -n "$error_message" ]] && echo -e "${TEST_RED}       Error: $error_message${TEST_NC}"
            ((FAILED_COUNT++))
            ;;
        "skipped")
            echo -e "${TEST_YELLOW}[SKIP]${TEST_NC} $name"
            ;;
    esac
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"

    if [[ "$expected" == "$actual" ]]; then
        return 0
    else
        echo "Assertion failed: $message"
        echo "  Expected: '$expected'"
        echo "  Actual:   '$actual'"
        return 1
    fi
}

assert_file_exists() {
    local file_path="$1"
    local message="${2:-File should exist: $file_path}"

    if [[ -f "$file_path" ]]; then
        return 0
    else
        echo "Assertion failed: $message"
        return 1
    fi
}

# Mock functions for testing
create_mock_binary() {
    local name="$1"
    local content="${2:-echo 'Mock binary: $name'}"
    local mock_path="$TEST_DIR/bin/$name"

    mkdir -p "$(dirname "$mock_path")"
    cat > "$mock_path" << EOF
#!/bin/bash
$content
EOF
    chmod +x "$mock_path"
    export PATH="$TEST_DIR/bin:$PATH"
    echo "$mock_path"
}

# Test suites
test_core_utilities() {
    start_test "Core Utilities" "Testing core utility functions"

    # Test logging functions
    local test_log="$TEST_DIR/core-test.log"
    LOG_FILE="$test_log"

    log "Test log message"
    warn "Test warning message"
    error "Test error message"

    assert_file_exists "$test_log" "Log file should be created"
    if grep -q "Test log message" "$test_log"; then
        echo "✓ Log function works"
    else
        end_test "failed" "Log function failed"
        return 1
    fi

    # Test system detection
    local os=$(detect_os)
    local arch=$(detect_arch)
    echo "✓ Detected OS: $os, Architecture: $arch"

    end_test "passed"
}

test_configuration_management() {
    start_test "Configuration Management" "Testing configuration module"

    # Source config manager
    source "$SCRIPT_DIR/../lib/config-manager.sh"

    local test_config_dir="$TEST_DIR/config"
    CONFIG_DIR="$test_config_dir"
    local config_file="$test_config_dir/config.json"

    # Test configuration initialization
    if init_config; then
        echo "✓ Configuration initialization works"
        assert_file_exists "$config_file"
    else
        end_test "failed" "Configuration initialization failed"
        return 1
    fi

    # Test configuration values
    set_config_value "test.key" "test-value"
    local retrieved_value=$(get_config_value "test.key")
    assert_equals "test-value" "$retrieved_value" "Configuration value retrieval"

    end_test "passed"
}

test_installation_detection() {
    start_test "Installation Detection" "Testing detection module"

    # Source detection module
    source "$SCRIPT_DIR/../lib/detection.sh"

    local test_config_dir="$TEST_DIR/detection-config"
    CONFIG_DIR="$test_config_dir"

    # Create mock installations
    local mock_cli=$(create_mock_binary "claude" "echo 'Claude Code CLI v1.0.0'")
    mkdir -p "$test_config_dir/claude-python-env/bin"
    echo '#!/bin/bash' > "$test_config_dir/claude-python-env/bin/python"
    chmod +x "$test_config_dir/claude-python-env/bin/python"

    # Test detection
    detect_all_installations

    if [[ ${#DETECTED_INSTALLATIONS[@]} -gt 0 ]]; then
        echo "✓ Installation detection works"
    else
        end_test "failed" "Installation detection failed"
        return 1
    fi

    end_test "passed"
}

test_uninstaller() {
    start_test "Uninstaller Module" "Testing uninstall functionality"

    # Source uninstaller
    source "$SCRIPT_DIR/../installers/uninstaller.sh"

    local test_config_dir="$TEST_DIR/uninstall-test"
    CONFIG_DIR="$test_config_dir"

    # Create mock installations to uninstall
    local mock_cli=$(create_mock_binary "claude" "echo 'Claude CLI'")
    mkdir -p "$test_config_dir/claude-python-env"
    create_mock_config "$test_config_dir/config.json" '{"installationType": "claude-python-sdk"}'

    # Test backup creation
    if create_uninstall_backup; then
        echo "✓ Uninstall backup creation works"
        assert_directory_exists "$UNINSTALL_BACKUP_DIR"
    else
        end_test "failed" "Uninstall backup creation failed"
        return 1
    fi

    end_test "passed"
}

assert_directory_exists() {
    local dir_path="$1"
    local message="${2:-Directory should exist: $dir_path}"

    if [[ -d "$dir_path" ]]; then
        return 0
    else
        echo "Assertion failed: $message"
        return 1
    fi
}

create_mock_config() {
    local config_path="$1"
    local config_content="${2:-{}}"

    mkdir -p "$(dirname "$config_path")"
    echo "$config_content" > "$config_path"
}

# Main test runner
run_all_tests() {
    header "Running Claude Universal Installer Test Suite"

    # Initialize test environment
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"

    echo "Test directory: $TEST_DIR"
    echo ""

    # Run test suites
    test_core_utilities
    test_configuration_management
    test_installation_detection
    test_uninstaller

    # Display summary
    echo ""
    header "Test Summary"
    echo "Total Tests: $TEST_COUNT"
    echo -e "Passed: ${TEST_GREEN}$PASSED_COUNT${TEST_NC}"
    echo -e "Failed: ${TEST_RED}$FAILED_COUNT${TEST_NC}"
    echo ""

    if [[ $FAILED_COUNT -eq 0 ]]; then
        success "All tests passed! 🎉"
        return 0
    else
        error "Some tests failed."
        return 1
    fi
}

cleanup_test_environment() {
    if [[ -n "$TEST_DIR" && "$TEST_DIR" == /tmp/* ]]; then
        rm -rf "$TEST_DIR"
        log "Test environment cleaned up: $TEST_DIR"
    fi
}

# Export functions
export -f start_test end_test assert_equals assert_file_exists assert_directory_exists
export -f create_mock_binary create_mock_config
export -f test_core_utilities test_configuration_management
export -f test_installation_detection test_uninstaller
export -f run_all_tests cleanup_test_environment

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-all}" in
        "all")
            run_all_tests
            ;;
        "cleanup")
            cleanup_test_environment
            ;;
        *)
            echo "Usage: $0 [all|cleanup]"
            exit 1
            ;;
    esac
fi