#!/usr/bin/env bash
# shellcheck disable=SC2015  # "cond && ok || fail" is intended: ok/fail never fail
# Chronicle unit tests: hook engine (all harnesses) and chronicle-adr.
# No network, no real agent CLIs: the judge is replaced via CHRONICLE_JUDGE_CMD.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE="$ROOT/packages/engine/chronicle-hook"
ADR_SRC="$ROOT/packages/core/.apm/skills/chronicle-adr"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0; FAIL=0
ok()   { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n       %s\n' "$1" "$2"; }

# expect <name> <jq-filter-that-must-be-true> <json>
expect() {
  if jq -e "$2" >/dev/null 2>&1 <<< "$3"; then ok "$1"; else fail "$1" "got: $3"; fi
}

# new_project -> sets P; installs the skill where the engine looks for it
new_project() {
  P="$TMP/p$RANDOM$RANDOM"
  mkdir -p "$P/.claude/skills"
  cp -r "$ADR_SRC" "$P/.claude/skills/chronicle-adr"
  git -C "$P" init -q
}

JUDGE_IN="$TMP/judge-in"
JUDGE_YES="cat > $JUDGE_IN; echo '{\"decisions\":[{\"title\":\"SQLite for local cache\",\"final\":true}]}'"
JUDGE_NO="cat > $JUDGE_IN; echo '{\"decisions\":[]}'"
JUDGE_FAIL='exit 1'
JUDGE_NEVER="echo called > $TMP/judge-called; exit 1"

# hook <harness> <event> <json> [judge-cmd]
hook() {
  CHRONICLE_PROJECT_DIR="$P" CHRONICLE_JUDGE_CMD="${4:-$JUDGE_YES}" \
    bash "$ENGINE" --harness "$1" "$2" <<< "$3"
}
audit_on() { printf '{"judge":{"mode":"audit"}}' > "$P/.chronicle.json"; }
last_log() { tail -n1 "$P/.chronicle/log.jsonl" 2>/dev/null || echo '{}'; }
judge_not_called() { # judge_not_called <name>
  if [ -f "$TMP/judge-called" ]; then fail "$1" "judge was called"; rm -f "$TMP/judge-called"; else ok "$1"; fi
}

DECISION_MSG="We'll use SQLite instead of Redis for the local cache."

echo "== engine: stop with audit off (default)"
new_project
hook claude prompt '{"session_id":"s1","prompt":"Pick a cache."}' >/dev/null
out="$(hook claude stop "{\"session_id\":\"s1\",\"last_assistant_message\":\"$DECISION_MSG\"}" "$JUDGE_NEVER")"
expect "audit off -> allow" '. == {}' "$out"
judge_not_called "audit off -> no judge call"
[ ! -s "$P/.chronicle/log.jsonl" ] && ok "audit off -> nothing logged" || fail "audit off -> nothing logged" "$(cat "$P/.chronicle/log.jsonl")"

echo "== engine: audit mode"
new_project; audit_on
hook claude prompt '{"session_id":"a1","prompt":"Redis or SQLite? ok, do that."}' >/dev/null
out="$(hook claude stop "{\"session_id\":\"a1\",\"last_assistant_message\":\"$DECISION_MSG\"}")"
expect "audit: never blocks or messages" '. == {}' "$out"
expect "audit: verdict logged" '.action == "audit" and .decisions[0].title == "SQLite for local cache" and .adr_this_turn == false' "$(last_log)"
grep -q 'USER: Redis or SQLite? ok, do that.' "$JUDGE_IN" && grep -q "ASSISTANT: $DECISION_MSG" "$JUDGE_IN" \
  && ok "audit: judge sees the recorded prompt and the reply" || fail "audit: judge sees the recorded prompt and the reply" "$(cat "$JUDGE_IN")"

new_project; audit_on
hook claude prompt '{"session_id":"a2","prompt":"Pick a cache."}' >/dev/null
CHRONICLE_PROJECT_DIR="$P" bash "$P/.claude/skills/chronicle-adr/scripts/chronicle-adr" new --title "SQLite for local cache" >/dev/null
hook claude stop "{\"session_id\":\"a2\",\"last_assistant_message\":\"$DECISION_MSG\"}" >/dev/null
expect "audit: ADR written this turn is recorded" '.action == "audit" and .adr_this_turn == true' "$(last_log)"

new_project; audit_on
hook claude prompt '{"session_id":"a3","prompt":"x"}' >/dev/null
hook claude post-tool "{\"session_id\":\"a3\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$P/docs/decisions/0001-x.md\"}}" >/dev/null
hook claude stop "{\"session_id\":\"a3\",\"last_assistant_message\":\"$DECISION_MSG\"}" >/dev/null
expect "audit: ADR file written by the agent counts" '.adr_this_turn == true' "$(last_log)"

new_project; audit_on
out="$(hook claude stop "{\"session_id\":\"a4\",\"last_assistant_message\":\"$DECISION_MSG\"}" "$JUDGE_FAIL")"
expect "audit: judge fails -> allow" '. == {}' "$out"
expect "audit: judge failure logged" '.action == "audit-unavailable"' "$(last_log)"

new_project; audit_on
out="$(hook claude stop "{\"session_id\":\"a5\",\"stop_hook_active\":true,\"last_assistant_message\":\"$DECISION_MSG\"}" "$JUDGE_NEVER")"
expect "audit: stop_hook_active -> allow" '. == {}' "$out"
judge_not_called "audit: stop_hook_active -> no judge call"
out="$(hook claude stop '{"session_id":"a5","last_assistant_message":""}' "$JUDGE_NEVER")"
judge_not_called "audit: empty reply -> no judge call"
out="$(CHRONICLE_JUDGE=1 hook claude stop "{\"session_id\":\"a6\",\"last_assistant_message\":\"$DECISION_MSG\"}" "$JUDGE_NEVER")"
expect "fork guard: CHRONICLE_JUDGE=1 -> allow" '. == {}' "$out"
judge_not_called "fork guard: CHRONICLE_JUDGE=1 -> no judge call"

new_project; audit_on
mkdir -p "$P/.chronicle/state"; mkdir "$P/.chronicle/state/judge.lock"
out="$(hook claude stop "{\"session_id\":\"a7\",\"last_assistant_message\":\"$DECISION_MSG\"}" "$JUDGE_NEVER")"
judge_not_called "judge lock held -> no second judge"
expect "judge lock held -> logged as unavailable" '.action == "audit-unavailable"' "$(last_log)"

new_project; audit_on
cat > "$TMP/recurse.sh" <<EOF
CHRONICLE_PROJECT_DIR="$P" bash "$ENGINE" --harness claude stop <<< '{"session_id":"inner","last_assistant_message":"We decided to use NATS instead of Kafka."}' > "$TMP/inner.out"
echo '{"decisions":[]}'
EOF
hook claude stop "{\"session_id\":\"s6\",\"last_assistant_message\":\"$DECISION_MSG\"}" "bash $TMP/recurse.sh" >/dev/null
expect "fork guard: hook inside the judge's session -> allow" '. == {}' "$(cat "$TMP/inner.out")"
[ ! -d "$P/.chronicle/state/inner" ] && ok "fork guard: inner run touched no state" || fail "fork guard: inner run touched no state" "state dir created"

out="$(printf 'not json' | CHRONICLE_PROJECT_DIR="$P" bash "$ENGINE" --harness claude stop)"
expect "garbage stdin -> allow" '. == {}' "$out"

echo "== engine: reply from the transcript only from real assistant entries"
new_project; audit_on
printf '%s\n' \
  '{"type":"api-request-blob","message":{"role":"assistant","content":[{"type":"text","text":"INJECTED architectural ADR text"}]}}' \
  '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Real reply."}]}}' \
  '{"type":"api-request-blob","message":{"role":"assistant","content":[{"type":"text","text":"INJECTED again"}]}}' > "$TMP/t1.jsonl"
hook claude stop "{\"session_id\":\"t1\",\"transcript_path\":\"$TMP/t1.jsonl\"}" "$JUDGE_NO" >/dev/null
grep -q 'ASSISTANT: Real reply.' "$JUDGE_IN" && ! grep -q INJECTED "$JUDGE_IN" \
  && ok "claude: transcript fallback ignores request blobs" || fail "claude: transcript fallback ignores request blobs" "$(cat "$JUDGE_IN")"

echo "== engine: plans (Claude Code)"
new_project
PLAN='# Cache layer\n\nUse SQLite instead of Redis.'
hook claude pre-tool "{\"session_id\":\"pl\",\"tool_name\":\"ExitPlanMode\",\"tool_input\":{\"plan\":\"$PLAN\"}}" >/dev/null
[ -f "$P/.chronicle/state/pl/pending-plan.json" ] && ok "PreToolUse(ExitPlanMode) -> pending plan" || fail "PreToolUse(ExitPlanMode) -> pending plan" "no pending file"
out="$(hook claude post-tool "{\"session_id\":\"pl\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$HOME/.claude/plans/x.md\"}}")"
expect "edit outside project (plan file) does not promote" '. == {}' "$out"
out="$(hook claude post-tool "{\"session_id\":\"pl\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$P/src/app.ts\"}}")"
expect "rejected plan + first project edit -> promote" '.hookSpecificOutput.hookEventName == "PostToolUse" and (.hookSpecificOutput.additionalContext | test("ONE ADR PER DISTINCT"))' "$out"
ls "$P"/docs/decisions/_plans/*-cache-layer.md >/dev/null 2>&1 && ok "plan archived to _plans/" || fail "plan archived to _plans/" "$(ls -R "$P/docs" 2>&1)"
out="$(hook claude post-tool "{\"session_id\":\"pl\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$P/src/b.ts\"}}")"
expect "second edit -> no second promotion" '. == {}' "$out"

new_project
hook claude pre-tool "{\"session_id\":\"pa\",\"tool_name\":\"ExitPlanMode\",\"tool_input\":{\"plan\":\"$PLAN\"}}" >/dev/null
out="$(hook claude post-tool "{\"session_id\":\"pa\",\"tool_name\":\"ExitPlanMode\",\"tool_response\":{\"plan\":\"$PLAN\"}}")"
expect "approved plan -> promote immediately" '.hookSpecificOutput.additionalContext | test("approved plan")' "$out"

new_project
printf '# Revised plan\n\nUse NATS.\n' > "$TMP/plan-file.md"
hook claude pre-tool "{\"session_id\":\"pr\",\"tool_name\":\"ExitPlanMode\",\"tool_input\":{\"plan\":\"# Old plan\",\"planFilePath\":\"$TMP/plan-file.md\"}}" >/dev/null
hook claude post-tool "{\"session_id\":\"pr\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$P/a.go\"}}" >/dev/null
grep -q "Use NATS" "$P"/docs/decisions/_plans/*.md 2>/dev/null && ok "promotion re-reads the latest plan revision" || fail "promotion re-reads the latest plan revision" "archive has old text"

new_project
hook claude pre-tool "{\"session_id\":\"old\",\"tool_name\":\"ExitPlanMode\",\"tool_input\":{\"plan\":\"$PLAN\"}}" >/dev/null
out="$(hook claude session-start '{"session_id":"new"}')"
expect "unimplemented plan -> SessionStart reminder" '.hookSpecificOutput.hookEventName == "SessionStart" and (.hookSpecificOutput.additionalContext | test("unimplemented plan"))' "$out"


echo "== engine: Codex"
new_project; audit_on
hook codex prompt '{"session_id":"c1","turn_id":"t1","prompt":"Use SQLite?"}' >/dev/null
out="$(hook codex stop "{\"session_id\":\"c1\",\"turn_id\":\"t1\",\"last_assistant_message\":\"$DECISION_MSG\"}")"
expect "codex: audit -> allow" '. == {}' "$out"
grep -q 'USER: Use SQLite?' "$JUDGE_IN" && ok "codex: prompt recorded" || fail "codex: prompt recorded" "$(cat "$JUDGE_IN")"
out="$(hook codex post-tool "{\"session_id\":\"c1\",\"tool_name\":\"apply_patch\",\"tool_input\":{\"input\":\"*** Begin Patch\\n*** Add File: docs/decisions/0002-y.md\\n+x\\n*** End Patch\"}}")"
expect "codex: apply_patch ADR path detected" '. == {}' "$out"
[ -f "$P/.chronicle/state/last-adr" ] && ok "codex: ADR write marks last-adr" || fail "codex: ADR write marks last-adr" "missing"
printf '%s\n' \
  '{"type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"INJECTED"}]}}' \
  '{"type":"event_msg","payload":{"type":"agent_message","message":"Codex reply."}}' > "$TMP/cx.jsonl"
hook codex stop "{\"session_id\":\"c2\",\"transcript_path\":\"$TMP/cx.jsonl\",\"last_assistant_message\":null}" "$JUDGE_NO" >/dev/null
grep -q 'ASSISTANT: Codex reply.' "$JUDGE_IN" && ! grep -q INJECTED "$JUDGE_IN" \
  && ok "codex: transcript fallback reads agent_message only" || fail "codex: transcript fallback reads agent_message only" "$(cat "$JUDGE_IN")"

echo "== engine: Gemini CLI"
new_project; audit_on
hook gemini prompt '{"session_id":"g1","prompt":"Which DB?"}' >/dev/null
out="$(hook gemini stop "{\"session_id\":\"g1\",\"prompt\":\"Which DB?\",\"prompt_response\":\"$DECISION_MSG\"}")"
expect "gemini: audit -> allow (never deny)" '. == {}' "$out"
grep -q "ASSISTANT: $DECISION_MSG" "$JUDGE_IN" && ok "gemini: reply from prompt_response" || fail "gemini: reply from prompt_response" "$(cat "$JUDGE_IN")"
new_project
mkdir -p "$P/plans"; printf '# Gemini plan\n\nUse Postgres.\n' > "$P/plans/p.md"
hook gemini pre-tool '{"session_id":"g2","tool_name":"exit_plan_mode","tool_input":{"plan_path":"plans/p.md"}}' >/dev/null
out="$(hook gemini post-tool "{\"session_id\":\"g2\",\"tool_name\":\"write_file\",\"tool_input\":{\"file_path\":\"$P/db.py\"}}")"
expect "gemini: plan_path read + promoted on first write" '.hookSpecificOutput.hookEventName == "AfterTool" and (.hookSpecificOutput.additionalContext | test("approved plan"))' "$out"

echo "== engine: Cursor"
new_project; audit_on
hook cursor prompt '{"conversation_id":"k1","prompt":"Pick one."}' >/dev/null
hook cursor reply "{\"conversation_id\":\"k1\",\"text\":\"$DECISION_MSG\"}" >/dev/null
out="$(hook cursor stop '{"conversation_id":"k1","status":"completed","loop_count":0}')"
expect "cursor: audit -> allow (no followup_message)" '. == {}' "$out"
grep -q "ASSISTANT: $DECISION_MSG" "$JUDGE_IN" && ok "cursor: reply from afterAgentResponse" || fail "cursor: reply from afterAgentResponse" "$(cat "$JUDGE_IN")"
out="$(hook cursor stop '{"conversation_id":"k3","status":"aborted","loop_count":0}' "$JUDGE_NEVER")"
judge_not_called "cursor: aborted -> no judge call"

echo "== engine: Copilot"
new_project; audit_on
printf '%s\n' \
  "{\"type\":\"user.message\",\"data\":{\"content\":\"pick one\"}}" \
  "{\"type\":\"assistant.message\",\"data\":{\"content\":\"$DECISION_MSG\"}}" \
  "{\"type\":\"tool.result\",\"data\":{\"content\":\"INJECTED\"}}" > "$TMP/cp.jsonl"
hook copilot prompt '{"sessionId":"cp1","prompt":"pick one"}' >/dev/null
out="$(hook copilot stop "{\"sessionId\":\"cp1\",\"transcriptPath\":\"$TMP/cp.jsonl\",\"stopReason\":\"end_turn\"}")"
expect "copilot: audit -> allow" '. == {}' "$out"
grep -q "ASSISTANT: $DECISION_MSG" "$JUDGE_IN" && ! grep -q INJECTED "$JUDGE_IN" \
  && ok "copilot: reply from the last assistant.message" || fail "copilot: reply from the last assistant.message" "$(cat "$JUDGE_IN")"
out="$(hook copilot stop "{\"sessionId\":\"cp2\",\"stopHookActive\":true,\"transcriptPath\":\"$TMP/cp.jsonl\"}" "$JUDGE_NEVER")"
judge_not_called "copilot: camelCase stopHookActive -> no judge call"

echo "== engine: judge timeout"
for mode in timeout watchdog; do
  new_project
  printf '{"judge":{"mode":"audit","timeoutSec":1}}' > "$P/.chronicle.json"
  start=$(date +%s)
  if [ "$mode" = watchdog ]; then export CHRONICLE_FORCE_WATCHDOG=1; fi
  out="$(hook claude stop "{\"session_id\":\"to$mode\",\"last_assistant_message\":\"$DECISION_MSG\"}" 'sleep 8; echo "{\"decisions\":[]}"')"
  unset CHRONICLE_FORCE_WATCHDOG
  took=$(( $(date +%s) - start ))
  [ "$took" -le 5 ] && ok "judge killed after timeoutSec ($mode, ${took}s)" || fail "judge killed after timeoutSec ($mode)" "took ${took}s"
  expect "judge timeout ($mode) -> unavailable, allow" '.action == "audit-unavailable"' "$(last_log)"
done

echo "== chronicle-adr"
new_project
A="$P/.claude/skills/chronicle-adr/scripts/chronicle-adr"
export CHRONICLE_PROJECT_DIR="$P"
f1="$(bash "$A" new --title "Postgres for primary store" --status Accepted)"
[ "$(basename "$f1")" = "0001-postgres-for-primary-store.md" ] && ok "adr: first number + slug" || fail "adr: first number + slug" "$f1"
grep -q '^Accepted$' "$f1" && ok "adr: status filled" || fail "adr: status filled" "$(cat "$f1")"
bash "$A" new --title "Postgres for primary store" >/dev/null 2>&1 && fail "adr: duplicate slug refused" "created" || ok "adr: duplicate slug refused"
touch "$P/docs/decisions/0007-legacy.md"
f2="$(bash "$A" new --title "Redis for cache" --supersedes 1)"
[ "$(basename "$f2")" = "0008-redis-for-cache.md" ] && ok "adr: numbering continues after gaps" || fail "adr: numbering continues after gaps" "$f2"
bash "$A" supersede 1 --by 8 >/dev/null
grep -q '^Superseded by ADR-0008$' "$f1" && ok "adr: supersede rewrites only the status" || fail "adr: supersede rewrites only the status" "$(cat "$f1")"
bash "$A" index >/dev/null && grep -q 'Redis for cache' "$P/docs/decisions/README.md" && ok "adr: index" || fail "adr: index" "missing"
printf '{"stopHook":{"enabled":false,"judgeModel":"haiku"}}' > "$P/.chronicle.json"
expect "adr: v1 config migrated" '.judge.model == "haiku" and .judge.mode == "off" and .version == 2 and (.stopHook | not)' "$(bash "$A" config)"
printf '{}' > "$P/package.json"; git -C "$P" add package.json
bash "$A" guard --staged 2>/dev/null && ok "guard: warn mode exits 0" || fail "guard: warn mode exits 0" "non-zero"
printf '{"guard":{"mode":"block"}}' > "$P/.chronicle.json"
bash "$A" guard --staged 2>/dev/null && fail "guard: block mode exits non-zero" "zero" || ok "guard: block mode exits non-zero"
git -C "$P" add docs/decisions/0008-redis-for-cache.md
bash "$A" guard --staged 2>/dev/null && ok "guard: passes when an ADR is added" || fail "guard: passes when an ADR is added" "non-zero"
unset CHRONICLE_PROJECT_DIR

echo
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]
