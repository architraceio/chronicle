#!/usr/bin/env bash
set -euo pipefail

# Chronicle installer
# This script is designed to be run with:
# curl -fsSL https://raw.githubusercontent.com/architraceio/chronicle/main/install.sh | bash

# Color support
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
PROJECT_DIR="$(pwd)"
DECISIONS_DIR="docs/decisions"
TEMPLATE="adr-nygard"
STOP_HOOK_ENABLED=true
ADD_DELEGATION_RULE=true
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS=()
DRY_RUN=false
ASSUME_YES=false

# Track which values came from flags so we can skip the corresponding prompts
DECISIONS_DIR_SET=false
TEMPLATE_SET=false
STOP_HOOK_SET=false
DELEGATION_RULE_SET=false

# Delegation rule appended to CLAUDE.md / AGENTS.md (between markers so uninstall can remove it cleanly)
DELEGATION_MARKER_START="<!-- chronicle:delegation:start -->"
DELEGATION_MARKER_END="<!-- chronicle:delegation:end -->"
read -r -d '' DELEGATION_RULE <<'RULE' || true
## Architectural Decisions (Chronicle)

When a meaningful architectural or design decision is made — choosing between
alternatives, adopting or dropping a library, changing data flow, picking a
pattern, or accepting a plan — invoke the `decision-logger` subagent to record
it as an ADR in the configured decisions directory (see `.chronicle.json`).

Trigger phrases include: "let's go with", "we'll use", "decided to",
"instead of", trade-off discussions, and accepting a plan in plan mode.

Use `/log-decision` to capture a decision manually at any time.
RULE

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --agent)
      if [ "$2" = "both" ]; then
        AGENTS+=("claude-code" "opencode")
      else
        AGENTS+=("$2")
      fi
      shift 2
      ;;
    --decisions-dir)
      DECISIONS_DIR="$2"
      DECISIONS_DIR_SET=true
      shift 2
      ;;
    --template)
      TEMPLATE="$2"
      TEMPLATE_SET=true
      shift 2
      ;;
    --no-stop-hook)
      STOP_HOOK_ENABLED=false
      STOP_HOOK_SET=true
      shift
      ;;
    --no-delegation-rule)
      ADD_DELEGATION_RULE=false
      DELEGATION_RULE_SET=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -y|--yes)
      ASSUME_YES=true
      shift
      ;;
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --agent claude-code|opencode|both      Install for specific agent(s)"
      echo "  --decisions-dir DIR                    Set decisions directory (default: docs/decisions)"
      echo "  --template template-name               Set ADR template (default: adr-nygard)"
      echo "  --no-stop-hook                         Disable auto-capture Stop hook (Claude Code only)"
      echo "  --no-delegation-rule                   Don't add delegation rule to CLAUDE.md / AGENTS.md"
      echo "  --dry-run                              Print changes without applying"
      echo "  -y, --yes                              Skip remaining prompts (use defaults / flag values)"
      echo "  --help                                 Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Detect existing setup
if [ -d ".claude" ]; then
  if [[ "${#AGENTS[@]}" -eq 0 ]]; then
    AGENTS+=("claude-code")
  fi
fi

if [ -d ".opencode" ]; then
  if [[ "${#AGENTS[@]}" -eq 0 ]]; then
    AGENTS+=("opencode")
  fi
fi

if [[ "${#AGENTS[@]}" -eq 0 ]]; then
  # Prompt user to select agents
  echo -e "${YELLOW}> Which agent(s) do you use? (detected: .claude/ exists)${NC}"
  echo -e "  ▸ Claude Code"
  echo -e "    OpenCode"
  echo -e "    Both"
  echo -ne "  Select (1-3): "
  read -r agent_choice
  case $agent_choice in
    1|Claude*)
      AGENTS+=("claude-code")
      ;;
    2|OpenCode*)
      AGENTS+=("opencode")
      ;;
    3|Both*)
      AGENTS+=("claude-code" "opencode")
      ;;
    *)
      AGENTS+=("claude-code" "opencode")
      ;;
  esac
fi

# Prompt for decisions directory (skipped if --decisions-dir or --yes was passed)
if [ "$DECISIONS_DIR_SET" != true ] && [ "$ASSUME_YES" != true ]; then
  echo -e "${YELLOW}> Where should ADRs be stored? (relative to project root)${NC}"
  read -p "  [$DECISIONS_DIR] " input_dir
  if [ -n "$input_dir" ]; then
    DECISIONS_DIR="$input_dir"
  fi
fi

# Prompt for template (skipped if --template or --yes was passed)
if [ "$TEMPLATE_SET" != true ] && [ "$ASSUME_YES" != true ]; then
  echo -e "${YELLOW}> Which ADR template?${NC}"
  echo -e "  ▸ Nygard classic (recommended)"
  echo -e "    extended (adds frontmatter + alternatives + rationale)"
  echo -e "    lightweight (4 sections only)"
  echo -ne "  Select (1-3): "
  read -r template_choice
  case $template_choice in
    1|Nygard*)     TEMPLATE="adr-nygard" ;;
    2|extended*)   TEMPLATE="adr-extended" ;;
    3|lightweight*) TEMPLATE="adr-lightweight" ;;
    *)             TEMPLATE="adr-nygard" ;;
  esac
fi

# Prompt for Stop hook (skipped if --no-stop-hook or --yes was passed; only relevant for Claude Code)
if [[ " ${AGENTS[*]} " =~ " claude-code " ]] \
   && [ "$STOP_HOOK_ENABLED" = true ] \
   && [ "$STOP_HOOK_SET" != true ] \
   && [ "$ASSUME_YES" != true ]; then
  echo -e "${YELLOW}> Enable the auto-capture Stop hook (Claude Code)?${NC}"
  echo -e "  This adds an LLM judge that runs at the end of each Claude turn to detect undocumented decisions."
  echo -e "  Cost: ~\$0.001 per turn (Haiku), reduced ~10x by the keyword prefilter."
  echo -e "  ▸ Yes (recommended)"
  echo -e "    No, just the plan-mode hook"
  echo -ne "  Select (1-2): "
  read -r hook_choice
  case $hook_choice in
    2|No*) STOP_HOOK_ENABLED=false ;;
    *)     STOP_HOOK_ENABLED=true ;;
  esac
fi

# Prompt for delegation rule (skipped if --no-delegation-rule or --yes was passed)
if [ "$ADD_DELEGATION_RULE" = true ] \
   && [ "$DELEGATION_RULE_SET" != true ] \
   && [ "$ASSUME_YES" != true ]; then
  echo -e "${YELLOW}> Add the delegation rule to CLAUDE.md / AGENTS.md?${NC}"
  echo -e "  ▸ Yes"
  echo -e "    Show me the rule first"
  echo -e "    No"
  echo -ne "  Select (1-3): "
  read -r rule_choice
  case $rule_choice in
    2|Show*)
      echo
      echo "----- delegation rule (will be appended between markers) -----"
      echo "$DELEGATION_MARKER_START"
      echo "$DELEGATION_RULE"
      echo "$DELEGATION_MARKER_END"
      echo "--------------------------------------------------------------"
      echo -ne "  Append it now? [Y/n]: "
      read -r confirm_rule
      case $confirm_rule in
        n|N|no|No) ADD_DELEGATION_RULE=false ;;
        *)         ADD_DELEGATION_RULE=true  ;;
      esac
      ;;
    3|No*)
      ADD_DELEGATION_RULE=false
      ;;
    *)
      ADD_DELEGATION_RULE=true
      ;;
  esac
fi

# Helper: append the delegation rule to a markdown file (idempotent, marker-wrapped)
append_delegation_rule() {
  local target="$1"
  if grep -q "$DELEGATION_MARKER_START" "$target" 2>/dev/null; then
    echo "  • $target already contains the Chronicle delegation rule, skipping"
    return
  fi
  {
    echo
    echo "$DELEGATION_MARKER_START"
    echo "$DELEGATION_RULE"
    echo "$DELEGATION_MARKER_END"
  } >> "$target"
}

# Resolve adapter source directory.
# When run from a checkout, $INSTALL_DIR contains claude-code/ and opencode/.
# When piped via curl, those files aren't on disk — fetch a tarball.
SOURCE_DIR="$INSTALL_DIR"
if [ ! -d "$SOURCE_DIR/claude-code" ] || [ ! -d "$SOURCE_DIR/opencode" ]; then
  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}> [dry-run] would download adapter source from github.com/architraceio/chronicle${NC}"
  else
    echo -e "${YELLOW}> Downloading adapter source from github.com/architraceio/chronicle${NC}"
    TMP_SOURCE=$(mktemp -d)
    trap 'rm -rf "$TMP_SOURCE"' EXIT
    if ! curl -fsSL "https://github.com/architraceio/chronicle/archive/refs/heads/main.tar.gz" \
         | tar -xz -C "$TMP_SOURCE" --strip-components=1; then
      echo -e "${RED}> Failed to download adapter source from github.com/architraceio/chronicle.${NC}"
      echo -e "${RED}> Check network connectivity and that the repository is public.${NC}"
      exit 1
    fi
    SOURCE_DIR="$TMP_SOURCE"
  fi
fi

# Start installation
echo -e "${GREEN}> Installing Chronicle${NC}"

# Create decisions directory if it doesn't exist
if [ "$DRY_RUN" != true ]; then
  mkdir -p "$DECISIONS_DIR"
fi

# Build the agents JSON array (e.g. ["claude-code","opencode"])
AGENTS_JSON=$(printf '"%s",' "${AGENTS[@]}")
AGENTS_JSON="[${AGENTS_JSON%,}]"

# Create config file
if [ "$DRY_RUN" != true ]; then
  cat > ".chronicle.json" <<EOF
{
  "version": 1,
  "decisionsDir": "$DECISIONS_DIR",
  "template": "$TEMPLATE",
  "archivePlans": true,
  "agents": $AGENTS_JSON,
  "stopHook": {
    "enabled": $STOP_HOOK_ENABLED,
    "prefilterKeywords": [],
    "judgeModel": "claude-haiku-4-5-20251001"
  },
  "installDir": "$INSTALL_DIR"
}
EOF
fi

# Install for each agent
for agent in "${AGENTS[@]}"; do
  echo -e "${GREEN}> Installing for $agent${NC}"
  
  case $agent in
    claude-code)
      if [ "$DRY_RUN" != true ]; then
        mkdir -p ".claude/agents" ".claude/hooks"
        
        # Copy Claude Code adapter files
        mkdir -p ".claude/commands"
        cp -r "$SOURCE_DIR/claude-code/agents/"*   ".claude/agents/"
        cp -r "$SOURCE_DIR/claude-code/hooks/"*    ".claude/hooks/"
        cp -r "$SOURCE_DIR/claude-code/commands/"* ".claude/commands/"
        chmod +x ".claude/hooks/"chronicle-*.sh
        
        # Merge Chronicle hooks into .claude/settings.json
        [ -f ".claude/settings.json" ] || echo '{}' > ".claude/settings.json"

        plan_hook_cmd='$CLAUDE_PROJECT_DIR/.claude/hooks/chronicle-save-plan.sh'
        prefilter_cmd='$CLAUDE_PROJECT_DIR/.claude/hooks/chronicle-prefilter.sh'
        judge_prompt='Transcript: $ARGUMENTS

Did the assistant finalize a non-trivial architectural, design, or trade-off decision in this turn that is not already recorded in the configured decisions directory? If yes, return {"decision":"block","reason":"Invoke the decision-logger subagent for: <one-line summary>"}. Otherwise return {"decision":"approve"}.'

        plan_entry=$(jq -n --arg cmd "$plan_hook_cmd" '{
          matcher: "ExitPlanMode",
          hooks: [{type: "command", command: $cmd}]
        }')

        if [ "$STOP_HOOK_ENABLED" = true ]; then
          stop_entry=$(jq -n --arg pre "$prefilter_cmd" --arg p "$judge_prompt" '{
            hooks: [
              {type: "command", command: $pre},
              {type: "prompt",  prompt:  $p}
            ]
          }')
        else
          stop_entry=null
        fi

        tmp_settings=$(mktemp)
        jq --argjson plan "$plan_entry" --argjson stop "${stop_entry:-null}" '
          .hooks //= {} |
          .hooks.PostToolUse //= [] |
          .hooks.Stop //= [] |
          # Drop any prior Chronicle entries (idempotent re-install)
          .hooks.PostToolUse |= map(select(
            ((.hooks // []) | map(.command // "") | any(test("chronicle-(save-plan|prefilter)\\.sh"))) | not
          )) |
          .hooks.Stop |= map(select(
            ((.hooks // []) | map(.command // "") | any(test("chronicle-(save-plan|prefilter)\\.sh"))) | not
          )) |
          .hooks.PostToolUse += [$plan] |
          (if $stop != null then .hooks.Stop += [$stop] else . end)
        ' ".claude/settings.json" > "$tmp_settings" && mv "$tmp_settings" ".claude/settings.json"
        
        # Append to CLAUDE.md (creating it if needed)
        if [ "$ADD_DELEGATION_RULE" = true ]; then
          [ -f "CLAUDE.md" ] || printf "# CLAUDE.md\n" > "CLAUDE.md"
          append_delegation_rule "CLAUDE.md"
        fi
      fi
      
      echo -e "  ✓ Wrote .chronicle.json"
      echo -e "  ✓ Created $DECISIONS_DIR/"
      echo -e "  ✓ Copied .claude/agents/decision-logger.md"
      echo -e "  ✓ Copied .claude/hooks/chronicle-{save-plan,prefilter}.sh"
      echo -e "  ✓ Merged .claude/settings.json (existing hooks preserved)"
      echo -e "  ✓ Added delegation rule to CLAUDE.md"
      ;;
    
    opencode)
      if [ "$DRY_RUN" != true ]; then
        mkdir -p ".opencode/agent" ".opencode/command"
        
        # Copy OpenCode adapter files
        cp -r "$SOURCE_DIR/opencode/agent/"*   ".opencode/agent/"
        cp -r "$SOURCE_DIR/opencode/command/"* ".opencode/command/"
        
        # Append to AGENTS.md (creating it if needed)
        if [ "$ADD_DELEGATION_RULE" = true ]; then
          [ -f "AGENTS.md" ] || printf "# AGENTS.md\n" > "AGENTS.md"
          append_delegation_rule "AGENTS.md"
        fi
      fi
      
      echo -e "  ✓ Wrote .chronicle.json"
      echo -e "  ✓ Created $DECISIONS_DIR/"
      echo -e "  ✓ Copied .opencode/agent/decision-logger.md"
      echo -e "  ✓ Copied .opencode/command/log-decision.md"
      echo -e "  ✓ Added delegation rule to AGENTS.md"
      ;;
    
    *)
      echo -e "${RED}Unknown agent: $agent${NC}"
      ;;
  esac
done

if [ "$DRY_RUN" != true ]; then
  # Self-check: confirm the install actually placed what it should
  echo -e ""
  echo -e "${GREEN}> Verifying install${NC}"
  verify_ok=true
  if [ -f ".chronicle.json" ]; then
    echo -e "  ✓ .chronicle.json present"
  else
    echo -e "  ${RED}✗ .chronicle.json missing${NC}"; verify_ok=false
  fi
  if [ -d "$DECISIONS_DIR" ]; then
    echo -e "  ✓ $DECISIONS_DIR/ ready"
  else
    echo -e "  ${RED}✗ $DECISIONS_DIR/ missing${NC}"; verify_ok=false
  fi
  for agent in "${AGENTS[@]}"; do
    case $agent in
      claude-code)
        if [ -f ".claude/agents/decision-logger.md" ]; then
          echo -e "  ✓ .claude/agents/decision-logger.md installed"
        else
          echo -e "  ${RED}✗ .claude/agents/decision-logger.md missing${NC}"; verify_ok=false
        fi
        ;;
      opencode)
        if [ -f ".opencode/agent/decision-logger.md" ]; then
          echo -e "  ✓ .opencode/agent/decision-logger.md installed"
        else
          echo -e "  ${RED}✗ .opencode/agent/decision-logger.md missing${NC}"; verify_ok=false
        fi
        ;;
    esac
  done

  if [ "$verify_ok" = true ]; then
    echo -e "${GREEN}> Done. Try it:${NC}"
  else
    echo -e "${RED}> Install completed with warnings — see above${NC}"
  fi
  echo -e "  1. Run \`claude\` and use plan mode (Shift+Tab Shift+Tab)"
  echo -e "  2. Accept a plan — your first ADR will appear in $DECISIONS_DIR/"
  echo -e "  3. Or run /log-decision to capture a decision manually"
  echo -e ""
  echo -e "Docs: https://github.com/architraceio/chronicle/tree/main/docs"
fi