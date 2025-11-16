# Unified Claude Interface

Provides a consistent interface and user experience across all Claude SDK implementations (CLI, Python, TypeScript).

## Overview

The unified interface abstracts away the differences between SDK implementations while preserving their unique capabilities. Users can switch between SDKs without learning new commands or patterns.

## Core Features

### 1. Consistent Command Structure
All SDKs support the same basic commands:
- `claude chat <message>` - Send a message to Claude
- `claude analyze <file>` - Analyze code or files
- `claude create <type>` - Create new projects/templates
- `claude config <setting>` - Configure the environment
- `claude status` - Show current status and configuration

### 2. Unified Configuration
- Single configuration file format
- Consistent environment variables
- Shared system prompt management
- Common permission handling patterns

### 3. Cross-SDK Compatibility
- Project templates work across SDKs
- System prompts are portable
- Configuration can be migrated
- Audit logs have consistent format

## Interface Components

### CLI Interface (claude-unified)
```bash
# Universal commands that work with any SDK
claude-unified chat "Help me debug this code"
claude-unified analyze ./src/main.py
claude-unified create project myapp --type web
claude-unified config set model claude-3-5-sonnet
claude-unified status
```

### Python Interface
```python
from claude_unified import ClaudeInterface

# Works regardless of backend SDK
interface = ClaudeInterface()
response = await interface.chat("Explain this code")
analysis = await interface.analyze_file("./main.py")
```

### TypeScript Interface
```typescript
import { ClaudeInterface } from 'claude-unified';

// Works regardless of backend SDK
const interface = new ClaudeInterface();
const response = await interface.chat('Explain this code');
const analysis = await interface.analyzeFile('./main.ts');
```

## SDK-Specific Features

While maintaining a consistent interface, each SDK preserves its unique capabilities:

### Claude Code CLI
- Terminal integration and file operations
- Direct command execution
- Shell integration
- MCP server connectivity

### Python SDK
- Async/await patterns
- Data science integration
- Package ecosystem (pandas, numpy)
- Jupyter notebook support

### TypeScript SDK
- Web application integration
- Node.js ecosystem
- Real-time communication
- Full-stack development

## Configuration Management

### Global Configuration (`~/.claude-universal/config.json`)
```json
{
  "defaultSdk": "claude-code-cli",
  "apiToken": "sk-ant-...",
  "model": "claude-3-5-sonnet-20241022",
  "systemPrompts": {
    "base": "professional",
    "codeAnalysis": "detailed"
  },
  "permissions": {
    "autoEscalate": false,
    "auditLogging": true
  },
  "features": {
    "streaming": true,
    "contextManagement": true,
    "customCommands": true
  }
}
```

### Project Configuration (`./claude-project.json`)
```json
{
  "sdk": "python-sdk",
  "projectType": "web-api",
  "systemPrompts": ["base-personality", "web-development"],
  "dependencies": ["fastapi", "anthropic"],
  "permissions": {
    "level": "basic",
    "allowedOperations": ["file-read", "network"]
  }
}
```

## Migration Tools

### SDK Migration
```bash
# Convert project from one SDK to another
claude-unified migrate --from python --to typescript
claude-unified migrate --from cli --to python

# Export/Import configuration
claude-unified export config > my-config.json
claude-unified import config < my-config.json
```

### Project Templates
```bash
# Create project with specific SDK but portable structure
claude-unified create project myapp --sdk python --template web-api
claude-unified create project myapp --sdk typescript --template web-api

# Both create compatible project structures
```

## Implementation Architecture

### Abstraction Layer
```
User Interface
     ↓
Unified API Layer
     ↓
SDK Adapters
     ↓
Specific SDK Implementation
```

### Adapter Pattern
Each SDK has an adapter that implements the unified interface:
- `CliAdapter` - Claude Code CLI adapter
- `PythonAdapter` - Python SDK adapter
- `TypeScriptAdapter` - TypeScript SDK adapter

### Plugin System
- Custom commands can be added to any SDK
- System prompts are shared across SDKs
- Permission handlers are pluggable
- Audit loggers are swappable

## Usage Examples

### Development Workflow
```bash
# 1. Create a new project (portable across SDKs)
claude-unified create project myapp --type web-api

# 2. Start development (uses configured SDK)
cd myapp
claude-unified dev

# 3. Get help (context-aware based on project type)
claude-unified chat "Help me implement user authentication"

# 4. Analyze code (works with any SDK)
claude-unified analyze src/auth.py

# 5. Switch SDKs if needed
claude-unified config set sdk typescript-sdk
claude-unified migrate --current-project
```

### CI/CD Integration
```yaml
# GitHub Actions example
- name: Run Claude Analysis
  run: |
    claude-unified analyze ./src --format json > analysis.json
    claude-unified chat "Review this PR" --context pr.json
```

### Team Collaboration
```bash
# Share configuration
claude-unified export team-config > team-claude.json
# Team members import:
claude-unified import config < team-claude.json

# Share prompts
claude-unified prompt share "code-review" --team
claude-unified prompt install "code-review" --from @teammate
```

## Benefits

1. **Consistency**: Same commands and patterns across SDKs
2. **Flexibility**: Choose the best SDK for each use case
3. **Portability**: Projects can be migrated between SDKs
4. **Productivity**: Less learning curve when switching SDKs
5. **Collaboration**: Teams can use different SDKs harmoniously
6. **Future-Proof**: Easy to add new SDKs or features

The unified interface ensures that regardless of which Claude implementation you choose, you have a consistent, productive experience that leverages the unique strengths of each SDK while maintaining compatibility and portability.