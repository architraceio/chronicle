#!/usr/bin/env bash
# Installs Chronicle with APM into a fixture project for every target and checks
# the deployed files against the support matrix, then uninstalls and checks cleanup.
# shellcheck disable=SC2015  # "cond && ok || fail" is intended
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APM="${APM:-apm}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
ok()   { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }
has()  { [ -e "$P/$2" ] && ok "$1" || fail "$1 ($2 missing)"; }
hasnt(){ [ ! -e "$P/$2" ] && ok "$1" || fail "$1 ($2 still there)"; }
jqok() { jq -e "$3" "$P/$2" >/dev/null 2>&1 && ok "$1" || fail "$1 ($2: $3)"; }

P="$TMP/project"
mkdir -p "$P"/{.claude,.codex,.gemini,.cursor,.github,.opencode}
git -C "$P" init -q
echo '{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"echo user-hook"}]}]}}' > "$P/.claude/settings.json"

echo "== apm install"
# shellcheck disable=SC2086  # APM may be a multi-word command
(cd "$P" && $APM install "$ROOT" --target claude,codex,gemini,cursor,copilot,opencode >"$TMP/install.log" 2>&1) \
  && ok "apm install succeeded" || { fail "apm install succeeded"; cat "$TMP/install.log"; }

echo "== Claude Code"
has  "skill + script"            .claude/skills/chronicle-adr/scripts/chronicle-adr
has  "templates bundled"         .claude/skills/chronicle-adr/templates/adr-nygard.md
has  "decision-logger agent"     .claude/agents/decision-logger.md
has  "hook engine"               .claude/hooks/hooks-claude/scripts/chronicle-hook
has  "judge prompt"              .claude/hooks/hooks-claude/scripts/judge-prompt.md
jqok "user hook preserved"       .claude/settings.json '[.hooks.Stop[].hooks[].command] | index("echo user-hook") != null'
for e in SessionStart UserPromptSubmit PreToolUse PostToolUse Stop; do
  jqok "hook $e"                 .claude/settings.json ".hooks.$e | map(.hooks[].command) | any(test(\"chronicle-hook\"))"
done
[ -x "$P/.claude/hooks/hooks-claude/scripts/chronicle-hook" ] && ok "engine executable" || fail "engine executable"

echo "== Codex"
has  "agent (toml)"              .codex/agents/decision-logger.toml
has  "skill via .agents"         .agents/skills/chronicle-adr/SKILL.md
for e in SessionStart UserPromptSubmit PostToolUse Stop; do jqok "hook $e" .codex/hooks.json ".hooks.$e != null"; done

echo "== Gemini CLI"
for e in SessionStart BeforeAgent BeforeTool AfterTool AfterAgent; do jqok "hook $e" .gemini/settings.json ".hooks.$e != null"; done
jqok "Stop not mapped to SessionEnd" .gemini/settings.json '.hooks.SessionEnd == null'
has  "/log-decision command"     .gemini/commands/log-decision.toml
has  "/chronicle-review command" .gemini/commands/chronicle-review.toml

echo "== Cursor"
for e in sessionStart beforeSubmitPrompt postToolUse afterAgentResponse stop; do jqok "hook $e" .cursor/hooks.json ".hooks.$e != null"; done
jqok "stop loop_limit = 1"       .cursor/hooks.json '.hooks.stop[0].loop_limit == 1'
jqok "postToolUse on every tool (deferred delivery)" .cursor/hooks.json '[.hooks.postToolUse[] | select(any(.hooks[]?; .command | test("chronicle-hook")))] | all(has("matcher") | not)'
has  "rule"                      .cursor/rules/chronicle.mdc
has  "agent"                     .cursor/agents/decision-logger.md

echo "== Copilot"
f="$(find "$P/.github/hooks" -maxdepth 1 -name "*chronicle*.json" 2>/dev/null | head -1)"; f="${f#"$P"/}"
[ -n "$f" ] && ok "hook file" || fail "hook file"
for e in sessionStart userPromptSubmitted preToolUse postToolUse agentStop; do jqok "hook $e (native format)" "$f" ".hooks.${e}[0].bash | test(\"chronicle-hook\")"; done
has  "agent"                     .github/agents/decision-logger.agent.md
has  "rule"                      .github/instructions/chronicle.instructions.md
has  "/log-decision prompt"      .github/prompts/log-decision.prompt.md

echo "== OpenCode"
has  "agent"                     .opencode/agents/decision-logger.md
has  "skills via .agents"        .agents/skills/log-decision/SKILL.md

echo "== AGENTS.md rule (documented in docs/getting-started.md)"
printf '# Team notes\n\nKeep me.\n' > "$P/AGENTS.md"
# shellcheck disable=SC2086
(cd "$P" && $APM compile >"$TMP/compile1.log" 2>&1)
grep -q 'Keep me.' "$P/AGENTS.md" && ! grep -q 'Chronicle' "$P/AGENTS.md" \
  && ok "hand-written AGENTS.md left alone by default" || fail "hand-written AGENTS.md left alone by default"
printf '\ncompilation:\n  agents_md:\n    mode: managed_section\n' >> "$P/apm.yml"
printf '\n<!-- apm:start -->\n<!-- apm:end -->\n\nFooter.\n' >> "$P/AGENTS.md"
# shellcheck disable=SC2086
(cd "$P" && $APM compile >"$TMP/compile2.log" 2>&1) && ok "apm compile (managed section)" || { fail "apm compile (managed section)"; cat "$TMP/compile2.log"; }
grep -q 'Keep me.' "$P/AGENTS.md" && grep -q 'Footer.' "$P/AGENTS.md" && ok "own text kept" || fail "own text kept"
sed -n '/apm:start/,/apm:end/p' "$P/AGENTS.md" | grep -q 'Architectural decisions (Chronicle)' \
  && ok "rule written between markers" || fail "rule written between markers"

echo "== apm uninstall"
# shellcheck disable=SC2086
(cd "$P" && $APM uninstall "$ROOT" >"$TMP/uninstall.log" 2>&1) && ok "apm uninstall succeeded" || { fail "apm uninstall succeeded"; tail -20 "$TMP/uninstall.log"; }
jqok  "user hook still there"    .claude/settings.json '[.hooks.Stop[].hooks[].command] | index("echo user-hook") != null'
jqok  "chronicle hooks removed"  .claude/settings.json '[.. | .command? // empty | strings] | any(test("chronicle-hook")) | not'
hasnt "claude skill removed"     .claude/skills/chronicle-adr
hasnt "engine removed"           .claude/hooks/hooks-claude/scripts/chronicle-hook

echo
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]
