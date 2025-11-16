# SDK-Specific System Prompt Management

This directory contains system prompt templates and management utilities for each Claude SDK implementation.

## Directory Structure

```
sdk-system-prompts/
├── README.md                    # This file
├── shared/                      # Shared prompts across all SDKs
│   ├── base-personality.md      # Core Claude personality
│   ├── code-analysis.md         # Code review and analysis
│   └── debugging.md             # Debugging assistance
├── claude-code-cli/             # Claude Code CLI specific prompts
│   ├── terminal-interaction.md  # Terminal-based interactions
│   ├── file-operations.md       # File editing and management
│   └── slash-commands.md        # Custom slash command responses
├── python-sdk/                  # Python SDK specific prompts
│   ├── agent-workflow.md        # Python agent workflows
│   ├── async-patterns.md        # Async/await patterns
│   └── python-ecosystem.md      # Python-specific integrations
├── typescript-sdk/              # TypeScript SDK specific prompts
│   ├── nodejs-workflow.md       # Node.js environment patterns
│   ├── typescript-patterns.md   # TypeScript development
│   └── web-integration.md       # Web app integration
└── templates/                   # Code templates for each SDK
    ├── python-agent.py          # Python agent template
    ├── typescript-agent.ts      # TypeScript agent template
    └── system-prompts.json      # Configuration file
```

## Usage

### Claude Code CLI
System prompts are automatically integrated into the CLI configuration and can be triggered via slash commands.

### Python SDK
```python
from sdk_system_prompts import load_prompt, PythonPrompts

# Load a specific prompt
system_prompt = load_prompt('python-sdk/agent-workflow.md')

# Use predefined prompts
response = agent.chat("Help me debug this", system_prompt=PythonPrompts.DEBUGGING)
```

### TypeScript SDK
```typescript
import { loadPrompt, TypeScriptPrompts } from './sdk-system-prompts';

// Load a specific prompt
const systemPrompt = loadPrompt('typescript-sdk/nodejs-workflow.md');

// Use predefined prompts
const response = await agent.chat("Help me build a web app", {
  systemPrompt: TypeScriptPrompts.WEB_INTEGRATION
});
```

## Integration Matrix

| Feature | Claude Code CLI | Python SDK | TypeScript SDK |
|---------|-----------------|------------|----------------|
| Base Personality | ✅ Built-in | ✅ Template | ✅ Template |
| Code Analysis | ✅ Specialized | ✅ Adapted | ✅ Adapted |
| File Operations | ✅ Native | ⚠️ Limited | ⚠️ Limited |
| Async Patterns | N/A | ✅ Full | ✅ Full |
| Web Integration | N/A | ⚠️ Custom | ✅ Native |
| Terminal Access | ✅ Native | ❌ No | ❌ No |