#!/bin/bash

# Claude Universal Installer - Modular System Demo
# Demonstrates the new modular architecture capabilities

set -eo pipefail

# Colors for output (different names to avoid conflicts)
readonly DEMO_GREEN='\033[0;32m'
readonly DEMO_BLUE='\033[0;34m'
readonly DEMO_YELLOW='\033[1;33m'
readonly DEMO_NC='\033[0m'

echo -e "${DEMO_BLUE}=== Claude Universal Installer - Modular System Demo ===${DEMO_NC}"
echo ""

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${DEMO_YELLOW}This demo showcases the enhanced modular architecture:${DEMO_NC}"
echo ""

# Demo 1: Core Utilities
echo -e "${DEMO_BLUE}🔧 Demo 1: Core Utilities${DEMO_NC}"
echo "Testing core utility functions..."
source "$SCRIPT_DIR/modules/lib/core.sh"

# Test logging
log "This is a log message"
success "This is a success message"
warn "This is a warning message"

# Test system detection
echo "Detected OS: $(detect_os)"
echo "Detected Architecture: $(detect_arch)"
echo ""

# Demo 2: Configuration Management
echo -e "${DEMO_BLUE}⚙️  Demo 2: Configuration Management${DEMO_NC}"
echo "Testing unified configuration system..."
source "$SCRIPT_DIR/modules/lib/config-manager.sh"

# Set up test config directory
TEST_CONFIG_DIR="/tmp/claude-demo-config"
CONFIG_DIR="$TEST_CONFIG_DIR"

# Initialize configuration
init_config

# Set some configuration values
set_config_value "apiToken" "demo-token-12345"
set_config_value "model" "claude-3-5-sonnet-20241022"
set_nested_config_value "features.streaming" true

# Display configuration
echo "Configuration summary:"
get_config_summary
echo ""

# Demo 3: Installation Detection
echo -e "${DEMO_BLUE}🔍 Demo 3: Installation Detection${DEMO_NC}"
echo "Testing installation detection capabilities..."
source "$SCRIPT_DIR/modules/lib/detection.sh"

# Reset config dir for detection test
CONFIG_DIR="$TEST_CONFIG_DIR"

# Create mock installations for detection
mkdir -p "$TEST_CONFIG_DIR/claude-python-env/bin"
echo '#!/bin/bash' > "$TEST_CONFIG_DIR/claude-python-env/bin/python"
chmod +x "$TEST_CONFIG_DIR/claude-python-env/bin/python"

mkdir -p "$TEST_CONFIG_DIR/claude-typescript-projects"

# Create mock CLI in test directory
mkdir -p "$TEST_CONFIG_DIR/bin"
cat > "$TEST_CONFIG_DIR/bin/claude" << 'EOF'
#!/bin/bash
echo "Claude Code CLI v2.0.0 (Demo)"
EOF
chmod +x "$TEST_CONFIG_DIR/bin/claude"
export PATH="$TEST_CONFIG_DIR/bin:$PATH"

# Run detection
detect_existing_installations
echo ""

# Demo 4: Testing Framework
echo -e "${DEMO_BLUE}🧪 Demo 4: Testing Framework${DEMO_NC}"
echo "Running comprehensive test suite..."
source "$SCRIPT_DIR/modules/tests/test-framework.sh"

# Run tests with our test config
CONFIG_DIR="$TEST_CONFIG_DIR" "$SCRIPT_DIR/modules/tests/test-framework.sh" | head -20
echo "   ... (test output truncated for demo)"
echo ""

# Demo 5: Uninstaller Safety
echo -e "${DEMO_BLUE}🗑️  Demo 5: Uninstaller Safety Features${DEMO_NC}"
echo "Testing uninstaller backup functionality..."
source "$SCRIPT_DIR/modules/installers/uninstaller.sh"

# Set config for uninstaller test
CONFIG_DIR="$TEST_CONFIG_DIR"

# Test backup creation
if create_uninstall_backup; then
    echo "✓ Uninstall backup created successfully"
    echo "  Backup location: $UNINSTALL_BACKUP_DIR"

    # Show backup contents
    if [[ -d "$UNINSTALL_BACKUP_DIR" ]]; then
        echo "  Backup contents:"
        ls -la "$UNINSTALL_BACKUP_DIR" | head -5
    fi
else
    echo "✗ Uninstall backup creation failed"
fi
echo ""

# Demo 6: Module Integration
echo -e "${DEMO_BLUE}🔗 Demo 6: Module Integration${DEMO_NC}"
echo "Demonstrating how modules work together..."

# Create a unified workflow using multiple modules
echo "Workflow: Detection → Configuration → Validation"

# 1. Detect installations
detect_all_installations
echo "  ✓ Detected ${#DETECTED_INSTALLATIONS[@]} installation(s)"

# 2. Configure based on detection
if [[ " ${DETECTED_INSTALLATIONS[*]} " =~ " claude-code-cli " ]]; then
    set_config_value "installationType" "claude-code-cli"
    echo "  ✓ Set installation type to claude-code-cli"
fi

# 3. Validate configuration
if validate_config_structure "$CONFIG_DIR/config.json"; then
    echo "  ✓ Configuration validation passed"
else
    echo "  ✗ Configuration validation failed"
fi

# 4. Generate detection report
generate_detection_report
echo "  ✓ Detection report generated"
echo ""

# Cleanup
echo -e "${DEMO_BLUE}🧹 Cleanup${DEMO_NC}"
echo "Cleaning up demo environment..."

# Remove test config
if [[ -d "$TEST_CONFIG_DIR" ]]; then
    rm -rf "$TEST_CONFIG_DIR"
    echo "✓ Test configuration removed"
fi

# Clean up test framework
"$SCRIPT_DIR/modules/tests/test-framework.sh" cleanup 2>/dev/null || true
echo "✓ Test environment cleaned up"
echo ""

echo -e "${DEMO_GREEN}🎉 Demo completed successfully!${DEMO_NC}"
echo ""
echo "The modular architecture provides:"
echo "  • Separation of concerns for better maintainability"
echo "  • Comprehensive testing capabilities"
echo "  • Unified configuration management"
echo "  • Safe installation and uninstallation"
echo "  • Robust error handling and logging"
echo ""
echo "See modules/README.md for detailed documentation."