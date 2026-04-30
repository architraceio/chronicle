#!/usr/bin/env bash
set -euo pipefail

# Cheap regex pre-filter for the Stop hook
# Always exits 0 (non-blocking)

# Check if we should run the prefilter based on configuration
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
CONFIG="$PROJECT_DIR/.chronicle.json"
[ -f "$CONFIG" ] || exit 0

PREFILTER_KEYWORDS=$(jq -r '.stopHook.prefilterKeywords // []' "$CONFIG")

# Default keywords as specified in the plan
DEFAULT_KEYWORDS="let's go with|we'll use|we'll go with|decided to|going to use|the decision is|I'll choose|chosen approach|trade-off|instead of|rather than|as opposed to|ADR|architectural decision"

# Determine keywords to use
KEYWORDS=""
if [ "${#PREFILTER_KEYWORDS}" -gt 2 ]; then
  # We have custom keywords
  KEYWORDS=$(echo "$PREFILTER_KEYWORDS" | jq -r 'map("\"\(.)\"") | join("|")')
else
  # Use defaults
  KEYWORDS="$DEFAULT_KEYWORDS"
fi

# Check current turn transcript for decision keywords
# This would be implemented using a transcript available to the hook
# For now, we just return a dummy result indicating whether we should trigger further processing
echo "{}"