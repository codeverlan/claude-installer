#!/bin/bash

# Claude Universal Installer - TypeScript SDK Installation Module
# Handles installation of Claude Agent TypeScript SDK with project templates and tooling

set -eo pipefail

# Source core utilities and modules
source "$(dirname "${BASH_SOURCE[0]}")/../lib/core.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/config-manager.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/detection.sh"

# TypeScript SDK configuration
readonly TYPESCRIPT_SDK_VERSION="latest"
readonly ANTHROPIC_TYPESCRIPT_PACKAGE="@anthropic-ai/sdk"
readonly TYPESCRIPT_VERSION="^5.0.0"
readonly NODE_MIN_VERSION="18.0.0"
readonly NPM_MIN_VERSION="8.0.0"

# Core TypeScript packages
readonly CORE_PACKAGES=(
    "$ANTHROPIC_TYPESCRIPT_PACKAGE"
    "typescript"
    "@types/node"
    "ts-node"
    "tsx"
)

# Development and utility packages
readonly DEV_PACKAGES=(
    "dotenv"
    "nodemon"
    "jest"
    "@types/jest"
    "ts-jest"
    "eslint"
    "@typescript-eslint/eslint-plugin"
    "@typescript-eslint/parser"
    "prettier"
    "concurrently"
    "rimraf"
)

# Check Node.js and npm installation
check_node_requirements() {
    log "Checking Node.js requirements..."

    # Check Node.js
    if ! command -v node >/dev/null 2>&1; then
        error "Node.js is required but not installed."
        echo "Please install Node.js (${NODE_MIN_VERSION} or later) and try again."
        echo ""
        echo "Installation options:"
        echo "  • Official installer: https://nodejs.org"
        echo "  • Version manager: nvm (https://github.com/nvm-sh/nvm)"
        echo "  • Package manager: brew install node (macOS)"
        return 1
    fi

    # Check Node.js version
    local node_version
    node_version=$(node --version 2>/dev/null | sed 's/^v//')

    if [[ -z "$node_version" ]]; then
        error "Failed to determine Node.js version"
        return 1
    fi

    log "Found Node.js version: $node_version"

    # Simple version comparison
    if ! node -e "process.exit(require('semver').gte('$node_version', '$NODE_MIN_VERSION') ? 0 : 1)" 2>/dev/null; then
        error "Node.js ${NODE_MIN_VERSION} or later is required. Found: $node_version"
        return 1
    fi

    # Check npm
    if ! command -v npm >/dev/null 2>&1; then
        error "npm is required but not found"
        return 1
    fi

    local npm_version
    npm_version=$(npm --version 2>/dev/null)
    log "Found npm version: $npm_version"

    success "Node.js requirements check passed"
    return 0
}

# Create TypeScript project structure
create_typescript_project_structure() {
    local project_dir="$1"

    log "Creating TypeScript project structure..."

    # Create main project directory
    safe_mkdir "$project_dir"

    # Create subdirectories
    local directories=(
        "src"
        "tests"
        "dist"
        "types"
        "scripts"
        "examples"
        "docs"
    )

    for dir in "${directories[@]}"; do
        safe_mkdir "$project_dir/$dir"
    done

    success "TypeScript project structure created"
}

# Initialize npm project with enhanced package.json
initialize_npm_project() {
    local project_dir="$1"

    log "Initializing npm project..."

    cd "$project_dir"

    # Create package.json with enhanced configuration
    cat > package.json << 'EOF'
{
  "name": "claude-typescript-agent",
  "version": "1.0.0",
  "description": "Claude Agent built with TypeScript and Node.js",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "scripts": {
    "build": "tsc",
    "build:watch": "tsc --watch",
    "start": "node dist/index.js",
    "dev": "tsx src/index.ts",
    "dev:watch": "tsx watch src/index.ts",
    "test": "jest",
    "test:watch": "jest --watch",
    "test:coverage": "jest --coverage",
    "lint": "eslint src/**/*.ts",
    "lint:fix": "eslint src/**/*.ts --fix",
    "format": "prettier --write src/**/*.ts",
    "format:check": "prettier --check src/**/*.ts",
    "clean": "rimraf dist",
    "prebuild": "npm run clean",
    "prestart": "npm run build"
  },
  "keywords": [
    "claude",
    "anthropic",
    "ai",
    "agent",
    "typescript",
    "nodejs"
  ],
  "author": "Claude Agent Developer",
  "license": "MIT",
  "engines": {
    "node": ">=18.0.0",
    "npm": ">=8.0.0"
  },
  "dependencies": {},
  "devDependencies": {}
}
EOF

    success "npm project initialized with enhanced package.json"
}

# Install TypeScript and development packages
install_typescript_packages() {
    local project_dir="$1"

    log "Installing TypeScript packages..."

    cd "$project_dir"

    # Install core packages
    log "Installing core packages..."
    if npm install "${CORE_PACKAGES[@]}"; then
        success "Core packages installed successfully"
    else
        error "Failed to install core packages"
        return 1
    fi

    # Install development packages
    log "Installing development packages..."
    if npm install --save-dev "${DEV_PACKAGES[@]}"; then
        success "Development packages installed successfully"
    else
        error "Failed to install development packages"
        return 1
    fi

    success "All TypeScript packages installed"
}

# Create TypeScript configuration
create_typescript_config() {
    local project_dir="$1"

    log "Creating TypeScript configuration..."

    cd "$project_dir"

    # Create tsconfig.json
    cat > tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022"],
    "module": "commonjs",
    "moduleResolution": "node",
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "removeComments": false,
    "noImplicitAny": true,
    "noImplicitReturns": true,
    "noImplicitThis": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "exactOptionalPropertyTypes": true,
    "noImplicitOverride": true,
    "noPropertyAccessFromIndexSignature": false,
    "allowSyntheticDefaultImports": true,
    "experimentalDecorators": true,
    "emitDecoratorMetadata": true
  },
  "include": [
    "src/**/*"
  ],
  "exclude": [
    "node_modules",
    "dist",
    "tests"
  ]
}
EOF

    # Create tsconfig.build.json (for production builds)
    cat > tsconfig.build.json << 'EOF'
{
  "extends": "./tsconfig.json",
  "compilerOptions": {
    "removeComments": true,
    "sourceMap": false
  },
  "exclude": [
    "node_modules",
    "dist",
    "tests",
    "**/*.test.ts",
    "**/*.spec.ts"
  ]
}
EOF

    # Create tsconfig.test.json (for tests)
    cat > tsconfig.test.json << 'EOF'
{
  "extends": "./tsconfig.json",
  "compilerOptions": {
    "outDir": "./dist/tests",
    "rootDir": "./tests",
    "types": ["jest", "node"]
  },
  "include": [
    "tests/**/*",
    "src/**/*"
  ]
}
EOF

    success "TypeScript configuration created"
}

# Create project template
create_typescript_project_template() {
    local project_dir="$1"
    local template_dir="$project_dir/template"

    log "Creating TypeScript project template..."

    # Create template directory
    safe_mkdir "$template_dir"
    safe_mkdir "$template_dir/src"

    # Create main index.ts
    cat > "$template_dir/src/index.ts" << 'EOF'
/**
 * Claude Agent TypeScript Template
 *
 * This template provides a starting point for building custom Claude agents
 * using the Anthropic TypeScript SDK with modern TypeScript patterns.
 */

import { Anthropic } from '@anthropic-ai/sdk';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

export interface AgentConfig {
    apiKey?: string;
    model?: string;
    maxTokens?: number;
    timeout?: number;
}

export interface ChatMessage {
    role: 'user' | 'assistant';
    content: string;
}

export interface ChatResponse {
    content: string;
    model: string;
    usage?: {
        inputTokens: number;
        outputTokens: number;
    };
}

/**
 * Main Claude Agent class
 */
export class ClaudeAgent {
    private client: Anthropic;
    private config: Required<AgentConfig>;

    constructor(config: AgentConfig = {}) {
        this.config = {
            apiKey: config.apiKey || process.env.ANTHROPIC_API_KEY || '',
            model: config.model || 'claude-3-5-sonnet-20241022',
            maxTokens: config.maxTokens || 1000,
            timeout: config.timeout || 30000,
        };

        if (!this.config.apiKey) {
            throw new Error(
                'API key is required. Set ANTHROPIC_API_KEY environment variable or pass apiKey in config.'
            );
        }

        this.client = new Anthropic({
            apiKey: this.config.apiKey,
            timeout: this.config.timeout,
        });
    }

    /**
     * Send a message to Claude and get response
     */
    async chat(message: string, systemPrompt?: string): Promise<ChatResponse> {
        try {
            const messages: ChatMessage[] = [
                { role: 'user', content: message }
            ];

            const response = await this.client.messages.create({
                model: this.config.model,
                max_tokens: this.config.maxTokens,
                system: systemPrompt,
                messages,
            });

            const content = response.content[0];
            if (content.type !== 'text') {
                throw new Error('Unexpected response type from Claude');
            }

            return {
                content: content.text,
                model: response.model,
                usage: response.usage ? {
                    inputTokens: response.usage.input_tokens,
                    outputTokens: response.usage.output_tokens,
                } : undefined,
            };
        } catch (error) {
            throw new Error(`Claude API error: ${error instanceof Error ? error.message : 'Unknown error'}`);
        }
    }

    /**
     * Stream a chat response from Claude
     */
    async *streamChat(message: string, systemPrompt?: string): AsyncGenerator<string> {
        try {
            const messages: ChatMessage[] = [
                { role: 'user', content: message }
            ];

            const stream = await this.client.messages.create({
                model: this.config.model,
                max_tokens: this.config.maxTokens,
                system: systemPrompt,
                messages,
                stream: true,
            });

            for await (const event of stream) {
                if (event.type === 'content_block_delta' && event.delta.type === 'text_delta') {
                    yield event.delta.text;
                }
            }
        } catch (error) {
            yield `Error: ${error instanceof Error ? error.message : 'Unknown error'}`;
        }
    }

    /**
     * Get current configuration
     */
    getConfig(): Readonly<Required<AgentConfig>> {
        return { ...this.config };
    }

    /**
     * Update configuration
     */
    updateConfig(newConfig: Partial<AgentConfig>): void {
        this.config = { ...this.config, ...newConfig };

        if (newConfig.apiKey) {
            this.client = new Anthropic({
                apiKey: newConfig.apiKey,
                timeout: this.config.timeout,
            });
        }
    }
}

/**
 * Main function for standalone execution
 */
async function main(): Promise<void> {
    try {
        console.log('🤖 Initializing Claude Agent (TypeScript)...');

        const agent = new ClaudeAgent();
        console.log('✅ Claude Agent initialized successfully!');

        console.log('\n💬 Sending test message to Claude...');

        const response = await agent.chat(
            'Hello! Please introduce yourself and explain what you can help with.',
            'You are a helpful AI assistant powered by Claude. Be concise but informative.'
        );

        console.log(`\n📝 Claude's response:\n${response.content}`);

        if (response.usage) {
            console.log(`\n📊 Token usage: ${response.usage.inputTokens} input, ${response.usage.outputTokens} output`);
        }

        console.log('\n✅ Example completed successfully!');
    } catch (error) {
        console.error(`❌ Error: ${error instanceof Error ? error.message : 'Unknown error'}`);
        process.exit(1);
    }
}

// Run main function if this file is executed directly
if (require.main === module) {
    main();
}
EOF

    # Create types file
    cat > "$template_dir/src/types.ts" << 'EOF'
/**
 * Type definitions for Claude Agent
 */

export interface AgentOptions {
    apiKey?: string;
    model?: string;
    maxTokens?: number;
    timeout?: number;
    baseUrl?: string;
}

export interface Message {
    role: 'user' | 'assistant';
    content: string;
}

export interface ChatOptions {
    systemPrompt?: string;
    temperature?: number;
    topP?: number;
    stopSequences?: string[];
}

export interface StreamOptions extends ChatOptions {
    onChunk?: (chunk: string) => void;
    onComplete?: (response: string) => void;
    onError?: (error: Error) => void;
}

export interface AgentMetrics {
    totalRequests: number;
    totalTokens: number;
    averageResponseTime: number;
    errorRate: number;
}

export interface ClaudeConfig {
    apiKey: string;
    model: string;
    maxTokens: number;
    temperature?: number;
    timeout: number;
}
EOF

    # Create .env.example
    cat > "$template_dir/.env.example" << 'EOF'
# Claude Agent TypeScript Environment Configuration
ANTHROPIC_API_KEY=your_api_key_here
CLAUDE_MODEL=claude-3-5-sonnet-20241022
NODE_ENV=development
LOG_LEVEL=info

# Optional: Custom API endpoint
# ANTHROPIC_BASE_URL=https://api.anthropic.com

# Optional: Request timeout (milliseconds)
# REQUEST_TIMEOUT=30000

# Optional: Max tokens per request
# MAX_TOKENS=1000
EOF

    # Create README.md
    cat > "$template_dir/README.md" << 'EOF'
# Claude Agent TypeScript Project

A modern TypeScript template for building custom Claude agents using the Anthropic TypeScript SDK with full type safety and best practices.

## Quick Start

1. **Set up your API key:**
   \`\`\`bash
   cp .env.example .env
   # Edit .env and add your Anthropic API key
   \`\`\`

2. **Install dependencies:**
   \`\`\`bash
   npm install
   \`\`\`

3. **Build and run:**
   \`\`\`bash
   npm run build
   npm start
   \`\`\`

4. **Or run in development mode:**
   \`\`\`bash
   npm run dev
   \`\`\`

## Project Structure

\`\`\`
├── src/
│   ├── index.ts           # Main entry point
│   └── types.ts           # Type definitions
├── tests/                 # Test files
├── dist/                  # Compiled JavaScript
├── package.json           # Dependencies and scripts
├── tsconfig.json          # TypeScript configuration
├── jest.config.js         # Jest testing configuration
└── .env.example          # Environment variables template
\`\`\`

## Available Scripts

- \`npm run build\` - Compile TypeScript to JavaScript
- \`npm run dev\` - Run in development mode with tsx
- \`npm run start\` - Run the compiled application
- \`npm test\` - Run tests
- \`npm run lint\` - Check code with ESLint
- \`npm run format\` - Format code with Prettier

## Usage Examples

### Basic Usage
\`\`\`typescript
import { ClaudeAgent } from './src/index';

const agent = new ClaudeAgent({
    model: 'claude-3-5-sonnet-20241022',
    maxTokens: 1000
});

const response = await agent.chat('Hello, Claude!');
console.log(response.content);
\`\`\`

### Streaming Chat
\`\`\`typescript
for await (const chunk of agent.streamChat('Tell me a story')) {
    process.stdout.write(chunk);
}
\`\`\`

### Advanced Configuration
\`\`\`typescript
const agent = new ClaudeAgent({
    apiKey: process.env.ANTHROPIC_API_KEY,
    model: 'claude-3-opus-20240229',
    maxTokens: 2000,
    timeout: 60000
});
\`\`\`

## Development

### Running Tests
\`\`\`bash
npm test
\`\`\`

### Code Quality
\`\`\`bash
npm run lint
npm run format
\`\`\`

### Type Checking
\`\`\`bash
npm run build
\`\`\`

## Features

- ✅ **Full TypeScript Support** with strict type checking
- ✅ **Modern ES2022+** features and syntax
- ✅ **Streaming Chat** support for real-time responses
- ✅ **Error Handling** with proper error types
- ✅ **Environment Configuration** with .env support
- ✅ **Testing Framework** setup with Jest
- ✅ **Code Quality** tools (ESLint, Prettier)
- ✅ **Hot Reloading** in development mode
- ✅ **Build Optimization** for production

## Configuration

Set the following environment variables in your \`.env\` file:

- \`ANTHROPIC_API_KEY\`: Your Anthropic API key (required)
- \`CLAUDE_MODEL\`: Claude model to use (default: claude-3-5-sonnet-20241022)
- \`NODE_ENV\`: Environment (development, production)
- \`LOG_LEVEL\`: Logging level (info, debug, warn, error)

## Learn More

- [Anthropic TypeScript SDK Documentation](https://docs.anthropic.com/claude/reference/typescript)
- [Claude API Documentation](https://docs.anthropic.com/claude/reference)
- [TypeScript Handbook](https://www.typescriptlang.org/docs/)
- [Node.js Documentation](https://nodejs.org/docs/)
EOF

    success "TypeScript project template created"
}

# Create project creation script
create_typescript_project_script() {
    local project_dir="$1"
    local template_dir="$project_dir/template"
    local creation_script="$project_dir/create-project.sh"

    log "Creating TypeScript project creation script..."

    cat > "$creation_script" << EOF
#!/bin/bash

# Claude TypeScript Project Creation Script
# Creates new TypeScript projects from the Claude template

TEMPLATE_DIR="$template_dir"

# Colors for output
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

show_usage() {
    echo "Usage: create-project.sh <project-name> [directory]"
    echo ""
    echo "Arguments:"
    echo "  project-name    Name of the project to create"
    echo "  directory       Optional directory to create project in (default: current directory)"
    echo ""
    echo "Examples:"
    echo "  create-project.sh my-agent"
    echo "  create-project.sh my-agent ~/projects"
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
    echo -e "\${RED}❌ TypeScript template not found: \$TEMPLATE_DIR\${NC}"
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

echo -e "\${GREEN}🚀 Creating TypeScript project: \$PROJECT_NAME\${NC}"
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

# Update package.json with project name
npm pkg set name="\$PROJECT_NAME"
echo "✓ Package name updated"

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
echo "3. Install dependencies: npm install"
echo "4. Run in development: npm run dev"
echo "5. Build for production: npm run build && npm start"
echo ""
echo "Happy coding with Claude and TypeScript! 🤖"
EOF

    chmod +x "$creation_script"
    success "TypeScript project creation script created"
}

# Create Jest configuration
create_jest_config() {
    local project_dir="$1"

    log "Creating Jest configuration..."

    cd "$project_dir"

    cat > jest.config.js << 'EOF'
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/src', '<rootDir>/tests'],
  testMatch: [
    '**/__tests__/**/*.ts',
    '**/?(*.)+(spec|test).ts'
  ],
  transform: {
    '^.+\\.ts$': 'ts-jest',
  },
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts',
    '!src/**/*.test.ts',
    '!src/**/*.spec.ts',
  ],
  coverageDirectory: 'coverage',
  coverageReporters: [
    'text',
    'lcov',
    'html'
  ],
  setupFilesAfterEnv: ['<rootDir>/tests/setup.ts'],
  testTimeout: 30000,
  verbose: true,
};
EOF

    # Create test setup file
    safe_mkdir "$project_dir/tests"
    cat > "$project_dir/tests/setup.ts" << 'EOF'
/**
 * Jest test setup
 */

// Set test environment variables
process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'error';

// Mock console methods in tests unless needed
global.console = {
  ...console,
  log: jest.fn(),
  debug: jest.fn(),
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
};
EOF

    success "Jest configuration created"
}

# Create ESLint configuration
create_eslint_config() {
    local project_dir="$1"

    log "Creating ESLint configuration..."

    cd "$project_dir"

    cat > .eslintrc.js << 'EOF'
module.exports = {
  parser: '@typescript-eslint/parser',
  parserOptions: {
    project: 'tsconfig.json',
    tsconfigRootDir: __dirname,
    sourceType: 'module',
  },
  plugins: ['@typescript-eslint/eslint-plugin'],
  extends: [
    'eslint:recommended',
    '@typescript-eslint/recommended',
    '@typescript-eslint/recommended-requiring-type-checking',
  ],
  root: true,
  env: {
    node: true,
    jest: true,
  },
  ignorePatterns: ['.eslintrc.js', 'dist/', 'node_modules/'],
  rules: {
    '@typescript-eslint/interface-name-prefix': 'off',
    '@typescript-eslint/explicit-function-return-type': 'off',
    '@typescript-eslint/explicit-module-boundary-types': 'off',
    '@typescript-eslint/no-explicit-any': 'warn',
    '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
    '@typescript-eslint/prefer-const': 'error',
    '@typescript-eslint/no-var-requires': 'error',
  },
};
EOF

    success "ESLint configuration created"
}

# Create Prettier configuration
create_prettier_config() {
    local project_dir="$1"

    log "Creating Prettier configuration..."

    cd "$project_dir"

    cat > .prettierrc << 'EOF'
{
  "semi": true,
  "trailingComma": "es5",
  "singleQuote": true,
  "printWidth": 100,
  "tabWidth": 2,
  "useTabs": false,
  "bracketSpacing": true,
  "arrowParens": "avoid"
}
EOF

    cat > .prettierignore << 'EOF'
node_modules
dist
coverage
*.log
.env
.env.local
.env.development.local
.env.test.local
.env.production.local
EOF

    success "Prettier configuration created"
}

# Main installation function
install_claude_typescript_sdk() {
    header "Installing Claude Agent TypeScript SDK"

    echo "Installing Claude Agent TypeScript SDK with modern tooling..."
    echo ""

    # Check Node.js requirements
    if ! check_node_requirements; then
        return 1
    fi

    # Create project structure
    local project_dir="$CONFIG_DIR/claude-typescript-projects"
    create_typescript_project_structure "$project_dir"

    # Initialize npm project
    initialize_npm_project "$project_dir"

    # Install packages
    if ! install_typescript_packages "$project_dir"; then
        error "Package installation failed"
        return 1
    fi

    # Create configurations
    create_typescript_config "$project_dir"
    create_jest_config "$project_dir"
    create_eslint_config "$project_dir"
    create_prettier_config "$project_dir"

    # Create project template
    create_typescript_project_template "$project_dir"

    # Create project creation script
    create_typescript_project_script "$project_dir"

    # Update unified configuration
    set_config_value "installationType" "claude-typescript-sdk"
    set_config_value "typescript.projectDir" "$project_dir"
    set_config_value "typescript.nodeVersion" "$(node --version 2>/dev/null)"
    set_config_value "typescript.npmVersion" "$(npm --version 2>/dev/null)"
    set_nested_config_value "features.streaming" true
    set_nested_config_value "features.projectTemplates" true
    set_nested_config_value "features.typeScript" true

    echo ""
    success "✅ Claude Agent TypeScript SDK installation completed successfully!"
    echo ""
    echo "Installation Details:"
    echo "  Project Directory: $project_dir"
    echo "  Node.js Version: $(node --version 2>/dev/null)"
    echo "  npm Version: $(npm --version 2>/dev/null)"
    echo "  Template Directory: $project_dir/template"
    echo "  Project Creator: $project_dir/create-project.sh"
    echo ""
    echo "Quick Start:"
    echo "1. Create a new project:"
    echo "   $project_dir/create-project.sh my-agent"
    echo ""
    echo "2. Set up your project:"
    echo "   cd my-agent"
    echo "   # Edit .env file with your Anthropic API key"
    echo ""
    echo "3. Install dependencies:"
    echo "   npm install"
    echo ""
    echo "4. Run in development mode:"
    echo "   npm run dev"
    echo ""
    echo "5. Build for production:"
    echo "   npm run build && npm start"
    echo ""
    echo "Features Included:"
    echo "  • Full TypeScript support with strict type checking"
    echo "  • Modern ES2022+ features and async/await patterns"
    echo "  • Streaming chat responses for real-time interaction"
    echo "  • Comprehensive testing framework (Jest)"
    echo "  • Code quality tools (ESLint, Prettier)"
    echo "  • Hot reloading in development mode"
    echo "  • Production build optimization"
    echo "  • Environment configuration with .env support"
}

# Update existing TypeScript SDK installation
update_typescript_sdk() {
    header "Updating Claude Agent TypeScript SDK"

    local project_dir="$CONFIG_DIR/claude-typescript-projects"

    if [[ ! -d "$project_dir" ]]; then
        error "TypeScript SDK is not installed. Use install function first."
        return 1
    fi

    echo "Updating TypeScript SDK packages..."

    cd "$project_dir"

    # Update npm packages
    if npm update; then
        success "TypeScript SDK packages updated successfully"
    else
        error "Failed to update TypeScript SDK packages"
        return 1
    fi

    # Update core template packages
    if [[ -d "$project_dir/template" ]]; then
        cd "$project_dir/template"
        if npm update; then
            success "Template packages updated successfully"
        else
            warn "Failed to update template packages"
        fi
    fi

    echo "TypeScript SDK update completed"
}

# Verify TypeScript SDK installation
verify_typescript_sdk_installation() {
    header "Verifying Claude Agent TypeScript SDK Installation"

    local project_dir="$CONFIG_DIR/claude-typescript-projects"
    local verification_passed=true

    # Check project directory
    if [[ -d "$project_dir" ]]; then
        success "✓ Project directory exists: $project_dir"

        # Check Node.js and npm
        if command -v node >/dev/null 2>&1; then
            local node_version
            node_version=$(node --version 2>/dev/null)
            success "✓ Node.js available: $node_version"
        else
            error "✗ Node.js not found"
            verification_passed=false
        fi

        if command -v npm >/dev/null 2>&1; then
            local npm_version
            npm_version=$(npm --version 2>/dev/null)
            success "✓ npm available: $npm_version"
        else
            error "✗ npm not found"
            verification_passed=false
        fi

        # Check package.json
        if [[ -f "$project_dir/package.json" ]]; then
            success "✓ package.json exists"

            # Check if TypeScript is installed
            cd "$project_dir"
            if npm list typescript >/dev/null 2>&1; then
                success "✓ TypeScript is installed"
            else
                error "✗ TypeScript is not installed"
                verification_passed=false
            fi

            # Check if Anthropic SDK is installed
            if npm list @anthropic-ai/sdk >/dev/null 2>&1; then
                success "✓ Anthropic TypeScript SDK is installed"
            else
                error "✗ Anthropic TypeScript SDK is not installed"
                verification_passed=false
            fi
        else
            error "✗ package.json not found"
            verification_passed=false
        fi
    else
        error "✗ Project directory not found: $project_dir"
        verification_passed=false
    fi

    # Check project template
    if [[ -d "$project_dir/template" ]]; then
        success "✓ Project template exists"
    else
        error "✗ Project template not found"
        verification_passed=false
    fi

    # Check helper scripts
    local creation_script="$project_dir/create-project.sh"
    if [[ -f "$creation_script" && -x "$creation_script" ]]; then
        success "✓ Project creation script exists"
    else
        error "✗ Project creation script missing or not executable"
        verification_passed=false
    fi

    # Check unified configuration
    local install_type
    install_type=$(get_config_value "installationType")
    if [[ "$install_type" == "claude-typescript-sdk" ]]; then
        success "✓ Unified configuration updated"
    else
        warn "⚠ Unified configuration may not be updated"
    fi

    echo ""
    if [[ "$verification_passed" == true ]]; then
        success "TypeScript SDK installation verification passed"
    else
        error "TypeScript SDK installation verification failed"
        return 1
    fi
}

# Export functions
export -f install_claude_typescript_sdk update_typescript_sdk verify_typescript_sdk_installation
export -f check_node_requirements create_typescript_project_structure initialize_npm_project
export -f install_typescript_packages create_typescript_config create_typescript_project_template
export -f create_typescript_project_script create_jest_config create_eslint_config create_prettier_config

# Export configuration variables
export TYPESCRIPT_SDK_VERSION ANTHROPIC_TYPESCRIPT_PACKAGE TYPESCRIPT_VERSION
export NODE_MIN_VERSION NPM_MIN_VERSION CORE_PACKAGES DEV_PACKAGES