#!/bin/bash

# Simple Anthropic Documentation Retrieval using Jina

JINA_API_KEY="jina_7b6f57d091044d6b97842ce4b2255f97AhbRBm7_D6wha51sJxHM4LrCamG6"
OUTPUT_DIR="$(pwd)/anthropic-docs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

mkdir -p "$OUTPUT_DIR"

echo "=== Anthropic Documentation Retrieval ==="
echo "Output directory: $OUTPUT_DIR"
echo "Timestamp: $TIMESTAMP"

# Test with a single URL first
test_url="https://docs.anthropic.com/en/docs/claude-code"
echo "Testing fetch from: $test_url"

if curl -s \
    -H "Authorization: Bearer $JINA_API_KEY" \
    "https://r.jina.ai/$test_url" \
    > "$OUTPUT_DIR/test_response.json"; then

    echo "✅ Successfully fetched documentation"
    echo "📄 Saved to: $OUTPUT_DIR/test_response.json"

    # Show a preview
    if command -v jq >/dev/null 2>&1; then
        echo "📋 Title: $(jq -r '.data.title // "Unknown"' "$OUTPUT_DIR/test_response.json")"
        echo "📝 Content length: $(jq -r '.data.content | length' "$OUTPUT_DIR/test_response.json") characters"
    else
        echo "📋 Raw response saved (install jq for better formatting)"
    fi
else
    echo "❌ Failed to fetch documentation"
    exit 1
fi

echo ""
echo "✅ Test completed successfully!"