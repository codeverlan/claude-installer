#!/bin/bash

# Anthropic Documentation Retrieval using Jina
# Uses Jina AI to fetch comprehensive documentation for Claude Code and SDKs

set -eo pipefail

# Configuration
JINA_API_KEY="${JINA_API_KEY:-jina_7b6f57d091044d6b97842ce4b2255f97AhbRBm7_D6wha51sJxHM4LrCamG6)"
OUTPUT_DIR="$(pwd)/anthropic-docs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Colors for output
RED=''
GREEN=''
YELLOW=''
BLUE=''
NC=''

# Logging function
log() {
    echo "[INFO] $1"
}

warn() {
    echo "[WARN] $1"
}

error() {
    echo "[ERROR] $1"
}

header() {
    echo "=== $1 ==="
}

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Documentation URLs to retrieve
declare -A DOC_URLS=(
    ["claude-code-overview"]="https://docs.anthropic.com/en/docs/claude-code"
    ["claude-code-getting-started"]="https://docs.anthropic.com/en/docs/claude-code/getting-started"
    ["claude-code-cli-reference"]="https://docs.anthropic.com/en/docs/claude-code/cli-reference"
    ["claude-code-configuration"]="https://docs.anthropic.com/en/docs/claude-code/configuration"
    ["claude-code-slash-commands"]="https://docs.anthropic.com/en/docs/claude-code/slash-commands"
    ["claude-sdk-overview"]="https://docs.anthropic.com/en/docs/claude-sdk"
    ["claude-sdk-python"]="https://docs.anthropic.com/en/docs/claude-sdk/python"
    ["claude-sdk-typescript"]="https://docs.anthropic.com/en/docs/claude-sdk/typescript"
    ["claude-sdk-async"]="https://docs.anthropic.com/en/docs/claude-sdk/async-usage"
    ["claude-api-reference"]="https://docs.anthropic.com/en/api-reference"
    ["claude-messages"]="https://docs.anthropic.com/en/api/messages"
    ["claude-streaming"]="https://docs.anthropic.com/en/api/messages-streaming"
    ["system-prompts"]="https://docs.anthropic.com/en/docs/system-prompts"
    ["prompt-engineering"]="https://docs.anthropic.com/en/docs/prompt-engineering"
    ["mcp-protocol"]="https://modelcontextprotocol.io/docs"
    ["mcp-claude-integration"]="https://modelcontextprotocol.io/docs/concepts/architecture#claude-integration"
)

# Function to fetch documentation using Jina
fetch_doc() {
    local name="$1"
    local url="$2"
    local output_file="$OUTPUT_DIR/${name}_${TIMESTAMP}.md"

    header "Fetching: $name"
    log "URL: $url"

    # Use Jina AI reader to fetch and extract content
    local curl_data="{\"url\": \"$url\", \"options\": {\"includeMetadata\": true}}"
    if curl -s -X POST \
        -H "Authorization: Bearer $JINA_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$curl_data" \
        "https://api.jina.ai/v1/reader" \
        > /tmp/jina_response.json; then

        # Extract and format the content
        if command -v jq >/dev/null 2>&1; then
            local title=$(jq -r '.data.title // "Unknown Title"' /tmp/jina_response.json)
            local content=$(jq -r '.data.content // "No content available"' /tmp/jina_response.json)

            cat > "$output_file" << EOF
# $title

**Source:** $url
**Retrieved:** $(date)
**Type:** Anthropic Documentation

---

$content

---

## Metadata

\`\`\`json
$(jq '.data.metadata // {}' /tmp/jina_response.json)
\`\`\`
EOF

            log "✅ Saved to: $output_file"
            log "📄 Title: $title"
        else
            # Fallback without jq
            warn "⚠️  jq not available, saving raw response"
            cp /tmp/jina_response.json "$output_file.json"
            log "📄 Saved raw JSON to: $output_file.json"
        fi

        # Cleanup
        rm -f /tmp/jina_response.json

    else
        error "❌ Failed to fetch: $url"
        return 1
    fi

    echo ""
}

# Function to create comprehensive documentation index
create_index() {
    local index_file="$OUTPUT_DIR/documentation_index_$TIMESTAMP.md"

    cat > "$index_file" << 'EOF'
# Anthropic Documentation Collection

**Generated:** TIMESTAMP_PLACEHOLDER
**Purpose:** Comprehensive reference for Claude Code Universal Installer

## Quick Reference

### Claude Code CLI
- **Overview:** [claude-code-overview_TIMESTAMP.md](claude-code-overview_TIMESTAMP.md)
- **Getting Started:** [claude-code-getting-started_TIMESTAMP.md](claude-code-getting-started_TIMESTAMP.md)
- **CLI Reference:** [claude-code-cli-reference_TIMESTAMP.md](claude-code-cli-reference_TIMESTAMP.md)
- **Configuration:** [claude-code-configuration_TIMESTAMP.md](claude-code-configuration_TIMESTAMP.md)
- **Slash Commands:** [claude-code-slash-commands_TIMESTAMP.md](claude-code-slash-commands_TIMESTAMP.md)

### Claude Agent SDKs
- **SDK Overview:** [claude-sdk-overview_TIMESTAMP.md](claude-sdk-overview_TIMESTAMP.md)
- **Python SDK:** [claude-sdk-python_TIMESTAMP.md](claude-sdk-python_TIMESTAMP.md)
- **TypeScript SDK:** [claude-sdk-typescript_TIMESTAMP.md](claude-sdk-typescript_TIMESTAMP.md)
- **Async Usage:** [claude-sdk-async_TIMESTAMP.md](claude-sdk-async_TIMESTAMP.md)

### API Reference
- **API Reference:** [claude-api-reference_TIMESTAMP.md](claude-api-reference_TIMESTAMP.md)
- **Messages API:** [claude-messages_TIMESTAMP.md](claude-messages_TIMESTAMP.md)
- **Streaming API:** [claude-streaming_TIMESTAMP.md](claude-streaming_TIMESTAMP.md)

### Development Guides
- **System Prompts:** [system-prompts_TIMESTAMP.md](system-prompts_TIMESTAMP.md)
- **Prompt Engineering:** [prompt-engineering_TIMESTAMP.md](prompt-engineering_TIMESTAMP.md)

### Model Context Protocol (MCP)
- **MCP Protocol:** [mcp-protocol_TIMESTAMP.md](mcp-protocol_TIMESTAMP.md)
- **Claude Integration:** [mcp-claude-integration_TIMESTAMP.md](mcp-claude-integration_TIMESTAMP.md)

## Installation Integration Matrix

| Feature | Claude Code CLI | Python SDK | TypeScript SDK |
|---------|-----------------|------------|----------------|
| System Prompts | ✅ Built-in | ⚠️ Manual | ⚠️ Manual |
| Slash Commands | ✅ Built-in | ❌ N/A | ❌ N/A |
| Permission Escalation | ⚠️ OS-level | ⚠️ Process-level | ⚠️ Process-level |
| Docker Integration | ✅ Native | ⚠️ Custom | ⚠️ Custom |
| MCP Integration | ✅ Built-in | ✅ Available | ✅ Available |
| Configuration Files | ✅ .claude/ | ⚠️ Custom | ⚠️ Custom |
| Interactive Mode | ✅ Native | ⚠️ Custom | ⚠️ Custom |

## Key Implementation Considerations

### Claude Code CLI
1. **Binary Management:** Download and mount Linux binary
2. **Configuration:** Environment variables + .claude/ directory
3. **Customization:** System prompts, slash commands, hooks
4. **Integration:** Native MCP, Docker, Git

### Python SDK
1. **Installation:** pip install anthropic
2. **Environment:** Python virtual environment
3. **Configuration:** Custom config management
4. **Integration:** Async support, context management

### TypeScript SDK
1. **Installation:** npm install @anthropic-ai/sdk
2. **Environment:** Node.js project setup
3. **Configuration:** TypeScript/JavaScript config
4. **Integration:** Promise-based, streaming support

## Development Priority

1. **Phase 1:** Documentation collection and analysis
2. **Phase 2:** Installation script architecture
3. **Phase 3:** SDK-specific implementations
4. **Phase 4:** Unified interface development
5. **Phase 5:** Testing and optimization

---

*This documentation collection serves as the foundation for the Claude Code Universal Installer project.*
EOF

    # Replace timestamp placeholder
    sed -i.bak "s/TIMESTAMP_PLACEHOLDER/$(date)/g" "$index_file"
    rm -f "$index_file.bak"

    # Replace all TIMESTAMP placeholders with actual timestamp
    sed -i.bak "s/TIMESTAMP/$TIMESTAMP/g" "$index_file"
    rm -f "$index_file.bak"

    log "📚 Documentation index created: $index_file"
}

# Main execution
main() {
    header "Anthropic Documentation Retrieval"
    log "Output directory: $OUTPUT_DIR"
    log "Timestamp: $TIMESTAMP"
    echo ""

    # Check if Jina API key is available
    if [[ -z "$JINA_API_KEY" ]]; then
        error "JINA_API_KEY environment variable is not set"
        exit 1
    fi

    # Check dependencies
    if ! command -v curl >/dev/null 2>&1; then
        error "curl is required but not installed"
        exit 1
    fi

    local success_count=0
    local total_count=${#DOC_URLS[@]}

    # Fetch all documentation
    for name in "${!DOC_URLS[@]}"; do
        if fetch_doc "$name" "${DOC_URLS[$name]}"; then
            ((success_count++))
        fi
    done

    # Create index
    create_index

    # Summary
    header "Retrieval Summary"
    log "Successfully retrieved: $success_count/$total_count documents"
    log "Output directory: $OUTPUT_DIR"
    log "Index file: $OUTPUT_DIR/documentation_index_$TIMESTAMP.md"

    if [[ $success_count -eq $total_count ]]; then
        log "🎉 All documentation retrieved successfully!"
        exit 0
    else
        warn "⚠️  Some documents failed to retrieve. Check the logs above."
        exit 1
    fi
}

# Run main function
main "$@"