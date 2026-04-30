#!/usr/bin/env bash
set -euo pipefail

# Chronicle uninstaller
# Removes all Chronicle files and settings from the project

# Color support
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

DELEGATION_MARKER_START="<!-- chronicle:delegation:start -->"
DELEGATION_MARKER_END="<!-- chronicle:delegation:end -->"

# Remove the delegation block (and its preceding blank line) from a markdown file
strip_delegation_rule() {
  local target="$1"
  if [ ! -f "$target" ] || ! grep -qF "$DELEGATION_MARKER_START" "$target"; then
    return
  fi
  awk -v s="$DELEGATION_MARKER_START" -v e="$DELEGATION_MARKER_END" '
    BEGIN { skip = 0; buf = "" }
    {
      if (skip) { if ($0 == e) skip = 0; next }
      if ($0 == s) { skip = 1; buf = ""; next }
      if ($0 == "") { buf = buf $0 "\n"; next }
      printf "%s", buf; buf = ""
      print
    }
    END { printf "%s", buf }
  ' "$target" > "$target.chronicle.tmp" && mv "$target.chronicle.tmp" "$target"
  echo -e "  ✓ Removed Chronicle delegation rule from $target"
}

echo -e "${GREEN}> Uninstalling Chronicle${NC}"

# Check if config exists
if [ ! -f ".chronicle.json" ]; then
  echo -e "${RED}No .chronicle.json found - Chronicle may not be installed in this project${NC}"
  exit 1
fi

# Read configuration
CONFIG=$(cat .chronicle.json)
AGENTS=$(echo "$CONFIG" | jq -r '.agents[]')
DECISIONS_DIR=$(echo "$CONFIG" | jq -r '.decisionsDir')

# Remove files for each agent
for agent in $AGENTS; do
  echo -e "${GREEN}> Uninstalling for $agent${NC}"
  
  case $agent in
    claude-code)
      # Remove Claude Code specific files
      if [ -d ".claude/agents" ]; then
        rm -rf ".claude/agents/decision-logger.md"
      fi
      
      if [ -d ".claude/hooks" ]; then
        rm -f ".claude/hooks/chronicle-save-plan.sh"
        rm -f ".claude/hooks/chronicle-prefilter.sh"
      fi
      
      if [ -d ".claude/commands" ]; then
        rm -f ".claude/commands/log-decision.md"
      fi
      
      # Strip Chronicle hook entries from .claude/settings.json
      if [ -f ".claude/settings.json" ]; then
        tmp_settings=$(mktemp)
        if jq '
          if .hooks.PostToolUse then
            .hooks.PostToolUse |= map(select(
              ((.hooks // []) | map(.command // "") | any(test("chronicle-(save-plan|prefilter)\\.sh"))) | not
            ))
          else . end |
          if .hooks.Stop then
            .hooks.Stop |= map(select(
              ((.hooks // []) | map(.command // "") | any(test("chronicle-(save-plan|prefilter)\\.sh"))) | not
            ))
          else . end
        ' ".claude/settings.json" > "$tmp_settings"; then
          mv "$tmp_settings" ".claude/settings.json"
          echo -e "  ✓ Removed Chronicle hooks from .claude/settings.json"
        else
          rm -f "$tmp_settings"
          echo -e "  ${RED}! Could not parse .claude/settings.json — leaving it unchanged${NC}"
        fi
      fi
      
      strip_delegation_rule "CLAUDE.md"

      echo -e "  ✓ Removed Claude Code files"
      ;;
    
    opencode)
      # Remove OpenCode specific files
      if [ -d ".opencode/agent" ]; then
        rm -rf ".opencode/agent/decision-logger.md"
      fi
      
      if [ -d ".opencode/command" ]; then
        rm -f ".opencode/command/log-decision.md"
      fi
      
      strip_delegation_rule "AGENTS.md"

      echo -e "  ✓ Removed OpenCode files"
      ;;
  esac
done

# Remove config file
rm -f ".chronicle.json"
echo -e "  ✓ Removed .chronicle.json"

# Remove decisions directory if it's empty
if [ -d "$DECISIONS_DIR" ]; then
  if [ -z "$(ls -A "$DECISIONS_DIR")" ]; then
    rmdir "$DECISIONS_DIR"
    echo -e "  ✓ Removed empty decisions directory"
  else
    echo -e "  ✓ Left non-empty decisions directory: $DECISIONS_DIR"
  fi
fi

echo -e "${GREEN}> Uninstall complete${NC}"