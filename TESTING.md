# Testing Chronicle

Three layers. Layers 1 and 2 run in CI; layer 3 is done by hand before a release.

## 1. Unit tests: `make test`

`tests/run.sh` feeds hook payloads for each harness into `packages/engine/chronicle-hook` and checks the JSON it returns. The judge is replaced via `CHRONICLE_JUDGE_CMD`, so no network and no agent CLI is needed. Covered:

- Stop: prefilter miss, judge yes / no / unavailable (self fallback), nudge mode, deferred delivery (exactly once; via the next tool result for Cursor and Copilot, whose prompt hooks can't add context), window from transcript (keyword only in a user message), garbage input → allow, judge timeout with `timeout` and with the shell watchdog used on macOS, keyword matching (`ADR` doesn't match `address`).
- Loop guards, each on its own: `CHRONICLE_JUDGE=1`, `stop_hook_active`, one block per turn, ADR written since the previous stop (including the async `decision-logger` continuation seen in a live run), same title never flagged twice, block cap, judge lock, the judge's own session re-entering the hook.
- Plans: pending on `PreToolUse(ExitPlanMode)`, promotion on approval and on the first project edit after a rejected dialog, edits outside the project don't promote, the latest plan revision is archived, no double promotion, `SessionStart` reminder for an unimplemented plan.
- Per harness: Codex (`apply_patch` ADR detection), Gemini (never `deny`, `plan_path`, `AfterTool` delivery), Cursor (`afterAgentResponse` → `stop` → `followup_message`, `loop_count`, aborted), Copilot (camelCase payloads, transcript parsing).
- `chronicle-adr`: numbering with gaps, duplicate refusal, supersede, index, v1 config migration, guard in warn and block mode.

`make lint` runs shellcheck over all scripts. `make check-sync` fails if a hook package's bundled engine drifted from `packages/engine/`. Run `make sync` after editing the engine.

## 2. APM install test: `make test-apm`

`tests/apm-install.sh` installs the repository with APM 0.38.1 into a fixture project with `.claude`, `.codex`, `.gemini`, `.cursor`, `.github` and `.opencode`. It checks every deployed file and hook entry against the support matrix, including that a pre-existing user hook survives, that Gemini doesn't get a `SessionEnd` mapping, and that Cursor gets `loop_limit: 1` and Copilot the native hook format. It also runs the documented `AGENTS.md` setup: a hand-written `AGENTS.md` is left alone by default, and with `compilation.agents_md.mode: managed_section` the rule lands between the markers while your own text stays. It then runs `apm uninstall` and checks that only Chronicle's entries are gone.

## 3. Live smoke tests (manual, per harness)

Install into a scratch repository (`apm install /path/to/chronicle --target <harness>`), then:

| # | Do | Expect (`.chronicle/log.jsonl`, `docs/decisions/`) |
|---|---|---|
| L1 | Ask: *"Compare Redis vs SQLite for this CLI's cache, then decide: we'll go with SQLite instead of Redis. No code."* | one `judged` with 1 decision, one ADR, then `skip-adr-written`; no second judge call, no stray judge processes (`pgrep -fa "claude -p"`) |
| L2 | Ask a question without a decision | `prefilter-miss`, no judge call |
| L3 | Plan mode: propose a plan, press Esc, ask a question, leave plan mode, say "go ahead" | `plan-pending`, then `plan-promoted` at the first edit; one ADR per decision in the plan plus one `_plans/` file |
| L4 | Plan mode: propose a plan, reject it, end the session, start a new one | no ADR; the new session mentions the unimplemented plan |
| L5 | Approve a plan whose final reply is full of decision words | ADRs from the plan only, no extra mid-session ADR |
| L6 | Log out of the judge CLI (or remove it from `PATH`), repeat L1 | `judge-unavailable`, self-check fallback, still at most one extra turn |

Status (0.2.0):

| Harness | L1 | L2 | L3 | L4 | L5 | L6 |
|---|---|---|---|---|---|---|
| Claude Code | ✅ | ✅ | unit-tested only | unit-tested only | unit-tested only | unit-tested only |
| Codex, Gemini, Cursor, Copilot | not yet run | | | | | |
| OpenCode | manual capture only: check that `/log-decision` and `/chronicle-review` work | | | | | |

Verified: a GitHub install (`apm install "architraceio/chronicle#apm-package"`) resolves all sub-packages and deploys the same paths as a local install.

Checked against official docs, not yet in a live run: Codex hooks are on by default; trust is given in `/hooks`, tied to a hash, and asked again after a change; Stop has `last_assistant_message`, `stop_hook_active`, `transcript_path` and `turn_id`, and `decision: block` continues. Gemini's `AfterAgent` has `prompt_response`; `deny` discards the reply; `AfterTool` and `BeforeAgent` accept `additionalContext`; the plan field is `plan_path`; project hooks are fingerprinted. Cursor runs project hooks from the project root; `agent -p` supports `--mode ask` and `--output-format json`. Copilot: `postToolUse` and `sessionStart` accept `additionalContext`; prompt-hook output is dropped; `agentStop` honors `decision: block`. VS Code reads `.github/hooks/*.json`.

Live-test checklist: each item is an assumption the code relies on that only a real session can confirm.

| Agent | Check |
|---|---|
| Claude Code | `PreToolUse(ExitPlanMode)` fires when the plan dialog is rejected (L3, L4). The plan text is in `tool_response.plan` and the path in `planFilePath` (L5). |
| Codex | `codex exec` accepts `-s read-only` and `-c features.hooks=false` (watch `judge-unavailable` in L1). The rollout transcript is parsed into the window. The hook timeout is in seconds. Hooks find the engine when Codex is started from a subdirectory. |
| Gemini CLI | `systemMessage` is shown; reminders arrive via `AfterTool`/`BeforeAgent`. `exit_plan_mode` sends `plan_path` and the plan file is found (`GEMINI_PLANS_DIR`). The judge's `--output-format json` envelope has `.response`. |
| Cursor | `afterAgentResponse` fires before `stop` and carries `.text`. `stop` sends `loop_count` and `status`. `postToolUse` without a matcher fires for every tool and `additional_context` reaches the model. The judge's JSON envelope has `.result`. |
| Copilot CLI | Payload field names (`sessionId`, `transcriptPath`, `toolName`, `toolArgs`, `stopHookActive`). The transcript format and its last assistant message. Whether `preToolUse`/`postToolUse` fire for `exit_plan_mode`. The judge flags `-s --no-custom-instructions --no-ask-user`. |
| Copilot in VS Code | Whether Chronicle's `.github/hooks` file runs there and with which payload. That no hooks run twice when `chat.useClaudeHooks` is off. |
| macOS | The full unit suite under the system bash 3.2 and BSD tools (`grep -E`, `stat -f`, `date`, `pkill`). |
| All | Detection quality over a real session: decisions missed (false negatives) and judge calls that found nothing (`judged` with an empty list). |
