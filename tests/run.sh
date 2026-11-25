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

JUDGE_YES='echo "{\"decisions\":[{\"title\":\"SQLite for local cache\",\"final\":true}]}"'
JUDGE_NO='echo "{\"decisions\":[]}"'
JUDGE_FAIL='exit 1'

# hook <harness> <event> <json> [judge-cmd]
hook() {
  CHRONICLE_PROJECT_DIR="$P" CHRONICLE_JUDGE_CMD="${4:-$JUDGE_YES}" \
    bash "$ENGINE" --harness "$1" "$2" <<< "$3"
}

DECISION_MSG="We'll use SQLite instead of Redis for the local cache."

echo "== engine: Claude Code stop"
new_project
out="$(hook claude stop '{"session_id":"s1","last_assistant_message":"Fixed the typo in README."}')"
expect "no keyword -> allow" '. == {}' "$out"
expect "prefilter miss is logged" '.action == "prefilter-miss"' "$(tail -n1 "$P/.chronicle/log.jsonl")"

hook claude prompt '{"session_id":"s1"}' >/dev/null
out="$(hook claude stop "{\"session_id\":\"s1\",\"last_assistant_message\":\"$DECISION_MSG\"}")"
expect "keyword + judge yes -> block" '.decision == "block" and (.reason | test("SQLite for local cache"))' "$out"
expect "final decision -> Accepted" '.reason | test("Status: Accepted")' "$out"

out="$(hook claude stop '{"session_id":"s1","last_assistant_message":"Recorded ADR 0001. We decided to use SQLite."}')"
expect "loop guard: second stop in same turn -> allow" '. == {}' "$out"

out="$(hook claude stop "{\"session_id\":\"s1\",\"stop_hook_active\":true,\"last_assistant_message\":\"$DECISION_MSG\"}")"
expect "loop guard: stop_hook_active -> allow" '. == {}' "$out"

out="$(CHRONICLE_JUDGE=1 hook claude stop "{\"session_id\":\"s9\",\"last_assistant_message\":\"$DECISION_MSG\"}")"
expect "loop guard: CHRONICLE_JUDGE=1 -> allow" '. == {}' "$out"

hook claude prompt '{"session_id":"s1"}' >/dev/null
out="$(hook claude stop "{\"session_id\":\"s1\",\"last_assistant_message\":\"$DECISION_MSG\"}")"
expect "dedupe: same reply next turn -> allow" '. == {}' "$out"

new_project
hook claude prompt '{"session_id":"s2"}' >/dev/null
out="$(hook claude stop "{\"session_id\":\"s2\",\"last_assistant_message\":\"$DECISION_MSG\"}" "$JUDGE_NO")"
expect "judge no -> allow" '. == {}' "$out"

new_project
hook claude prompt '{"session_id":"s3"}' >/dev/null
out="$(hook claude stop "{\"session_id\":\"s3\",\"last_assistant_message\":\"$DECISION_MSG\"}" "$JUDGE_FAIL")"
expect "judge unavailable -> self-check fallback block" '.decision == "block" and (.reason | test("stop without any further comment"))' "$out"
expect "judge-unavailable is logged" '.action == "judge-unavailable"' "$(tail -n1 "$P/.chronicle/log.jsonl")"

new_project
mkdir -p "$P/.chronicle/state"; mkdir "$P/.chronicle/state/judge.lock"
hook claude prompt '{"session_id":"s4"}' >/dev/null
out="$(hook claude stop "{\"session_id\":\"s4\",\"last_assistant_message\":\"$DECISION_MSG\"}")"
expect "judge lock held -> no judge, fallback" '.decision == "block" and (.reason | test("Chronicle check"))' "$out"

new_project
hook claude prompt '{"session_id":"s5"}' >/dev/null
CHRONICLE_PROJECT_DIR="$P" bash "$P/.claude/skills/chronicle-adr/scripts/chronicle-adr" new --title "SQLite for local cache" >/dev/null
out="$(hook claude stop "{\"session_id\":\"s5\",\"last_assistant_message\":\"$DECISION_MSG\"}")"
expect "ADR already written this turn -> allow" '. == {}' "$out"

new_project
cat > "$TMP/recurse.sh" <<EOF
CHRONICLE_PROJECT_DIR="$P" bash "$ENGINE" --harness claude stop <<< '{"session_id":"inner","last_assistant_message":"We decided to use NATS instead of Kafka."}' > "$TMP/inner.out"
echo '{"decisions":[]}'
EOF
hook claude prompt '{"session_id":"s6"}' >/dev/null
hook claude stop "{\"session_id\":\"s6\",\"last_assistant_message\":\"$DECISION_MSG\"}" "bash $TMP/recurse.sh" >/dev/null
expect "fork guard: hook inside the judge's session -> allow" '. == {}' "$(cat "$TMP/inner.out")"
[ ! -d "$P/.chronicle/state/inner" ] && ok "fork guard: inner run touched no state" || fail "fork guard: inner run touched no state" "state dir created"

new_project
printf '%s\n' \
  '{"type":"user","message":{"role":"user","content":"Should we go with Kafka or NATS? Lets go with NATS, it is simpler to run."}}' \
  '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Agreed."}]}}' > "$TMP/t1.jsonl"
hook claude prompt '{"session_id":"s7"}' >/dev/null
out="$(hook claude stop "{\"session_id\":\"s7\",\"transcript_path\":\"$TMP/t1.jsonl\",\"last_assistant_message\":\"Agreed.\"}")"
expect "window: keyword only in user turn -> judged" '.decision == "block"' "$out"

out="$(printf 'not json' | CHRONICLE_PROJECT_DIR="$P" bash "$ENGINE" --harness claude stop)"
expect "garbage stdin -> allow" '. == {}' "$out"

new_project
printf '{"capture":{"midSession":false}}' > "$P/.chronicle.json"
out="$(hook claude stop "{\"session_id\":\"s8\",\"last_assistant_message\":\"$DECISION_MSG\"}")"
expect "midSession disabled -> allow" '. == {}' "$out"

new_project
printf '{"capture":{"mode":"nudge"}}' > "$P/.chronicle.json"
hook claude prompt '{"session_id":"n1"}' >/dev/null
out="$(hook claude stop "{\"session_id\":\"n1\",\"last_assistant_message\":\"$DECISION_MSG\"}")"
expect "nudge mode -> systemMessage, no block" 'has("systemMessage") and (has("decision") | not)' "$out"
out="$(hook claude prompt '{"session_id":"n1"}')"
expect "nudge mode: deferred delivery on next prompt" '.hookSpecificOutput.hookEventName == "UserPromptSubmit" and (.hookSpecificOutput.additionalContext | test("SQLite"))' "$out"
out="$(hook claude prompt '{"session_id":"n1"}')"
expect "deferred delivery happens once" '. == {}' "$out"

echo "== engine: async continuation (regression from live run)"
# block -> agent starts a background decision-logger, turn ends (stop_hook_active)
# -> logger writes ADR -> its completion arrives as a NEW turn -> stop must not judge again
new_project
hook claude prompt '{"session_id":"as"}' >/dev/null
hook claude stop "{\"session_id\":\"as\",\"last_assistant_message\":\"$DECISION_MSG\"}" >/dev/null
hook claude stop "{\"session_id\":\"as\",\"stop_hook_active\":true,\"last_assistant_message\":\"Started decision-logger.\"}" >/dev/null
sleep 1
CHRONICLE_PROJECT_DIR="$P" bash "$P/.claude/skills/chronicle-adr/scripts/chronicle-adr" new --title "SQLite for local cache" --status Accepted >/dev/null
sleep 1
hook claude prompt '{"session_id":"as"}' >/dev/null
out="$(hook claude stop '{"session_id":"as","last_assistant_message":"decision-logger recorded the ADR; we decided on SQLite instead of Redis."}' 'echo SHOULD-NOT-RUN; exit 1')"
expect "notification turn after ADR -> allow without judging" '. == {}' "$out"
expect "skip is logged" '.action == "skip-adr-written"' "$(tail -n1 "$P/.chronicle/log.jsonl")"

new_project
hook claude prompt '{"session_id":"dt"}' >/dev/null
hook claude stop "{\"session_id\":\"dt\",\"last_assistant_message\":\"$DECISION_MSG\"}" >/dev/null
hook claude prompt '{"session_id":"dt"}' >/dev/null
out="$(hook claude stop '{"session_id":"dt","last_assistant_message":"Again: we will use SQLite rather than Redis, as decided."}')"
expect "same decision title twice in a session -> allow" '. == {}' "$out"

new_project
printf '{"capture":{"maxBlocksPerSession":1}}' > "$P/.chronicle.json"
hook claude prompt '{"session_id":"cap"}' >/dev/null
hook claude stop "{\"session_id\":\"cap\",\"last_assistant_message\":\"$DECISION_MSG\"}" >/dev/null
hook claude prompt '{"session_id":"cap"}' >/dev/null
out="$(hook claude stop '{"session_id":"cap","last_assistant_message":"We decided to use NATS instead of Kafka."}' 'echo "{\"decisions\":[{\"title\":\"NATS for messaging\",\"final\":true}]}"')"
expect "block cap reached -> nudge instead of block" 'has("systemMessage") and (has("decision") | not)' "$out"

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

new_project
hook claude prompt '{"session_id":"aw"}' >/dev/null
hook claude post-tool "{\"session_id\":\"aw\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$P/docs/decisions/0001-x.md\"}}" >/dev/null
out="$(hook claude stop "{\"session_id\":\"aw\",\"last_assistant_message\":\"$DECISION_MSG\"}")"
expect "agent wrote an ADR file itself -> stop skips" '. == {}' "$out"

echo "== engine: Codex"
new_project
hook codex prompt '{"session_id":"c1","turn_id":"t1"}' >/dev/null
out="$(hook codex stop "{\"session_id\":\"c1\",\"turn_id\":\"t1\",\"last_assistant_message\":\"$DECISION_MSG\"}")"
expect "codex: judge yes -> block" '.decision == "block"' "$out"
out="$(hook codex post-tool "{\"session_id\":\"c1\",\"tool_name\":\"apply_patch\",\"tool_input\":{\"input\":\"*** Begin Patch\\n*** Add File: docs/decisions/0002-y.md\\n+x\\n*** End Patch\"}}")"
expect "codex: apply_patch ADR path detected" '. == {}' "$out"
[ -f "$P/.chronicle/state/last-adr" ] && ok "codex: ADR write marks last-adr" || fail "codex: ADR write marks last-adr" "missing"

echo "== engine: Gemini CLI"
new_project
hook gemini prompt '{"session_id":"g1"}' >/dev/null
out="$(hook gemini stop "{\"session_id\":\"g1\",\"prompt\":\"x\",\"prompt_response\":\"$DECISION_MSG\"}")"
expect "gemini: never deny (would discard reply) -> systemMessage" 'has("systemMessage") and (has("decision") | not)' "$out"
out="$(hook gemini post-tool "{\"session_id\":\"g1\",\"tool_name\":\"write_file\",\"tool_input\":{\"file_path\":\"$P/x.py\"}}")"
expect "gemini: deferred delivery via AfterTool" '.hookSpecificOutput.hookEventName == "AfterTool" and (.hookSpecificOutput.additionalContext | test("SQLite"))' "$out"
out="$(hook gemini prompt '{"session_id":"g1"}')"
expect "gemini: delivered only once" '. == {}' "$out"
new_project
mkdir -p "$P/plans"; printf '# Gemini plan\n\nUse Postgres.\n' > "$P/plans/p.md"
hook gemini pre-tool '{"session_id":"g2","tool_name":"exit_plan_mode","tool_input":{"plan_path":"plans/p.md"}}' >/dev/null
out="$(hook gemini post-tool "{\"session_id\":\"g2\",\"tool_name\":\"write_file\",\"tool_input\":{\"file_path\":\"$P/db.py\"}}")"
expect "gemini: plan_path read + promoted on first write" '.hookSpecificOutput.additionalContext | test("approved plan")' "$out"

echo "== engine: Cursor"
new_project
hook cursor prompt '{"conversation_id":"k1"}' >/dev/null
hook cursor reply "{\"conversation_id\":\"k1\",\"text\":\"$DECISION_MSG\"}" >/dev/null
out="$(hook cursor stop '{"conversation_id":"k1","status":"completed","loop_count":0}')"
expect "cursor: afterAgentResponse text + stop -> followup_message" '.followup_message | test("SQLite")' "$out"
out="$(hook cursor stop '{"conversation_id":"k2","status":"completed","loop_count":1}')"
expect "cursor: loop_count > 0 -> allow" '. == {}' "$out"
out="$(hook cursor stop '{"conversation_id":"k3","status":"aborted","loop_count":0}')"
expect "cursor: aborted -> allow" '. == {}' "$out"
new_project
printf '{"capture":{"mode":"nudge"}}' > "$P/.chronicle.json"
hook cursor prompt '{"conversation_id":"kn"}' >/dev/null
hook cursor reply "{\"conversation_id\":\"kn\",\"text\":\"$DECISION_MSG\"}" >/dev/null
out="$(hook cursor stop '{"conversation_id":"kn","status":"completed","loop_count":0}')"
expect "cursor nudge: no follow-up" '(has("followup_message") | not)' "$out"
out="$(hook cursor prompt '{"conversation_id":"kn"}')"
expect "cursor nudge: beforeSubmitPrompt can't add context -> allow" '. == {}' "$out"
out="$(hook cursor post-tool '{"conversation_id":"kn","tool_name":"Read","tool_input":{"path":"x"}}')"
expect "cursor nudge: deferred delivery via postToolUse" '.additional_context | test("SQLite")' "$out"

echo "== engine: Copilot"
new_project
printf '%s\n' "{\"type\":\"user.message\",\"data\":{\"content\":\"pick one\"}}" "{\"type\":\"assistant.message\",\"data\":{\"content\":\"$DECISION_MSG\"}}" > "$TMP/cp.jsonl"
hook copilot prompt '{"sessionId":"cp1"}' >/dev/null
out="$(hook copilot stop "{\"sessionId\":\"cp1\",\"transcriptPath\":\"$TMP/cp.jsonl\",\"stopReason\":\"end_turn\"}")"
expect "copilot: transcript parsed -> block" '.decision == "block" and (.reason | test("SQLite"))' "$out"
out="$(hook copilot pre-tool '{"sessionId":"cp1","toolName":"bash","toolArgs":"{\"command\":\"ls\"}"}')"
expect "copilot: unrelated preToolUse -> allow" '. == {}' "$out"
new_project
printf '{"capture":{"mode":"nudge"}}' > "$P/.chronicle.json"
hook copilot prompt '{"sessionId":"cpn"}' >/dev/null
out="$(hook copilot stop "{\"sessionId\":\"cpn\",\"transcriptPath\":\"$TMP/cp.jsonl\",\"stopReason\":\"end_turn\"}")"
expect "copilot nudge: no block" '(has("decision") | not)' "$out"
out="$(hook copilot prompt '{"sessionId":"cpn"}')"
expect "copilot nudge: prompt hook can't add context -> allow" '. == {}' "$out"
out="$(hook copilot post-tool '{"sessionId":"cpn","toolName":"bash","toolArgs":"{\"command\":\"ls\"}"}')"
expect "copilot nudge: deferred delivery via postToolUse" '.additionalContext | test("SQLite")' "$out"
out="$(hook copilot post-tool '{"sessionId":"cpn","toolName":"bash","toolArgs":"{\"command\":\"ls\"}"}')"
expect "copilot nudge: delivered only once" '. == {}' "$out"
new_project
hook copilot prompt '{"sessionId":"cpl"}' >/dev/null
out="$(hook copilot stop "{\"sessionId\":\"cpl\",\"stopHookActive\":true,\"transcriptPath\":\"$TMP/cp.jsonl\"}")"
expect "copilot: camelCase stopHookActive -> allow" '. == {}' "$out"

echo "== engine: judge timeout and keyword portability"
for mode in timeout watchdog; do
  new_project
  printf '{"judge":{"timeoutSec":1}}' > "$P/.chronicle.json"
  hook claude prompt "{\"session_id\":\"to$mode\"}" >/dev/null
  start=$(date +%s)
  if [ "$mode" = watchdog ]; then export CHRONICLE_FORCE_WATCHDOG=1; fi
  out="$(hook claude stop "{\"session_id\":\"to$mode\",\"last_assistant_message\":\"$DECISION_MSG\"}" 'sleep 8; echo "{\"decisions\":[]}"')"
  unset CHRONICLE_FORCE_WATCHDOG
  took=$(( $(date +%s) - start ))
  [ "$took" -le 5 ] && ok "judge killed after timeoutSec ($mode, ${took}s)" || fail "judge killed after timeoutSec ($mode)" "took ${took}s"
  expect "judge timeout ($mode) -> self fallback" '.decision == "block" and (.reason | test("Chronicle check"))' "$out"
done
new_project
out="$(hook claude stop '{"session_id":"kw1","last_assistant_message":"Updated the address field."}' "$JUDGE_FAIL")"
expect "keyword: 'address' does not match ADR" '. == {}' "$out"
hook claude prompt '{"session_id":"kw2"}' >/dev/null
out="$(hook claude stop '{"session_id":"kw2","last_assistant_message":"This needs an ADR."}')"
expect "keyword: standalone ADR matches" '.decision == "block"' "$out"

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
expect "adr: v1 config migrated" '.capture.midSession == false and .judge.model == "haiku" and .version == 2' "$(bash "$A" config)"
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
