#!/bin/bash
#
# Prompt Log Validation Script
#
# Checks if today's prompt log exists and has been recently updated.
#

PROMPTS_DIR="$(dirname "$0")/sessions"
TODAY=$(date +%Y-%m-%d)
TODAY_LOG=$(ls "$PROMPTS_DIR"/${TODAY}_*.md 2>/dev/null | head -1)

echo "=== Prompt Log Status ==="
echo ""

if [ -z "$TODAY_LOG" ]; then
    echo "❌ No prompt log found for today ($TODAY)"
    echo ""
    echo "Create one with:"
    echo "  cp .prompts/templates/session_template.md .prompts/sessions/${TODAY}_description.md"
    exit 1
fi

echo "✅ Today's log: $(basename "$TODAY_LOG")"
echo ""

# Count prompts in log
PROMPT_COUNT=$(grep -c "^## Prompt [0-9]" "$TODAY_LOG" 2>/dev/null || echo "0")
echo "📝 Prompts logged: $PROMPT_COUNT"

# Get last modification time
LAST_MOD=$(stat -c %Y "$TODAY_LOG" 2>/dev/null || stat -f %m "$TODAY_LOG" 2>/dev/null)
NOW=$(date +%s)
AGE_MINS=$(( (NOW - LAST_MOD) / 60 ))

echo "⏱️  Last updated: $AGE_MINS minutes ago"
echo ""

if [ $AGE_MINS -gt 30 ]; then
    echo "⚠️  WARNING: Log hasn't been updated in over 30 minutes"
    echo "   If you've had AI interactions, the log may be stale."
fi

# Show last prompt summary
echo ""
echo "=== Last Logged Prompt ==="
grep -A 20 "^## Prompt $PROMPT_COUNT$" "$TODAY_LOG" | head -15

exit 0
