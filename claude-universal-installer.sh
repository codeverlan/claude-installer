#!/bin/bash

# Claude Universal Installer - First Run Setup
# Allows users to choose between Claude Code CLI, Python SDK, or TypeScript SDK
# Each option includes appropriate customizations and integrations

set -eo pipefail

# Version and configuration
INSTALLER_VERSION="1.0.0"
INSTALLER_DATE="2025-11-14"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.claude-universal"
LOG_FILE="$CONFIG_DIR/install.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging function
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${GREEN}[INFO]${NC} $1"
    echo "$msg" >> "$LOG_FILE"
}

warn() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${YELLOW}[WARN]${NC} $1"
    echo "$msg" >> "$LOG_FILE"
}

error() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${RED}[ERROR]${NC} $1"
    echo "$msg" >> "$LOG_FILE"
}

header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Create configuration directory
setup_config() {
    mkdir -p "$CONFIG_DIR"
    touch "$LOG_FILE"
    log "Created configuration directory: $CONFIG_DIR"
}

# Detect and display all existing Claude installations
detect_existing_installations() {
    header "Existing Claude Installations"

    local found_installations=false
    local installations=()

    # Check for Claude Code CLI
    if command -v claude >/dev/null 2>&1; then
        local claude_version=$(claude --version 2>/dev/null || echo "unknown version")
        local claude_path=$(command -v claude)
        installations+=("Claude Code CLI: $claude_path ($claude_version)")
        found_installations=true
    fi

    # Check for Python SDK virtual environment
    if [[ -d "$HOME/.claude-universal/claude-python-env" ]]; then
        local python_version=""
        if [[ -f "$HOME/.claude-universal/claude-python-env/bin/python" ]]; then
            python_version=$("$HOME/.claude-universal/claude-python-env/bin/python" --version 2>/dev/null || echo "unknown version")
        fi
        installations+=("Claude Python SDK: $HOME/.claude-universal/claude-python-env ($python_version)")
        found_installations=true
    fi

    # Check for TypeScript SDK projects
    if [[ -d "$HOME/.claude-universal/claude-typescript-projects" ]]; then
        local node_version=""
        if command -v node >/dev/null 2>&1; then
            node_version=$(node --version 2>/dev/null || echo "unknown version")
        fi
        installations+=("Claude TypeScript SDK: $HOME/.claude-universal/claude-typescript-projects ($node_version)")
        found_installations=true
    fi

    # Check for configuration directories
    if [[ -d "$HOME/.claude-universal" ]]; then
        local config_files=$(find "$HOME/.claude-universal" -name "config.json" 2>/dev/null | wc -l)
        if [[ $config_files -gt 0 ]]; then
            installations+=("Configuration files: $HOME/.claude-universal ($config_files config files)")
        fi
    fi

    # Check for Claude CLI configuration
    if [[ -d "$HOME/.claude" ]]; then
        installations+=("Claude CLI config: $HOME/.claude")
        found_installations=true
    fi

    # Check for Docker images
    if command -v docker >/dev/null 2>&1; then
        local docker_images=$(docker images --filter "reference=*claude*" --format "{{.Repository}}:{{.Tag}}" 2>/dev/null || true)
        if [[ -n "$docker_images" ]]; then
            while IFS= read -r image; do
                installations+=("Docker image: $image")
            done <<< "$docker_images"
            found_installations=true
        fi
    fi

    # Display results
    if [[ "$found_installations" = true ]]; then
        echo -e "${GREEN}Found the following Claude installations:${NC}"
        echo ""
        for installation in "${installations[@]}"; do
            echo -e "${CYAN}✓${NC} $installation"
        done
        echo ""
    else
        echo -e "${YELLOW}No existing Claude installations found.${NC}"
        echo ""
    fi
}

# Display welcome banner
show_welcome() {
    clear
    echo -e "${PURPLE}"
    cat << 'EOF'
    ____  __    _____ _____ _____ _____    _    _   _
   |  _ \/\ \  |_   _|_   _|_   _|_   _|  / \  | \ | |
   | |_) /  \ \   | |   | |   | |   | |   / _ \ |  \| |
   |  __/\ /\ / | |   | |   | |   | |  / ___ \| . ` |
   |_| \_\/_\/|_|   |_|   |_|   |_|  /_/   \_\_|\_|_|

              Universal Installer v1.0.0
EOF
    echo -e "${NC}"
    echo ""

    # Detect and show existing installations
    detect_existing_installations

    header "Welcome to Claude Universal Installer"
    echo "This installer helps you set up Claude development environment with:"
    echo "1. Claude Code CLI (Terminal-based AI coding assistant)"
    echo "2. Claude Agent Python SDK (Build custom AI agents)"
    echo "3. Claude Agent TypeScript SDK (Build custom AI agents in Node.js)"
    echo ""
}

# Check system requirements
check_requirements() {
    # Quick silent check - only fail on critical missing tools
    local missing=()

    # Check basic command availability
    for cmd in curl wget; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing required commands: ${missing[*]}"
        echo "Please install these commands and try again."
        exit 1
    fi
}

# Installation option selection
select_installation_type() {
    header "Select Installation Type"
    echo "Please choose how you want to use Claude:"
    echo ""
    echo "1. ${CYAN}Claude Code CLI${NC} - Terminal-based AI coding assistant"
    echo "   • Interactive terminal interface"
    echo "   • Built-in system prompts and slash commands"
    echo "   • Direct file editing and command execution"
    echo "   • Native MCP integration"
    echo "   • Best for: Day-to-day development tasks"
    echo ""
    echo "2. ${YELLOW}Claude Agent Python SDK${NC} - Build custom AI agents"
    echo "   • Programmatic Claude API integration"
    echo "   • Custom agent workflows"
    echo "   • Async/await support"
    echo "   • Python ecosystem integration"
    echo "   • Best for: Custom AI applications and automation"
    echo ""
    echo "3. ${GREEN}Claude Agent TypeScript SDK${NC} - Build agents in Node.js"
    echo "   • TypeScript/JavaScript Claude API"
    echo "   • Modern async/await patterns"
    echo "   • npm package ecosystem"
    echo "   • Full-stack web integration"
    echo "   • Best for: Web applications and Node.js services"
    echo ""
    echo "4. ${RED}Uninstall Claude${NC} - Remove existing Claude installation"
    echo "   • Detect and uninstall any Claude installation"
    echo "   • Clean up configuration files and directories"
    echo "   • Remove system integration and PATH modifications"
    echo "   • Best for: Complete removal of Claude setup"
    echo ""

    while true; do
        read -p "Enter your choice (1-4): " choice
        case $choice in
            1)
                INSTALLATION_TYPE="claude-code-cli"
                break
                ;;
            2)
                INSTALLATION_TYPE="claude-python-sdk"
                break
                ;;
            3)
                INSTALLATION_TYPE="claude-typescript-sdk"
                break
                ;;
            4)
                INSTALLATION_TYPE="uninstall"
                break
                ;;
            *)
                echo "Invalid choice. Please enter 1, 2, 3, or 4."
                ;;
        esac
    done

    log "Selected option: $INSTALLATION_TYPE"
    echo ""
    echo "✅ Selected: $INSTALLATION_TYPE"
    echo ""
}

# Configure API authentication and endpoint
configure_api() {
    header "Configure API Authentication"

    echo "Claude requires an Anthropic API token for authentication."
    echo "Get your API token from: https://console.anthropic.com/"
    echo ""

    # Check for existing token
    if [[ -n "${ANTHROPIC_AUTH_TOKEN:-}" ]]; then
        echo "Found existing ANTHROPIC_AUTH_TOKEN in environment."
        read -p "Use this token? (y/N): " use_existing
        if [[ $use_existing =~ ^[Yy]$ ]]; then
            API_TOKEN="$ANTHROPIC_AUTH_TOKEN"
            log "Using existing API token from environment"
            echo "✅ Using existing API token"
        else
            prompt_api_token
        fi
    else
        prompt_api_token
    fi

    # Configure API endpoint
    configure_api_endpoint

    echo "✅ API configuration completed"
    log "API configuration completed successfully"
    echo ""
}

prompt_api_token() {
    # Prompt for API token
    while true; do
        read -s -p "Enter your Anthropic API token: " input_token
        echo ""
        if [[ -z "$input_token" ]]; then
            echo "API token cannot be empty. Please try again."
            continue
        fi

        # Basic token validation
        if [[ "$input_token" =~ ^sk-ant-[a-zA-Z0-9_-]+$ ]]; then
            API_TOKEN="$input_token"
            echo "✅ API token configured"
            break
        else
            warn "Invalid token format. Expected format: sk-ant-..."
            read -p "Continue anyway? (y/N): " continue_anyway
            if [[ $continue_anyway =~ ^[Yy]$ ]]; then
                API_TOKEN="$input_token"
                echo "✅ API token configured"
                break
            fi
        fi
    done
}

configure_api_endpoint() {
    echo ""
    echo "Configure API endpoint (optional):"
    echo "Press Enter to use the default Anthropic API"
    echo ""

    # Show available endpoints
    echo "Available endpoints:"
    echo "1. https://api.anthropic.com (Official Anthropic)"
    echo "2. https://api.z.ai/api/anthropic (Z.AI Proxy)"
    echo "3. https://anyrouter.top/v1 (AnyRouter)"
    echo "4. https://openrouter.ai/api/v1 (OpenRouter)"
    echo "5. Custom endpoint"
    echo ""

    while true; do
        read -p "Select endpoint (1-5) or press Enter for default: " endpoint_choice

        case $endpoint_choice in
            1|"")
                API_ENDPOINT="https://api.anthropic.com"
                echo "✅ Using official Anthropic API endpoint"
                break
                ;;
            2)
                API_ENDPOINT="https://api.z.ai/api/anthropic"
                echo "✅ Using Z.AI Proxy endpoint"
                break
                ;;
            3)
                API_ENDPOINT="https://anyrouter.top/v1"
                echo "✅ Using AnyRouter endpoint"
                break
                ;;
            4)
                API_ENDPOINT="https://openrouter.ai/api/v1"
                echo "✅ Using OpenRouter endpoint"
                break
                ;;
            5)
                read -p "Enter custom API endpoint URL: " custom_endpoint
                if [[ -n "$custom_endpoint" ]]; then
                    API_ENDPOINT="$custom_endpoint"
                    echo "✅ Using custom endpoint: $API_ENDPOINT"
                    break
                else
                    echo "Endpoint cannot be empty. Please try again."
                fi
                ;;
            *)
                echo "Invalid choice. Please enter 1-5 or press Enter for default."
                ;;
        esac
    done

    # Validate endpoint format
    if [[ ! "$API_ENDPOINT" =~ ^https?:// ]]; then
        warn "Endpoint should start with http:// or https://"
        read -p "Continue anyway? (y/N): " continue_endpoint
        if [[ ! $continue_endpoint =~ ^[Yy]$ ]]; then
            API_ENDPOINT="https://api.anthropic.com"
            echo "Using default endpoint: $API_ENDPOINT"
        fi
    fi

    log "API endpoint configured: $API_ENDPOINT"
}

# Installation implementations
install_claude_code_cli() {
    header "Installing Claude Code CLI"

    echo "Installing Claude Code CLI..."

    # Detect platform and architecture
    local platform=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)

    case $arch in
        x86_64) arch="x64" ;;
        aarch64|arm64) arch="arm64" ;;
        armv7l) arch="arm" ;;
        *)
            error "Unsupported architecture: $arch"
            exit 1
            ;;
    esac

    # Download Claude Code binary
    local binary_name="claude-code-${platform}-${arch}"
    local download_url="https://github.com/anthropics/claude-code/releases/latest/download/${binary_name}"
    local install_dir="$HOME/.local/bin"
    local binary_path="$install_dir/claude"

    mkdir -p "$install_dir"

    log "Downloading Claude Code CLI from: $download_url"

    if curl -fsSL "$download_url" -o "$binary_path"; then
        chmod +x "$binary_path"
        log "Claude Code CLI installed to: $binary_path"
        echo "✅ Claude Code CLI installed successfully"
    else
        error "Failed to download Claude Code CLI"
        exit 1
    fi

    # Add to PATH if not already there
    if [[ ":$PATH:" != *":$install_dir:"* ]]; then
        echo "export PATH=\"\$PATH:$install_dir\"" >> "$HOME/.bashrc"
        echo "export PATH=\"\$PATH:$install_dir\"" >> "$HOME/.zshrc"
        log "Added $install_dir to PATH"
        echo "ℹ️  Added $install_dir to PATH in your shell configuration"
    fi

    # Create configuration directory
    local claude_config_dir="$HOME/.claude"
    mkdir -p "$claude_config_dir"/{commands,skills,hooks,agents,projects,system-prompts,session-env,todos}

    # Set up customizations
    setup_claude_code_customizations "$claude_config_dir"

    echo "✅ Claude Code CLI installation completed"
    echo ""
    echo "Next steps:"
    echo "1. Restart your terminal or run: source ~/.bashrc"
    echo "2. Run: claude"
    echo "3. Follow the authentication prompts"
    echo ""
}

install_claude_python_sdk() {
    header "Installing Claude Agent Python SDK"

    # Check Python installation
    if ! command -v python3 >/dev/null 2>&1; then
        echo "Python3 is required but not installed."
        echo "Please install Python3 and try again."
        exit 1
    fi

    # Create virtual environment
    local venv_dir="$CONFIG_DIR/claude-python-env"
    log "Creating Python virtual environment: $venv_dir"

    python3 -m venv "$venv_dir"

    # Activate virtual environment and install SDK
    source "$venv_dir/bin/activate"
    pip install --upgrade pip
    pip install anthropic

    log "Python SDK installed in virtual environment"
    echo "✅ Claude Agent Python SDK installed"

    # Create project template
    create_python_project_template

    # Create activation script
    create_python_activation_script "$venv_dir"

    echo "✅ Python SDK installation completed"
    echo ""
    echo "Next steps:"
    echo "1. Activate the environment: source ~/config/claude-universal/activate-python.sh"
    echo "2. Create a new Python project: claude-python-create myproject"
    echo "3. Run your agent: python myproject/main.py"
    echo ""
}

install_claude_typescript_sdk() {
    header "Installing Claude Agent TypeScript SDK"

    # Check Node.js installation
    if ! command -v node >/dev/null 2>&1; then
        echo "Node.js is required but not installed."
        echo "Please install Node.js and try again."
        exit 1
    fi

    # Create project directory
    local project_dir="$CONFIG_DIR/claude-typescript-projects"
    mkdir -p "$project_dir"

    # Initialize npm project and install SDK
    cd "$project_dir"
    npm init -y
    npm install @anthropic-ai/sdk typescript @types/node ts-node

    log "TypeScript SDK installed in: $project_dir"
    echo "✅ Claude Agent TypeScript SDK installed"

    # Create TypeScript configuration
    create_typescript_config "$project_dir"

    # Create project template
    create_typescript_project_template "$project_dir"

    # Create project creation script
    create_typescript_project_script "$project_dir"

    echo "✅ TypeScript SDK installation completed"
    echo ""
    echo "Next steps:"
    echo "1. Create a new project: ~/config/claude-universal/claude-typescript-projects/create-project.sh myproject"
    echo "2. Navigate to project: cd ~/myproject"
    echo "3. Run your agent: npm start"
    echo ""
}

# Setup customizations for Claude Code CLI
setup_claude_code_customizations() {
    local config_dir="$1"

    # Copy system prompts from existing docker-baseline project
    if [[ -d "$SCRIPT_DIR/claude-system-prompts" ]]; then
        log "Copying system prompts from docker-baseline project"
        cp -r "$SCRIPT_DIR/claude-system-prompts" "$config_dir/"

        # Set up symlinks
        cd "$config_dir"
        ln -sf system-prompts projects/claude-system-prompts
        ln -sf commands projects/claude-commands
        ln -sf skills projects/claude-skills
        ln -sf hooks projects/claude-hooks
        ln -sf agents projects/claude-agents
        ln -sf todos projects/claude-todos
        ln -sf session-env projects/claude-sessions

        log "Claude Code customizations installed"
    else
        warn "System prompts not found in $SCRIPT_DIR/claude-system-prompts"
    fi

    # Create configuration file
    cat > "$config_dir/settings.json" << EOF
{
  "apiToken": "$API_TOKEN",
  "customPromptsDir": "$config_dir/system-prompts",
  "autoCompactBufferRatio": 0.05,
  "contextAutocompactTarget": "5%",
  "disableNonessentialTraffic": true,
  "customizations": {
    "systemPrompts": true,
    "slashCommands": true,
    "sudoEscalation": true,
    "dockerIntegration": true
  }
}
EOF

    log "Claude Code configuration created"
}

# Create Python project template
create_python_project_template() {
    local template_dir="$CONFIG_DIR/python-template"
    mkdir -p "$template_dir"

    cat > "$template_dir/main.py" << 'EOF'
#!/usr/bin/env python3
"""
Claude Agent Python Template
Basic template for creating custom Claude agents
"""

import os
import asyncio
from anthropic import Anthropic

class ClaudeAgent:
    def __init__(self, api_key=None):
        self.api_key = api_key or os.getenv('ANTHROPIC_API_KEY')
        if not self.api_key:
            raise ValueError("API key is required. Set ANTHROPIC_API_KEY environment variable.")

        self.client = Anthropic(api_key=self.api_key)

    async def chat(self, message, system_prompt=None):
        """Send a message to Claude and get response"""
        try:
            response = await self.client.messages.create(
                model="claude-3-5-sonnet-20241022",
                max_tokens=1000,
                system=system_prompt,
                messages=[
                    {"role": "user", "content": message}
                ]
            )
            return response.content[0].text
        except Exception as e:
            return f"Error: {str(e)}"

    async def analyze_code(self, code_content):
        """Analyze code and provide suggestions"""
        system_prompt = "You are a helpful code analysis assistant. Review the provided code and offer constructive feedback, suggestions for improvement, and identify any potential issues."

        return await self.chat(f"Please analyze this code:\n\n```python\n{code_content}\n```", system_prompt)

async def main():
    # Initialize the agent
    agent = ClaudeAgent()

    print("Claude Python Agent - Ready to assist!")
    print("Type 'quit' to exit")
    print()

    while True:
        try:
            user_input = input("You: ").strip()

            if user_input.lower() in ['quit', 'exit', 'q']:
                print("Goodbye!")
                break

            if not user_input:
                continue

            print("Claude: ", end="", flush=True)
            response = await agent.chat(user_input)
            print(response)
            print()

        except KeyboardInterrupt:
            print("\nGoodbye!")
            break
        except Exception as e:
            print(f"Error: {e}")

if __name__ == "__main__":
    asyncio.run(main())
EOF

    cat > "$template_dir/requirements.txt" << 'EOF'
anthropic>=0.7.0
asyncio
python-dotenv
EOF

    cat > "$template_dir/.env.example" << 'EOF'
ANTHROPIC_API_KEY=your_api_token_here
EOF

    log "Python project template created"
}

# Create Python activation script
create_python_activation_script() {
    local venv_dir="$1"

    cat > "$CONFIG_DIR/activate-python.sh" << EOF
#!/bin/bash
# Activation script for Claude Python SDK environment

echo "🐍 Activating Claude Python SDK environment..."

# Check if virtual environment exists
if [[ ! -d "$venv_dir" ]]; then
    echo "❌ Virtual environment not found at $venv_dir"
    exit 1
fi

# Activate virtual environment
source "$venv_dir/bin/activate"

# Set environment variables
export ANTHROPIC_API_KEY="$API_TOKEN"

echo "✅ Python SDK environment activated"
echo "📚 Available commands:"
echo "  - claude-python-create <project-name>: Create new Python project"
echo "  - python <script>: Run Python scripts with SDK available"
echo ""
echo "💡 Example usage:"
echo "  claude-python-create my-agent"
echo "  cd my-agent"
echo "  python main.py"
EOF

    chmod +x "$CONFIG_DIR/activate-python.sh"

    # Create project creation script
    cat > "$CONFIG_DIR/claude-python-create" << 'EOF'
#!/bin/bash
# Create new Claude Python project

if [[ $# -eq 0 ]]; then
    echo "Usage: claude-python-create <project-name>"
    exit 1
fi

project_name="$1"
template_dir="$HOME/.claude-universal/python-template"

if [[ ! -d "$template_dir" ]]; then
    echo "❌ Python template not found. Please run the installer again."
    exit 1
fi

# Copy template to new project directory
cp -r "$template_dir" "$project_name"

echo "✅ Created new Python project: $project_name"
echo ""
echo "Next steps:"
echo "  cd $project_name"
echo "  cp .env.example .env"
echo "  # Edit .env with your API token"
echo "  python main.py"
EOF

    chmod +x "$CONFIG_DIR/claude-python-create"

    log "Python activation and project scripts created"
}

# Create TypeScript configuration
create_typescript_config() {
    local project_dir="$1"

    cat > "$project_dir/tsconfig.json" << 'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "commonjs",
    "lib": ["ES2022"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
EOF

    log "TypeScript configuration created"
}

# Create TypeScript project template
create_typescript_project_template() {
    local project_dir="$1"
    local template_dir="$project_dir/template"
    mkdir -p "$template_dir/src"

    cat > "$template_dir/package.json" << 'EOF'
{
  "name": "claude-typescript-project",
  "version": "1.0.0",
  "description": "Claude Agent TypeScript Project",
  "main": "dist/index.js",
  "scripts": {
    "start": "ts-node src/index.ts",
    "build": "tsc",
    "dev": "ts-node --watch src/index.ts"
  },
  "dependencies": {
    "@anthropic-ai/sdk": "^0.24.0",
    "dotenv": "^16.0.0"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "typescript": "^5.0.0",
    "ts-node": "^10.9.0"
  }
}
EOF

    cat > "$template_dir/src/index.ts" << 'EOF'
#!/usr/bin/env ts-node

/**
 * Claude Agent TypeScript Template
 * Basic template for creating custom Claude agents in TypeScript
 */

import { Anthropic } from '@anthropic-ai/sdk';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

class ClaudeAgent {
  private client: Anthropic;

  constructor(apiKey?: string) {
    const key = apiKey || process.env.ANTHROPIC_API_KEY;
    if (!key) {
      throw new Error('API key is required. Set ANTHROPIC_API_KEY environment variable.');
    }

    this.client = new Anthropic({ apiKey: key });
  }

  async chat(message: string, systemPrompt?: string): Promise<string> {
    try {
      const response = await this.client.messages.create({
        model: 'claude-3-5-sonnet-20241022',
        max_tokens: 1000,
        system: systemPrompt,
        messages: [
          { role: 'user', content: message }
        ]
      });

      return response.content[0].type === 'text' ? response.content[0].text : 'No text response received.';
    } catch (error) {
      return `Error: ${error instanceof Error ? error.message : 'Unknown error'}`;
    }
  }

  async analyzeCode(codeContent: string): Promise<string> {
    const systemPrompt = 'You are a helpful code analysis assistant. Review the provided code and offer constructive feedback, suggestions for improvement, and identify any potential issues.';

    return this.chat(`Please analyze this code:\n\n\`\`\`typescript\n${codeContent}\n\`\`\``, systemPrompt);
  }
}

async function main(): Promise<void> {
  try {
    // Initialize the agent
    const agent = new ClaudeAgent();

    console.log('🤖 Claude TypeScript Agent - Ready to assist!');
    console.log('Type "quit" to exit\n');

    // Simple CLI interface (you'd typically want to use a library like readline)
    const readline = require('readline');
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });

    const askQuestion = (question: string): Promise<string> => {
      return new Promise((resolve) => {
        rl.question(question, resolve);
      });
    };

    while (true) {
      try {
        const userInput = await askQuestion('You: ');
        const input = userInput.trim();

        if (input.toLowerCase() === 'quit' || input.toLowerCase() === 'exit' || input.toLowerCase() === 'q') {
          console.log('Goodbye!');
          break;
        }

        if (!input) continue;

        process.stdout.write('Claude: ');
        const response = await agent.chat(input);
        console.log(response);
        console.log();

      } catch (error) {
        console.error(`Error: ${error instanceof Error ? error.message : 'Unknown error'}`);
      }
    }

    rl.close();

  } catch (error) {
    console.error('Failed to initialize Claude agent:', error);
    process.exit(1);
  }
}

// Run the main function
if (require.main === module) {
  main().catch(console.error);
}

export { ClaudeAgent };
EOF

    cat > "$template_dir/.env.example" << 'EOF'
ANTHROPIC_API_KEY=your_api_token_here
EOF

    log "TypeScript project template created"
}

# Create TypeScript project creation script
create_typescript_project_script() {
    local project_dir="$1"

    cat > "$project_dir/create-project.sh" << EOF
#!/bin/bash
# Create new Claude TypeScript project

if [[ \$# -eq 0 ]]; then
    echo "Usage: \$0 <project-name>"
    exit 1
fi

project_name="\$1"
template_dir="$project_dir/template"

if [[ ! -d "\$template_dir" ]]; then
    echo "❌ TypeScript template not found. Please run the installer again."
    exit 1
fi

# Copy template to new project directory
cp -r "\$template_dir" "\$project_name"

# Install dependencies
cd "\$project_name"
npm install

echo "✅ Created new TypeScript project: \$project_name"
echo ""
echo "Next steps:"
echo "  cd \$project_name"
echo "  cp .env.example .env"
echo "  # Edit .env with your API token"
echo "  npm start"
EOF

    chmod +x "$project_dir/create-project.sh"

    log "TypeScript project creation script created"
}

# Save installation configuration
save_configuration() {
    cat > "$CONFIG_DIR/config.json" << EOF
{
  "installationType": "$INSTALLATION_TYPE",
  "version": "$INSTALLER_VERSION",
  "installedAt": "$(date -Iseconds)",
  "apiTokenConfigured": true,
  "apiEndpoint": "${API_ENDPOINT:-https://api.anthropic.com}",
  "paths": {
    "configDir": "$CONFIG_DIR",
    "logFile": "$LOG_FILE"
  }
}
EOF

    log "Installation configuration saved"
}

# Display completion message
show_completion() {
    header "Installation Complete!"

    case $INSTALLATION_TYPE in
        "claude-code-cli")
            echo -e "${GREEN}✅ Claude Code CLI${NC} has been successfully installed!"
            echo ""
            echo "Your Claude Code environment includes:"
            echo "• Claude Code CLI binary"
            echo "• Custom system prompts and templates"
            echo "• Slash commands for enhanced functionality"
            echo "• Permission escalation capabilities"
            echo "• Docker integration support"
            echo ""
            echo "🚀 Start using Claude Code:"
            echo "1. Restart your terminal or run: source ~/.bashrc"
            echo "2. Navigate to your project directory"
            echo "3. Run: claude"
            echo ""
            ;;
        "claude-python-sdk")
            echo -e "${GREEN}✅ Claude Agent Python SDK${NC} has been successfully installed!"
            echo ""
            echo "Your Python SDK environment includes:"
            echo "• Anthropic Python SDK in virtual environment"
            echo "• Project templates and examples"
            echo "• Development tools and utilities"
            echo "• Activation scripts for easy setup"
            echo ""
            echo "🚀 Start building Python agents:"
            echo "1. Activate environment: source ~/config/claude-universal/activate-python.sh"
            echo "2. Create project: claude-python-create myagent"
            echo "3. Run your agent: cd myagent && python main.py"
            echo ""
            ;;
        "claude-typescript-sdk")
            echo -e "${GREEN}✅ Claude Agent TypeScript SDK${NC} has been successfully installed!"
            echo ""
            echo "Your TypeScript SDK environment includes:"
            echo "• Anthropic TypeScript SDK"
            echo "• Project templates with TypeScript configuration"
            echo "• Development scripts and utilities"
            echo "• npm-based project management"
            echo ""
            echo "🚀 Start building TypeScript agents:"
            echo "1. Create project: ~/config/claude-universal/claude-typescript-projects/create-project.sh myagent"
            echo "2. Navigate to project: cd myagent"
            echo "3. Run your agent: npm start"
            echo ""
            ;;
    esac

    echo "📚 Documentation and Resources:"
    echo "• Installation log: $LOG_FILE"
    echo "• Configuration directory: $CONFIG_DIR"
    echo "• Anthropic documentation: https://docs.anthropic.com/"
    echo ""

    echo "🔧 Configuration:"
    echo "• API Token: ✓ Configured"
    echo "• API Endpoint: ${API_ENDPOINT:-https://api.anthropic.com}"
    echo "• Installation type: $INSTALLATION_TYPE"
    echo "• Version: $INSTALLER_VERSION"
    echo ""

    echo "Thank you for using Claude Universal Installer! 🎉"
}

# Uninstall functionality
uninstall_claude() {
    header "Uninstalling Claude"

    # Detect existing installations with detailed information
    local installations=()
    local installation_details=()

    # Check for Claude Code CLI
    if command -v claude >/dev/null 2>&1; then
        local claude_version=$(claude --version 2>/dev/null || echo "unknown version")
        local claude_path=$(command -v claude)
        installations+=("claude-code-cli")
        installation_details+=("Claude Code CLI: $claude_path ($claude_version)")
    fi

    # Check for Python SDK installations
    if [[ -d "$HOME/.claude-universal/claude-python-env" ]]; then
        local python_version=""
        if [[ -f "$HOME/.claude-universal/claude-python-env/bin/python" ]]; then
            python_version=$("$HOME/.claude-universal/claude-python-env/bin/python" --version 2>/dev/null || echo "unknown version")
        fi
        installations+=("claude-python-sdk")
        installation_details+=("Claude Python SDK: $HOME/.claude-universal/claude-python-env ($python_version)")
    fi

    # Check for TypeScript SDK installations
    if [[ -d "$HOME/.claude-universal/claude-typescript-projects" ]]; then
        local node_version=""
        if command -v node >/dev/null 2>&1; then
            node_version=$(node --version 2>/dev/null || echo "unknown version")
        fi
        installations+=("claude-typescript-sdk")
        installation_details+=("Claude TypeScript SDK: $HOME/.claude-universal/claude-typescript-projects ($node_version)")
    fi

    # Check for configuration files
    if [[ -f "$HOME/.claude-universal/config.json" ]]; then
        local config_type=$(jq -r '.installationType' "$HOME/.claude-universal/config.json" 2>/dev/null || echo "unknown")
        if [[ "$config_type" != "unknown" ]] && [[ ! " ${installations[*]} " =~ " ${config_type} " ]]; then
            installations+=("$config_type")
            installation_details+=("Configuration: $HOME/.claude-universal/config.json (type: $config_type)")
        fi
    fi

    if [[ ${#installations[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No Claude installations found to uninstall.${NC}"
        echo ""
        echo "Checked locations:"
        echo "• Claude Code CLI binary in PATH"
        echo "• Python SDK virtual environment"
        echo "• TypeScript SDK projects"
        echo "• Configuration files in $HOME/.claude-universal"
        echo "• Docker images with 'claude' in name"
        echo ""
        echo "If you believe Claude is installed, it may be in a custom location."
        return 0
    fi

    echo -e "${GREEN}Found the following Claude installations to uninstall:${NC}"
    echo ""
    for detail in "${installation_details[@]}"; do
        echo -e "${CYAN}✓${NC} $detail"
    done
    echo ""

    read -p "Do you want to uninstall all found installations? (y/N): " confirm_uninstall
    if [[ ! $confirm_uninstall =~ ^[Yy]$ ]]; then
        echo "Uninstall cancelled."
        return 0
    fi

    echo ""
    echo "Starting uninstall process..."

    # Uninstall Claude Code CLI
    if [[ " ${installations[*]} " =~ " claude-code-cli " ]]; then
        uninstall_claude_code_cli
    fi

    # Uninstall Python SDK
    if [[ " ${installations[*]} " =~ " claude-python-sdk " ]]; then
        uninstall_claude_python_sdk
    fi

    # Uninstall TypeScript SDK
    if [[ " ${installations[*]} " =~ " claude-typescript-sdk " ]]; then
        uninstall_claude_typescript_sdk
    fi

    # Clean up common files
    cleanup_common_files

    echo ""
    echo "✅ Claude uninstallation completed"
    echo ""
    echo "Removed components:"
    for installation in "${installations[@]}"; do
        echo "• $installation"
    done
    echo ""
    echo "Note: Some files may require manual removal if they were installed"
    echo "with elevated permissions or in system directories."
}

uninstall_claude_code_cli() {
    echo "Uninstalling Claude Code CLI..."

    # Remove binary if we can find it
    local claude_binary=$(command -v claude 2>/dev/null || true)
    if [[ -n "$claude_binary" ]]; then
        echo "Removing Claude Code CLI binary: $claude_binary"
        rm -f "$claude_binary" 2>/dev/null || warn "Could not remove binary (may need sudo)"
    fi

    # Remove from PATH in shell configs
    local shell_files=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile")
    local install_dir="$HOME/.local/bin"

    for shell_file in "${shell_files[@]}"; do
        if [[ -f "$shell_file" ]]; then
            # Remove the PATH export line
            sed -i.bak "/export PATH=\".*$install_dir.*\"/d" "$shell_file" 2>/dev/null || true
            echo "Removed PATH configuration from $shell_file"
        fi
    done

    # Remove configuration directory
    if [[ -d "$HOME/.claude" ]]; then
        echo "Removing Claude Code CLI configuration: $HOME/.claude"
        rm -rf "$HOME/.claude" 2>/dev/null || warn "Could not remove configuration directory"
    fi

    log "Claude Code CLI uninstalled"
}

uninstall_claude_python_sdk() {
    echo "Uninstalling Claude Python SDK..."

    # Remove virtual environment
    local venv_dir="$HOME/.claude-universal/claude-python-env"
    if [[ -d "$venv_dir" ]]; then
        echo "Removing Python virtual environment: $venv_dir"
        rm -rf "$venv_dir"
    fi

    # Remove activation and project scripts
    local script_dir="$HOME/.claude-universal"
    for script in "activate-python.sh" "claude-python-create"; do
        if [[ -f "$script_dir/$script" ]]; then
            echo "Removing script: $script_dir/$script"
            rm -f "$script_dir/$script"
        fi
    done

    # Remove Python template if it exists
    local template_dir="$script_dir/python-template"
    if [[ -d "$template_dir" ]]; then
        echo "Removing Python template: $template_dir"
        rm -rf "$template_dir"
    fi

    log "Claude Python SDK uninstalled"
}

uninstall_claude_typescript_sdk() {
    echo "Uninstalling Claude TypeScript SDK..."

    # Remove TypeScript projects directory
    local projects_dir="$HOME/.claude-universal/claude-typescript-projects"
    if [[ -d "$projects_dir" ]]; then
        echo "Removing TypeScript projects: $projects_dir"
        rm -rf "$projects_dir"
    fi

    log "Claude TypeScript SDK uninstalled"
}

cleanup_common_files() {
    echo "Cleaning up common files..."

    # Remove configuration directory
    local config_dir="$HOME/.claude-universal"
    if [[ -d "$config_dir" ]]; then
        echo "Removing configuration directory: $config_dir"
        rm -rf "$config_dir"
    fi

    # Remove any remaining Claude-related files in common locations
    local common_locations=(
        "$HOME/.claude-python"
        "$HOME/.claude-typescript"
        "$HOME/.claude-config"
    )

    for location in "${common_locations[@]}"; do
        if [[ -d "$location" ]]; then
            echo "Removing directory: $location"
            rm -rf "$location"
        fi
    done

    # Remove log files
    local log_files=(
        "$HOME/.claude-universal.log"
        "$HOME/.claude-install.log"
        "$HOME/.claude-uninstall.log"
    )

    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            echo "Removing log file: $log_file"
            rm -f "$log_file"
        fi
    done

    log "Common cleanup completed"
}

# Main installation flow
main() {
    setup_config

    # Quick requirements check
    check_requirements

    select_installation_type

    # Handle uninstall option
    if [[ "$INSTALLATION_TYPE" == "uninstall" ]]; then
        uninstall_claude
        return 0
    fi

    configure_api

    # Run installation based on selection
    case $INSTALLATION_TYPE in
        "claude-code-cli")
            install_claude_code_cli
            ;;
        "claude-python-sdk")
            install_claude_python_sdk
            ;;
        "claude-typescript-sdk")
            install_claude_typescript-sdk
            ;;
        *)
            error "Unknown installation type: $INSTALLATION_TYPE"
            exit 1
            ;;
    esac

    save_configuration

    show_completion
}

# Check if script is being run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi