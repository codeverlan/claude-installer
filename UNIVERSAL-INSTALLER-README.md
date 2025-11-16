# Claude Universal Installer - Complete Installation System

A comprehensive installation system that allows users to choose between Claude Code CLI, Python SDK, or TypeScript SDK with full customization and unified interface support.

## 🚀 Quick Start

### One-Command Installation
```bash
# Download and run the installer in a single command
curl -fsSL https://raw.githubusercontent.com/codeverlan/claude-code-customized/main/claude-universal-installer.sh | bash
```

### Alternative: Download and Run
```bash
# Download the installer
curl -fsSL https://raw.githubusercontent.com/codeverlan/claude-code-customized/main/claude-universal-installer.sh -o claude-universal-installer.sh
chmod +x claude-universal-installer.sh

# Run the installer
./claude-universal-installer.sh
```

## 🔍 Installation Detection Feature

The installer automatically detects and displays all existing Claude installations on your system before presenting installation options. This feature helps you:

- **See what's already installed**: Displays all Claude installations with versions and paths
- **Avoid duplicate installations**: Shows existing CLI, SDK, and configuration files
- **Make informed decisions**: Complete overview of your current Claude setup

### What Gets Detected

**Claude Code CLI:**
- Binary location and version
- Installation path in system PATH

**Python SDK:**
- Virtual environment location
- Python version information

**TypeScript SDK:**
- Project directory location
- Node.js version information

**Configuration Files:**
- Universal installer configurations
- Claude CLI settings in `~/.claude`

**Docker Images:**
- All Docker images containing "claude" in the name
- Repository and tag information

### Example Output

```
=== Existing Claude Installations ===
Found the following Claude installations:

✓ Claude Code CLI: /usr/local/bin/claude (claude-code v1.0.0)
✓ Claude Python SDK: /home/user/.claude-universal/claude-python-env (Python 3.9.7)
✓ Configuration files: /home/user/.claude-universal (2 config files)
✓ Docker image: thornlcsw/claude-code-customized:latest

=== Welcome to Claude Universal Installer ===
```

### Available Options

**1. Claude Code CLI** 🖥️ (Install)
- Terminal-based AI coding assistant
- Custom system prompts and slash commands
- Docker integration
- MCP server connectivity

**2. Python SDK** 🐍 (Install)
- Virtual environment with Anthropic SDK
- Project templates and examples
- Async/await patterns
- Data science integration

**3. TypeScript SDK** 📜 (Install)
- Node.js environment with TypeScript
- Web application templates
- Real-time communication support
- npm ecosystem integration

**4. Uninstall Claude** 🗑️ (Remove)
- Detect and uninstall any Claude installation
- Clean up configuration files and directories
- Remove system integration and PATH modifications
- Complete removal of Claude setup

## 📋 System Requirements

### Minimum Requirements
- **Operating System**: Linux, macOS, or Windows (WSL2)
- **Memory**: 2GB RAM minimum
- **Storage**: 1GB free space
- **Network**: Internet connection for API access

### Recommended Requirements
- **Operating System**: Ubuntu 22.04+ or macOS 12+
- **Memory**: 4GB+ RAM
- **Storage**: 5GB+ free space
- **Node.js**: v18+ (for TypeScript SDK)
- **Python**: 3.8+ (for Python SDK)
- **Docker**: Latest version (for container integration)

## 🛠️ Installation Options

### Option 1: Claude Code CLI (Recommended for Beginners)

**Perfect for:**
- Day-to-day development tasks
- Terminal-based workflows
- Direct file editing
- System administration

**Features:**
- Interactive terminal interface
- Built-in system prompts
- Automatic sudo escalation
- Native Docker support
- MCP server integration

**Installation Commands:**
```bash
# After installation
export PATH="$PATH:$HOME/.local/bin"
claude  # Start using immediately
```

### Option 2: Python SDK (Recommended for Developers)

**Perfect for:**
- Custom AI applications
- Data science projects
- Backend API development
- Automation scripts

**Features:**
- Async/await support
- Virtual environment isolation
- Permission management
- Package ecosystem (pandas, numpy, fastapi)
- Jupyter notebook compatibility

**Installation Commands:**
```bash
# After installation
source ~/.claude-universal/activate-python.sh
claude-python-create myproject
cd myproject
python main.py
```

### Option 3: TypeScript SDK (Recommended for Web Developers)

**Perfect for:**
- Web applications
- Real-time services
- Full-stack development
- Node.js projects

**Features:**
- Modern TypeScript patterns
- npm ecosystem
- Real-time communication
- Web framework templates
- Cross-platform support

**Installation Commands:**
```bash
# After installation
cd ~/.claude-universal/claude-typescript-projects
./create-project.sh myproject
cd myproject
npm start
```

## 🔧 Configuration

### API Token & Endpoint Setup
During installation, you'll be prompted to configure:

1. **API Token** - Get your token from [Anthropic Console](https://console.anthropic.com/)
2. **API Endpoint** - Choose from available options:
   - Official Anthropic API (default)
   - Z.AI Proxy
   - AnyRouter
   - OpenRouter
   - Custom endpoint

The installer will automatically configure these settings for you.

### Configuration File Location
- **Linux/macOS**: `~/.claude-universal/config.json`
- **Windows**: `%USERPROFILE%\.claude-universal\config.json`

### Default Configuration
```json
{
  "installationType": "claude-code-cli",
  "apiToken": "your-api-token",
  "model": "claude-3-5-sonnet-20241022",
  "features": {
    "streaming": true,
    "contextManagement": true,
    "customCommands": true
  }
}
```

## 🎯 Usage Examples

### Claude Code CLI
```bash
# Start Claude Code
claude

# Use slash commands
claude /system-prompt use code-review
claude /sudo check
claude /prompt list

# Natural language commands
"Create a REST API for user management"
"Debug this authentication issue"
"Refactor this database query"
```

### Python SDK
```python
from anthropic import Anthropic
import asyncio

async def main():
    client = Anthropic(api_key="your-api-key")

    response = await client.messages.create(
        model="claude-3-5-sonnet-20241022",
        max_tokens=1000,
        messages=[{"role": "user", "content": "Hello, Claude!"}]
    )

    print(response.content[0].text)

asyncio.run(main())
```

### TypeScript SDK
```typescript
import { Anthropic } from '@anthropic-ai/sdk';

const anthropic = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY,
});

async function chat() {
  const response = await anthropic.messages.create({
    model: 'claude-3-5-sonnet-20241022',
    max_tokens: 1000,
    messages: [{ role: 'user', content: 'Hello, Claude!' }]
  });

  console.log(response.content[0].type === 'text'
    ? response.content[0].text
    : 'No text response');
}

chat();
```

## 🔒 Security & Permissions

### Permission Management
Each SDK includes comprehensive permission management:

**Python SDK:**
```python
from permission_manager import PythonPrivileges

privileges = PythonPrivileges()
privileges.install_system_package("requests")
privileges.setup_development_environment("requirements.txt")
```

**TypeScript SDK:**
```typescript
import { TypeScriptPrivileges } from './permission-manager';

const privileges = new TypeScriptPrivileges();
await privileges.installGlobalPackage('typescript');
await privileges.setupDevelopmentEnvironment('./my-project');
```

**Claude Code CLI:**
```bash
# Automatic permission escalation
mkdir -p /usr/local/custom-tool  # Automatically retries with sudo
pip install global-package      # Escalates when needed

# Manual permission management
/sudo check
/sudo exec systemctl status nginx
```

### Audit Logging
All privileged operations are logged to:
- **Python**: `~/.claude-python/audit.log`
- **TypeScript**: `~/.claude-typescript/audit.log`
- **CLI**: `~/.claude/audit.log`

## 🎨 Customization

### System Prompts
All SDKs support custom system prompts:

```bash
# CLI
claude /system-prompt use development-focus
claude /prompts list

# Python
from system_prompts import load_prompt
prompt = load_prompt("python-sdk/agent-workflow")

# TypeScript
import { loadPrompt } from './system-prompts';
const prompt = loadPrompt('typescript-sdk/nodejs-workflow');
```

### Custom Commands
Create your own commands and workflows:

```bash
# CLI custom commands
claude /custom create my-command
claude /my-command "some parameters"

# Python custom functions
def custom_workflow():
    # Your custom logic here
    pass

# TypeScript custom methods
class CustomAgent {
    async customWorkflow() {
        // Your custom logic here
    }
}
```

## 🐳 Docker Integration

### Using with Docker
```bash
# Pull the customized image
docker pull thornlcsw/claude-code-customized:latest

# Run with your API token
docker run -d --name claude \
  -e ANTHROPIC_AUTH_TOKEN="your-token" \
  -v $(pwd):/workspace \
  thornlcsw/claude-code-customized:latest

# Access the container
docker exec -it claude bash
```

### Docker Compose
```yaml
version: '3.8'
services:
  claude:
    image: thornlcsw/claude-code-customized:latest
    environment:
      - ANTHROPIC_AUTH_TOKEN=${ANTHROPIC_AUTH_TOKEN}
      - CLAUDE_DEFAULT_BASE_PROMPT=base/dev-focused.md
    volumes:
      - ./workspace:/workspace
      - ./claude-binary:/claude-binaries:ro
```

## 🔄 Unified Interface

The unified interface provides consistent commands across all SDKs:

```bash
# Universal commands (work with any SDK)
claude-unified chat "Help me debug this code"
claude-unified analyze ./src/main.py
claude-unified create project myapp --type web-api
claude-unified config set model claude-3-5-sonnet
claude-unified status

# Switch between SDKs
claude-unified config set sdk python-sdk
claude-unified migrate --from cli --to python
```

## 🗑️ Uninstallation

### Automatic Uninstallation
The installer includes a comprehensive uninstall feature that detects and removes all Claude installations with detailed information:

```bash
# Run the installer and choose option 4 (Uninstall Claude)
./claude-universal-installer.sh
```

**Enhanced Detection:** The uninstaller scans your system and displays:
- All installed Claude components with versions and paths
- Configuration files and their locations
- Docker images related to Claude
- Complete overview before asking for confirmation

### What Gets Uninstalled

**Claude Code CLI:**
- Binary executable from PATH
- Shell configuration (PATH exports)
- Configuration directory (`~/.claude`)
- System integration files

**Python SDK:**
- Virtual environment
- Activation scripts
- Project templates
- Configuration files

**TypeScript SDK:**
- Project directories
- Templates and configurations
- npm-related files

**Common Files:**
- Configuration directory (`~/.claude-universal`)
- Log files
- Temporary files
- Backup files created during installation

### Manual Uninstallation (if needed)

If the automatic uninstall doesn't work, you can manually remove:

```bash
# Remove configuration directory
rm -rf ~/.claude-universal

# Remove Claude Code CLI
rm -f ~/.local/bin/claude
rm -rf ~/.claude

# Remove from shell configurations
# Edit ~/.bashrc, ~/.zshrc, ~/.profile and remove PATH lines

# Remove log files
rm -f ~/.claude-universal.log ~/.claude-install.log
```

### Safety Features

- **Detection Only**: Uninstaller first detects what's installed before removing anything
- **Confirmation Required**: User must confirm before any removal occurs
- **Backup Protection**: Shell configuration files are backed up before modification
- **Non-Destructive**: Only removes files specifically created by the installer

## 🛠️ Troubleshooting

### Common Issues

**API Token Issues:**
```bash
# Check if token is set
echo $ANTHROPIC_AUTH_TOKEN

# Set token temporarily
export ANTHROPIC_AUTH_TOKEN="sk-ant-your-token"

# Set token permanently
echo 'export ANTHROPIC_AUTH_TOKEN="sk-ant-your-token"' >> ~/.bashrc
```

**Permission Issues:**
```bash
# Check sudo access
sudo -n true

# Configure passwordless sudo (if needed)
echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/claude
```

**Python Environment Issues:**
```bash
# Recreate virtual environment
rm -rf ~/.claude-universal/claude-python-env
source ~/.claude-universal/activate-python.sh

# Reinstall packages
pip install --upgrade anthropic
```

**TypeScript/Node.js Issues:**
```bash
# Reinstall dependencies
cd ~/.claude-universal/claude-typescript-projects
rm -rf node_modules package-lock.json
npm install

# Update npm
npm install -g npm@latest
```

### Getting Help

1. **Check logs**: Look in `~/.claude-universal/install.log`
2. **Verify configuration**: Check `~/.claude-universal/config.json`
3. **Test API connection**: Try a simple chat message
4. **Check permissions**: Ensure necessary permissions are available
5. **Reinstall**: Run the installer again if needed

### Support Resources

- **Documentation**: [Full documentation](https://github.com/codeverlan/claude-code-customized)
- **Issues**: [GitHub Issues](https://github.com/codeverlan/claude-code-customized/issues)
- **Community**: [Discussions](https://github.com/codeverlan/claude-code-customized/discussions)
- **Docker Hub**: [thornlcsw/claude-code-customized](https://hub.docker.com/r/thornlcsw/claude-code-customized)

## 📊 Feature Comparison

| Feature | Claude Code CLI | Python SDK | TypeScript SDK |
|---------|-----------------|------------|----------------|
| **Ease of Use** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| **Customization** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Performance** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Integration** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| **Web Development** | ⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Data Science** | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ |
| **Terminal Access** | ⭐⭐⭐⭐⭐ | ❌ | ❌ |
| **Async Support** | N/A | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Cross-Platform** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

## 🚀 Next Steps

1. **Choose your SDK** based on your use case
2. **Run the installer**: `./claude-universal-installer.sh`
3. **Configure your API token**
4. **Start building** with Claude!
5. **Explore customization** options
6. **Join the community** for support and inspiration

---

**Happy coding with Claude! 🎉**

Choose the installation path that best fits your needs and start building amazing things with Claude today.