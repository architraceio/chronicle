#!/usr/bin/env bash
set -euo pipefail

INPUT="$(cat)"
TOOL=$(echo "$INPUT" | jq -r '.tool_name')
[ "$TOOL" = "ExitPlanMode" ] || exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
CONFIG="$PROJECT_DIR/.chronicle.json"
[ -f "$CONFIG" ] || { echo "{}"; exit 0; }

DECISIONS_DIR=$(jq -r '.decisionsDir // "docs/decisions"' "$CONFIG")
ARCHIVE_PLANS=$(jq -r '.archivePlans // true' "$CONFIG")

PLAN=$(echo "$INPUT" | jq -r '.tool_response.plan // empty')
[ -z "$PLAN" ] && exit 0

if [ "$ARCHIVE_PLANS" = "true" ]; then
  PLAN_DIR="$PROJECT_DIR/$DECISIONS_DIR/_plans"
  mkdir -p "$PLAN_DIR"
  TS=$(date -u +"%Y%m%dT%H%M%SZ")
  SLUG=$(echo "$PLAN" | head -1 | sed 's/[^a-zA-Z0-9]/-/g' | tr -s '-' | cut -c1-50 | tr A-Z a-z)
  echo "$PLAN" > "$PLAN_DIR/${TS}-${SLUG:-plan}.md"
fi

jq -n --arg plan "$PLAN" '{
  "decision": "block",
  "reason": "A plan was accepted. Invoke the decision-logger subagent with the following plan content to produce a structured ADR before continuing:\n\n\($plan)"
}'