# Testing Chronicle

Three layers:

- **1 and 2 are automated** and are for people changing Chronicle. Run them from this repository; they need no agent, no account and no setup, and they create and delete their own temporary projects.
- **3 is manual**: you install Chronicle into a scratch project, one per agent, and use the agent as normal. This is the only layer that shows how a real agent behaves.

## 1. Unit tests: `make test`

`tests/run.sh` feeds hook payloads for each agent into `packages/engine/chronicle-hook` and checks the JSON it returns. The audit judge is replaced via `CHRONICLE_JUDGE_CMD`, so no network and no agent CLI is needed. Covered:

- Stop: with audit off, nothing is judged or logged; with audit on, the judge gets exactly the recorded prompt and the reply, the verdict and `adr_this_turn` are logged, and the hook always returns "allow" (judge yes, no, failing, timing out with `timeout` and with the shell watchdog used on macOS).
- Fork guard: `CHRONICLE_JUDGE=1`, the judge lock, the judge's own session re-entering the hook; also `stop_hook_active`, an empty reply and garbage input.
- Reply text: only from documented fields or, as a fallback, from the agent's own assistant entries in the transcript (Claude Code request copies, Codex `response_item`s and Copilot tool results are ignored).
- Plans: pending on `PreToolUse(ExitPlanMode)`, promotion on approval and on the first project edit after a rejected dialog, edits outside the project don't promote, the latest plan revision is archived, no double promotion, `SessionStart` reminder for an unimplemented plan.
- Per agent: Codex (`apply_patch` ADR detection, `agent_message` fallback), Gemini (`prompt_response`, `plan_path`, `AfterTool` promotion, never `deny`), Cursor (`afterAgentResponse` → `stop`, aborted turns), Copilot (camelCase payloads, transcript parsing).
- `chronicle-adr`: numbering with gaps, duplicate refusal, supersede, index, v1 config migration, guard in warn and block mode.

`make lint` runs shellcheck over all scripts. `make check-sync` fails if a hook package's bundled engine drifted from `packages/engine/`. Run `make sync` after editing the engine.

## 2. APM install test: `make test-apm`

`tests/apm-install.sh` installs this repository with APM 0.38.1 into a temporary project with `.claude`, `.codex`, `.gemini`, `.cursor`, `.github` and `.opencode`. It checks every deployed file and hook entry against the support matrix, including that a pre-existing user hook survives, that Gemini doesn't get a `SessionEnd` mapping, and that Copilot gets the native hook format. It also runs the documented `AGENTS.md` setup: a hand-written `AGENTS.md` is left alone by default, and with `compilation.agents_md.mode: managed_section` the rule lands between the markers while your own text stays. It then runs `apm uninstall` and checks that only Chronicle's entries are gone. To test another APM version: `make test-apm APM=apm`.

## 3. Live tests (manual, per agent)

Create one scratch project per agent, outside any other repository, and install from your local checkout:

```bash
mkdir chronicle_test_claude && cd chronicle_test_claude && git init
apm install /path/to/chronicle --target claude      # codex, gemini, cursor, copilot, opencode
```

For Codex, Gemini CLI and OpenCode, also add the rule to `AGENTS.md` ([how](docs/getting-started.md#add-the-chronicle-rule-to-agentsmd-codex-gemini-cli-opencode)). Start the agent from the project root, and watch `tail -F .chronicle/log.jsonl` in a second terminal. Then:

| # | Do | Expect |
|---|---|---|
| L1 | *"Compare Redis vs SQLite for this CLI's cache, then decide: we'll go with SQLite instead of Redis. No code."* | the agent records one ADR in the same turn, on its own |
| L1b | Ask for options ("Postgres or SQLite for the user store?"), then answer only *"ok, do that"* | one ADR for the chosen option |
| L1c | *"Add input validation to the config loader"* in a project where that means picking a library | an ADR for the library choice, or a reason in the reply why it isn't one |
| L2 | Ask a question without a decision | no ADR |
| L3 | Plan mode: propose a plan, press Esc, ask a question, leave plan mode, say "go ahead" | `plan-pending`, then `plan-promoted` at the first edit; one ADR per decision in the plan plus one `_plans/` file |
| L4 | Plan mode: propose a plan, reject it, end the session, start a new one | no ADR; the new session mentions the unimplemented plan |
| L5 | Approve a plan | ADRs from the plan, no duplicates |
| L7 | Set `"judge": {"mode": "audit"}`, repeat L1, L1b and L2, then run `/chronicle-status` | one `audit` entry per turn, none blocking; the status report lists no misses for L1/L1b |

Status (0.2.0):

| Agent | L1 | L1b | L1c | L2 | L3 | L4 | L5 | L7 |
|---|---|---|---|---|---|---|---|---|
| Claude Code | ✅ (agent recorded it before the end of the turn) | not yet run | not yet run | not yet run | unit-tested only | unit-tested only | unit-tested only | not yet run |
| Codex, Gemini, Cursor, Copilot | not yet run | | | | | | | |
| OpenCode | not yet run (L1, L1b, L2 only; check `/log-decision` and `/chronicle-review`) | | | | | | | |

Verified: a GitHub install (`apm install "architraceio/chronicle#apm-package"`) resolves all sub-packages and deploys the same paths as a local install.

Checked against official docs, not yet in a live run: Codex hooks are on by default; trust is given in `/hooks`, tied to a hash, and asked again after a change; Stop has `last_assistant_message`, `stop_hook_active`, `transcript_path` and `turn_id`, and `decision: block` continues. Gemini's `AfterAgent` has `prompt_response`; `deny` discards the reply; `AfterTool` and `BeforeAgent` accept `additionalContext`; the plan field is `plan_path`; project hooks are fingerprinted. Cursor runs project hooks from the project root; `agent -p` supports `--mode ask` and `--output-format json`. Copilot: `postToolUse` and `sessionStart` accept `additionalContext`; prompt-hook output is dropped; `agentStop` honors `decision: block`. VS Code reads `.github/hooks/*.json`.

Live-test checklist: each item is an assumption the code relies on that only a real session can confirm.

| Agent | Check |
|---|---|
| All | How reliably the agent follows the rule (L1, L1b, L1c, and over a longer session with audit mode). This is the main open question. |
| Claude Code | `PreToolUse(ExitPlanMode)` fires when the plan dialog is rejected (L3, L4). The plan text is in `tool_response.plan` and the path in `planFilePath` (L5). |
| Codex | The rule is read from `AGENTS.md`. For audit: `codex exec` accepts `-s read-only` and `-c features.hooks=false` (watch for `audit-unavailable`), `UserPromptSubmit` carries `prompt`, the hook timeout is in seconds, and hooks find the engine when Codex is started from a subdirectory. |
| Gemini CLI | The rule is read through `GEMINI.md` → `AGENTS.md`. `exit_plan_mode` sends `plan_path` and the plan file is found (`GEMINI_PLANS_DIR`). For audit: the judge's `--output-format json` envelope has `.response`. |
| Cursor | The rule in `.cursor/rules/` is applied. For audit: `afterAgentResponse` fires before `stop` and carries `.text`, `beforeSubmitPrompt` carries `prompt`, the judge's JSON envelope has `.result`. |
| Copilot CLI | Payload field names (`sessionId`, `transcriptPath`, `toolName`, `toolArgs`, `prompt`). The transcript's `assistant.message` entries. Whether `preToolUse`/`postToolUse` fire for `exit_plan_mode`. The judge flags `-s --no-custom-instructions --no-ask-user`. |
| Copilot in VS Code | Whether Chronicle's `.github/hooks` file runs there and with which payload. That no hooks run twice when `chat.useClaudeHooks` is off. |
| macOS | The full unit suite under the system bash 3.2 and BSD tools (`grep -E`, `stat -f`, `date`, `pkill`). |
