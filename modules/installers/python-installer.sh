#!/bin/bash

# Claude Universal Installer - Python SDK Installation Module
# Handles installation of Claude Agent Python SDK with virtual environment and templates

set -eo pipefail

# Source core utilities and modules
source "$(dirname "${BASH_SOURCE[0]}")/../lib/core.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/config-manager.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/detection.sh"

# Python SDK configuration
readonly PYTHON_SDK_VERSION="latest"
readonly ANTHROPIC_PYTHON_PACKAGE="anthropic"
readonly ADDITIONAL_PACKAGES=(
    "python-dotenv"
    "asyncio-extras"
    "aiohttp"
    "requests"
    "pydantic"
    "rich"
    "typer"
)
readonly MIN_PYTHON_VERSION="3.8"

# Check Python installation and version
check_python_requirements() {
    log "Checking Python requirements..."

    if ! command -v python3 >/dev/null 2>&1; then
        error "Python3 is required but not installed."
        echo "Please install Python3 (${MIN_PYTHON_VERSION} or later) and try again."
        echo ""
        echo "Installation options:"
        echo "  • Ubuntu/Debian: sudo apt install python3 python3-pip python3-venv"
        echo "  • macOS: brew install python3"
        echo "  • Windows: Download from https://python.org"
        return 1
    fi

    # Check Python version
    local python_version
    python_version=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null)

    if [[ -z "$python_version" ]]; then
        error "Failed to determine Python version"
        return 1
    fi

    log "Found Python version: $python_version"

    # Compare versions (simple check)
    local required_major="${MIN_PYTHON_VERSION%.*}"
    local required_minor="${MIN_PYTHON_VERSION#*.}"
    local found_major="${python_version%.*}"
    local found_minor="${python_version#*.}"

    if [[ $found_major -lt $required_major ]] || [[ $found_major -eq $required_major && $found_minor -lt $required_minor ]]; then
        error "Python ${MIN_PYTHON_VERSION} or later is required. Found: $python_version"
        return 1
    fi

    success "Python requirements check passed"
    return 0
}

# Create virtual environment with validation
create_python_virtual_environment() {
    local venv_dir="$1"

    log "Creating Python virtual environment: $venv_dir"

    # Remove existing virtual environment if it exists
    if [[ -d "$venv_dir" ]]; then
        warn "Virtual environment already exists, removing it..."
        rm -rf "$venv_dir"
    fi

    # Create virtual environment
    if python3 -m venv "$venv_dir"; then
        success "Virtual environment created successfully"
    else
        error "Failed to create virtual environment"
        return 1
    fi

    # Verify virtual environment structure
    local required_dirs=("bin" "include" "lib")
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$venv_dir/$dir" ]]; then
            error "Virtual environment structure incomplete: missing $dir directory"
            return 1
        fi
    done

    success "Virtual environment validation passed"
}

# Install packages in virtual environment
install_python_packages() {
    local venv_dir="$1"
    local packages=("${@:2}")

    log "Installing Python packages in virtual environment..."

    # Activate virtual environment
    source "$venv_dir/bin/activate"

    # Upgrade pip first
    log "Upgrading pip..."
    if pip install --upgrade pip setuptools wheel; then
        success "pip upgraded successfully"
    else
        error "Failed to upgrade pip"
        return 1
    fi

    # Install packages with error handling
    local failed_packages=()
    local successful_packages=()

    for package in "${packages[@]}"; do
        log "Installing package: $package"
        if pip install "$package"; then
            successful_packages+=("$package")
            success "✓ $package installed successfully"
        else
            failed_packages+=("$package")
            error "✗ Failed to install $package"
        fi
    done

    # Report installation results
    if [[ ${#successful_packages[@]} -gt 0 ]]; then
        success "Successfully installed: ${successful_packages[*]}"
    fi

    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        warn "Failed to install: ${failed_packages[*]}"
        warn "You may need to install these packages manually"
    fi

    # Verify core anthropic package
    if python -c "import anthropic; print('Anthropic package version:', anthropic.__version__)" 2>/dev/null; then
        success "Anthropic package is functional"
    else
        error "Anthropic package installation verification failed"
        return 1
    fi
}

# Create Python project template
create_python_project_template() {
    local template_dir="$CONFIG_DIR/python-template"

    log "Creating Python project template..."

    # Create template directory structure
    safe_mkdir "$template_dir"

    local directories=("src" "tests" "docs" "examples" "config")
    for dir in "${directories[@]}"; do
        safe_mkdir "$template_dir/$dir"
    done

    # Create main.py template
    cat > "$template_dir/main.py" << 'EOF'
#!/usr/bin/env python3
"""
Claude Agent Template - Main Entry Point

This template provides a starting point for building custom Claude agents
using the Anthropic Python SDK.
"""

import asyncio
import os
import sys
from typing import Optional

from anthropic import Anthropic
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

class ClaudeAgent:
    """Main Claude Agent class"""

    def __init__(self, api_key: Optional[str] = None, model: str = "claude-3-5-sonnet-20241022"):
        """
        Initialize Claude Agent

        Args:
            api_key: Anthropic API key (defaults to ANTHROPIC_API_KEY env var)
            model: Claude model to use
        """
        self.api_key = api_key or os.getenv("ANTHROPIC_API_KEY")
        if not self.api_key:
            raise ValueError("API key is required. Set ANTHROPIC_API_KEY environment variable.")

        self.model = model
        self.client = Anthropic(api_key=self.api_key)

    async def chat(self, message: str, system_prompt: Optional[str] = None) -> str:
        """
        Send a message to Claude and get response

        Args:
            message: The message to send
            system_prompt: Optional system prompt

        Returns:
            Claude's response
        """
        try:
            response = await self.client.messages.create(
                model=self.model,
                max_tokens=1000,
                system=system_prompt,
                messages=[
                    {"role": "user", "content": message}
                ]
            )

            return response.content[0].text

        except Exception as e:
            return f"Error: {str(e)}"

    async def stream_chat(self, message: str, system_prompt: Optional[str] = None):
        """
        Stream a chat response from Claude

        Args:
            message: The message to send
            system_prompt: Optional system prompt

        Yields:
            Response chunks as they arrive
        """
        try:
            async with self.client.messages.stream(
                model=self.model,
                max_tokens=1000,
                system=system_prompt,
                messages=[
                    {"role": "user", "content": message}
                ]
            ) as stream:
                async for text in stream.text_stream:
                    yield text

        except Exception as e:
            yield f"Error: {str(e)}"

async def main():
    """Main entry point"""

    # Initialize agent
    try:
        agent = ClaudeAgent()
        print("🤖 Claude Agent initialized successfully!")
    except ValueError as e:
        print(f"❌ Initialization failed: {e}")
        return 1

    # Example usage
    print("\n💬 Sending test message to Claude...")

    response = await agent.chat(
        "Hello! Please introduce yourself and explain what you can help with.",
        system_prompt="You are a helpful AI assistant powered by Claude."
    )

    print(f"\n📝 Claude's response:\n{response}")

    print("\n✅ Example completed successfully!")
    return 0

if __name__ == "__main__":
    try:
        exit_code = asyncio.run(main())
        sys.exit(exit_code)
    except KeyboardInterrupt:
        print("\n\n👋 Goodbye!")
        sys.exit(0)
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        sys.exit(1)
EOF

    # Create requirements.txt
    cat > "$template_dir/requirements.txt" << EOF
# Claude Agent Python Requirements
anthropic>=0.7.0
python-dotenv>=1.0.0
asyncio-extras>=0.1.0
aiohttp>=3.8.0
requests>=2.28.0
pydantic>=2.0.0
rich>=13.0.0
typer>=0.9.0

# Development dependencies
pytest>=7.0.0
pytest-asyncio>=0.21.0
black>=23.0.0
flake8>=6.0.0
mypy>=1.0.0
EOF

    # Create .env.example
    cat > "$template_dir/.env.example" << 'EOF'
# Claude Agent Environment Configuration
ANTHROPIC_API_KEY=your_api_key_here
CLAUDE_MODEL=claude-3-5-sonnet-20241022
LOG_LEVEL=INFO

# Optional: Custom API endpoint
# ANTHROPIC_BASE_URL=https://api.anthropic.com
EOF

    # Create README.md
    cat > "$template_dir/README.md" << 'EOF'
# Claude Agent Python Project

This is a template for building custom Claude agents using the Anthropic Python SDK.

## Quick Start

1. **Set up your API key:**
   ```bash
   cp .env.example .env
   # Edit .env and add your Anthropic API key
   ```

2. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

3. **Run the agent:**
   ```bash
   python main.py
   ```

## Project Structure

```
├── main.py              # Main entry point
├── requirements.txt     # Python dependencies
├── .env.example        # Environment variables template
├── src/                 # Source code
├── tests/               # Test files
├── docs/                # Documentation
├── examples/            # Example scripts
└── config/              # Configuration files
```

## Features

- **Async/await support** for efficient Claude API interactions
- **Streaming responses** for real-time chat experiences
- **Environment configuration** with .env support
- **Error handling** and graceful failure modes
- **Type hints** for better code quality
- **Logging** and debugging support

## Usage Examples

### Basic Chat
```python
from claude_agent import ClaudeAgent

agent = ClaudeAgent()
response = await agent.chat("Hello, Claude!")
print(response)
```

### Streaming Chat
```python
async for chunk in agent.stream_chat("Tell me a story"):
    print(chunk, end="", flush=True)
```

### Custom System Prompt
```python
response = await agent.chat(
    "Analyze this code",
    system_prompt="You are an expert software developer."
)
```

## Configuration

Set the following environment variables in your `.env` file:

- `ANTHROPIC_API_KEY`: Your Anthropic API key (required)
- `CLAUDE_MODEL`: Claude model to use (default: claude-3-5-sonnet-20241022)
- `LOG_LEVEL`: Logging level (INFO, DEBUG, WARNING, ERROR)

## Development

### Running Tests
```bash
python -m pytest tests/
```

### Code Formatting
```bash
black .
```

### Type Checking
```bash
mypy src/
```

## Learn More

- [Anthropic Python SDK Documentation](https://docs.anthropic.com/claude/reference/python)
- [Claude API Documentation](https://docs.anthropic.com/claude/reference)
- [AsyncIO Documentation](https://docs.python.org/3/library/asyncio.html)
EOF

    # Create pytest.ini
    cat > "$template_dir/pytest.ini" << 'EOF'
[tool:pytest]
testpaths = tests
python_files = test_*.py
python_classes = Test*
python_functions = test_*
addopts =
    --verbose
    --tb=short
    --strict-markers
    --disable-warnings
markers =
    slow: marks tests as slow
    integration: marks tests as integration tests
EOF

    success "Python project template created: $template_dir"
}

# Create activation script
create_python_activation_script() {
    local venv_dir="$1"
    local activation_script="$CONFIG_DIR/activate-python.sh"

    log "Creating Python activation script..."

    cat > "$activation_script" << EOF
#!/bin/bash

# Claude Python SDK Activation Script
# This script activates the Claude Python virtual environment

CLAUDE_PYTHON_ENV="$venv_dir"

# Colors for output
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Check if virtual environment exists
if [[ ! -d "\$CLAUDE_PYTHON_ENV" ]]; then
    echo -e "\${YELLOW}❌ Claude Python environment not found: \$CLAUDE_PYTHON_ENV\${NC}"
    echo "Please run the installer again to create the environment."
    return 1
fi

# Check if virtual environment is already active
if [[ "\$VIRTUAL_ENV" == "\$CLAUDE_PYTHON_ENV" ]]; then
    echo -e "\${YELLOW}ℹ️  Claude Python environment is already active\${NC}"
    return 0
fi

# Activate virtual environment
echo -e "\${GREEN}🐍 Activating Claude Python SDK environment...\${NC}"
source "\$CLAUDE_PYTHON_ENV/bin/activate"

# Display environment information
echo "Python environment activated:"
echo "  Python: \$(python --version)"
echo "  Environment: \$VIRTUAL_ENV"
echo "  Packages: \$(pip list | grep anthropic || echo 'Not installed')"

# Set helpful environment variables
export CLAUDE_PYTHON_ENV_ACTIVE=true
export PYTHONPATH="\$VIRTUAL_ENV/src:\$PYTHONPATH"

# Display usage information
echo ""
echo -e "\${GREEN}✅ Python SDK environment is ready!\${NC}"
echo ""
echo "Available commands:"
echo "  • claude-python-create <project-name>  - Create a new project"
echo "  • python main.py                       - Run the main script"
echo "  • pip install <package>               - Install additional packages"
echo "  • deactivate                           - Exit the environment"
echo ""
echo "Project templates are available in: $CONFIG_DIR/python-template"
EOF

    chmod +x "$activation_script"
    success "Python activation script created: $activation_script"
}

# Create project creation script
create_project_creation_script() {
    local venv_dir="$1"
    local template_dir="$CONFIG_DIR/python-template"
    local creation_script="$CONFIG_DIR/claude-python-create"

    log "Creating Python project creation script..."

    cat > "$creation_script" << EOF
#!/bin/bash

# Claude Python Project Creation Script
# Creates new Python projects from the Claude template

CLAUDE_PYTHON_ENV="$venv_dir"
TEMPLATE_DIR="$template_dir"

# Colors for output
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

show_usage() {
    echo "Usage: claude-python-create <project-name> [directory]"
    echo ""
    echo "Arguments:"
    echo "  project-name    Name of the project to create"
    echo "  directory       Optional directory to create project in (default: current directory)"
    echo ""
    echo "Examples:"
    echo "  claude-python-create my-agent"
    echo "  claude-python-create my-agent ~/projects"
}

# Check arguments
if [[ \$# -eq 0 || \$# -gt 2 ]]; then
    show_usage
    exit 1
fi

PROJECT_NAME="\$1"
PROJECT_DIR="\${2:-.}"

# Validate project name
if [[ ! "\$PROJECT_NAME" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
    echo -e "\${RED}❌ Invalid project name: \$PROJECT_NAME\${NC}"
    echo "Project names must start with a letter and contain only letters, numbers, hyphens, and underscores."
    exit 1
fi

# Check if template exists
if [[ ! -d "\$TEMPLATE_DIR" ]]; then
    echo -e "\${RED}❌ Python template not found: \$TEMPLATE_DIR\${NC}"
    echo "Please run the installer again to create the template."
    exit 1
fi

# Create project directory
FULL_PROJECT_PATH="\$PROJECT_DIR/\$PROJECT_NAME"

if [[ -d "\$FULL_PROJECT_PATH" ]]; then
    echo -e "\${YELLOW}⚠️  Project directory already exists: \$FULL_PROJECT_PATH\${NC}"
    read -p "Do you want to continue? (y/N): " continue
    if [[ ! \$continue =~ ^[Yy]\$ ]]; then
        echo "Project creation cancelled."
        exit 0
    fi
fi

echo -e "\${GREEN}🚀 Creating Python project: \$PROJECT_NAME\${NC}"
echo "Location: \$FULL_PROJECT_PATH"
echo ""

# Copy template
if cp -r "\$TEMPLATE_DIR" "\$FULL_PROJECT_PATH"; then
    echo "✓ Template copied successfully"
else
    echo -e "\${RED}❌ Failed to copy template\${NC}"
    exit 1
fi

# Customize project
cd "\$FULL_PROJECT_PATH"

# Update main.py with project name
sed -i.tmp "s/Claude Agent Template/\$PROJECT_NAME/g" main.py
rm -f main.py.tmp

# Create .env file from example
if [[ -f .env.example ]]; then
    cp .env.example .env
    echo "✓ Environment file created (.env)"
fi

# Initialize git repository if git is available
if command -v git >/dev/null 2>&1; then
    if [[ ! -d .git ]]; then
        git init
        git add .
        git commit -m "Initial commit: \$PROJECT_NAME"
        echo "✓ Git repository initialized"
    fi
fi

echo ""
echo -e "\${GREEN}🎉 Project '\$PROJECT_NAME' created successfully!\${NC}"
echo ""
echo "Next steps:"
echo "1. cd \$FULL_PROJECT_PATH"
echo "2. Edit .env file with your API key"
echo "3. Activate environment: source $CONFIG_DIR/activate-python.sh"
echo "4. Install dependencies: pip install -r requirements.txt"
echo "5. Run the project: python main.py"
echo ""
echo "Happy coding with Claude! 🤖"
EOF

    chmod +x "$creation_script"
    success "Project creation script created: $creation_script"
}

# Main installation function
install_claude_python_sdk() {
    header "Installing Claude Agent Python SDK"

    echo "Installing Claude Agent Python SDK with enhanced features..."
    echo ""

    # Check Python requirements
    if ! check_python_requirements; then
        return 1
    fi

    # Create virtual environment
    local venv_dir="$CONFIG_DIR/claude-python-env"
    if ! create_python_virtual_environment "$venv_dir"; then
        return 1
    fi

    # Prepare packages to install
    local packages=("$ANTHROPIC_PYTHON_PACKAGE")
    packages+=("${ADDITIONAL_PACKAGES[@]}")

    # Install packages
    if ! install_python_packages "$venv_dir" "${packages[@]}"; then
        error "Package installation failed"
        return 1
    fi

    # Create project template
    create_python_project_template

    # Create activation script
    create_python_activation_script "$venv_dir"

    # Create project creation script
    create_project_creation_script "$venv_dir" "$CONFIG_DIR/python-template"

    # Update unified configuration
    set_config_value "installationType" "claude-python-sdk"
    set_config_value "python.venvPath" "$venv_dir"
    set_config_value "python.version" "$(python3 --version 2>/dev/null)"
    set_nested_config_value "features.asyncSupport" true
    set_nested_config_value "features.projectTemplates" true

    echo ""
    success "✅ Claude Agent Python SDK installation completed successfully!"
    echo ""
    echo "Installation Details:"
    echo "  Virtual Environment: $venv_dir"
    echo "  Python Version: $(python3 --version 2>/dev/null)"
    echo "  Template Directory: $CONFIG_DIR/python-template"
    echo "  Activation Script: $CONFIG_DIR/activate-python.sh"
    echo "  Project Creator: $CONFIG_DIR/claude-python-create"
    echo ""
    echo "Quick Start:"
    echo "1. Activate the environment:"
    echo "   source $CONFIG_DIR/activate-python.sh"
    echo ""
    echo "2. Create a new project:"
    echo "   claude-python-create my-agent"
    echo ""
    echo "3. Set up your API key:"
    echo "   cd my-agent"
    echo "   # Edit .env file with your Anthropic API key"
    echo ""
    echo "4. Run your agent:"
    echo "   python main.py"
    echo ""
    echo "Features Included:"
    echo "  • Async/await support for efficient API usage"
    echo "  • Project templates with best practices"
    echo "  • Environment configuration with .env support"
    echo "  • Rich CLI output and progress indicators"
    echo "  • Type hints and error handling"
    echo "  • Test framework setup (pytest)"
    echo "  • Code quality tools (black, flake8, mypy)"
}

# Update existing Python SDK installation
update_python_sdk() {
    header "Updating Claude Agent Python SDK"

    local venv_dir="$CONFIG_DIR/claude-python-env"

    if [[ ! -d "$venv_dir" ]]; then
        error "Python SDK is not installed. Use install function first."
        return 1
    fi

    echo "Updating Python SDK packages..."

    # Activate virtual environment
    source "$venv_dir/bin/activate"

    # Upgrade pip
    pip install --upgrade pip setuptools wheel

    # Update packages
    local packages=("$ANTHROPIC_PYTHON_PACKAGE")
    packages+=("${ADDITIONAL_PACKAGES[@]}")

    local updated_packages=()
    local failed_updates=()

    for package in "${packages[@]}"; do
        log "Updating $package..."
        if pip install --upgrade "$package"; then
            updated_packages+=("$package")
        else
            failed_updates+=("$package")
        fi
    done

    success "Python SDK update completed"
    echo "Updated: ${updated_packages[*]}"
    [[ ${#failed_updates[@]} -gt 0 ]] && echo "Failed: ${failed_updates[*]}"
}

# Verify Python SDK installation
verify_python_sdk_installation() {
    header "Verifying Claude Agent Python SDK Installation"

    local venv_dir="$CONFIG_DIR/claude-python-env"
    local verification_passed=true

    # Check virtual environment
    if [[ -d "$venv_dir" ]]; then
        success "✓ Virtual environment exists: $venv_dir"

        # Check if virtual environment is functional
        if [[ -f "$venv_dir/bin/python" && -f "$venv_dir/bin/pip" ]]; then
            success "✓ Virtual environment structure is valid"

            # Test Python and packages
            source "$venv_dir/bin/activate"
            local python_version
            python_version=$(python --version 2>/dev/null)
            success "✓ Python version: $python_version"

            # Test anthropic package
            if python -c "import anthropic; print('Anthropic version:', anthropic.__version__)" 2>/dev/null; then
                success "✓ Anthropic package is functional"
            else
                error "✗ Anthropic package is not functional"
                verification_passed=false
            fi
        else
            error "✗ Virtual environment structure is invalid"
            verification_passed=false
        fi
    else
        error "✗ Virtual environment not found: $venv_dir"
        verification_passed=false
    fi

    # Check helper scripts
    local scripts=(
        "$CONFIG_DIR/activate-python.sh"
        "$CONFIG_DIR/claude-python-create"
    )

    for script in "${scripts[@]}"; do
        if [[ -f "$script" && -x "$script" ]]; then
            success "✓ Helper script exists: $(basename "$script")"
        else
            error "✗ Helper script missing or not executable: $(basename "$script")"
            verification_passed=false
        fi
    done

    # Check project template
    if [[ -d "$CONFIG_DIR/python-template" ]]; then
        success "✓ Project template exists"
    else
        error "✗ Project template not found"
        verification_passed=false
    fi

    # Check unified configuration
    local install_type
    install_type=$(get_config_value "installationType")
    if [[ "$install_type" == "claude-python-sdk" ]]; then
        success "✓ Unified configuration updated"
    else
        warn "⚠ Unified configuration may not be updated"
    fi

    echo ""
    if [[ "$verification_passed" == true ]]; then
        success "Python SDK installation verification passed"
    else
        error "Python SDK installation verification failed"
        return 1
    fi
}

# Export functions
export -f install_claude_python_sdk update_python_sdk verify_python_sdk_installation
export -f check_python_requirements create_python_virtual_environment install_python_packages
export -f create_python_project_template create_python_activation_script create_project_creation_script

# Export configuration variables
export PYTHON_SDK_VERSION ANTHROPIC_PYTHON_PACKAGE ADDITIONAL_PACKAGES MIN_PYTHON_VERSION