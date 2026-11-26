# Agent support in detail

This is the full matrix for people who want specifics. The short version is in the [README](../README.md#supported-agents) and [Getting started](getting-started.md#what-to-expect-in-your-agent); event-level behavior is in the [behavior reference](behavior.md#13-per-agent-differences).

Chronicle ships one APM package with a shared core (skill, templates, agent, rule) and one hook package per agent. APM installs only the hook packages for the agents you target. What works depends on what each agent's hook system allows.

✅ works · ⚠️ partial · ❌ not available

| Capability | Claude Code | Codex | Gemini CLI | Cursor | Copilot | OpenCode |
|---|---|---|---|---|---|---|
| Hooks installed by APM | ✅ `.claude/settings.json` | ✅ `.codex/hooks.json` | ✅ `.gemini/settings.json` | ✅ `.cursor/hooks.json` | ✅ `.github/hooks/` (CLI, cloud agent; VS Code reads it too, untested) | ❌ no hook system |
| Extra step before hooks run | none | trust in `/hooks` (only needed for audit mode) | trust prompt | none | none | n/a |
| Plan approved → ADRs | ✅ | ❌ no plan event (rule) | ✅ via `exit_plan_mode` | ❌ no plan event (rule) | ⚠️ CLI `exit_plan_mode` (unverified) | ❌ |
| Plan implemented without approval → ADRs | ✅ first edit promotes the plan | ❌ | ✅ first write promotes the plan | ❌ | ⚠️ (unverified) | ❌ |
| Plan archived verbatim | ✅ | ❌ | ✅ | ❌ | ⚠️ | ❌ |
| Decisions in conversation recorded by the agent (rule) | ✅ seen live | ⚠️ needs `AGENTS.md` | ⚠️ needs `AGENTS.md` + `GEMINI.md` import | ⚠️ | ⚠️ | ⚠️ needs `AGENTS.md` |
| Audit mode: reply from | `last_assistant_message` | `last_assistant_message` | `prompt_response` | `afterAgentResponse` | transcript (`assistant.message`) | n/a |
| Audit judge CLI | `claude -p` | `codex exec` | `gemini -p` | `agent -p` | `copilot -p` | n/a |
| `decision-logger` subagent | ✅ | ✅ | ❌ skill in main context | ✅ | ✅ | ✅ |
| `chronicle-adr` skill | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `/log-decision`, `/chronicle-review`, `/chronicle-status` | ✅ skills | ✅ `$log-decision` … | ✅ commands | ✅ skills | ✅ skills (CLI), prompts (VS Code) | ✅ skills |
| Rule (instructions) | ✅ `.claude/rules/` | ⚠️ `AGENTS.md`, set up once | ⚠️ `GEMINI.md` → `AGENTS.md`, set up once | ✅ `.cursor/rules/` | ✅ `.github/instructions/` | ⚠️ `AGENTS.md`, set up once |
| **Overall** | **Full** | **Rule only** (no plan hook) | **Full** once the rule is set up | **Rule only** (no plan hook) | **Full** in CLI if plan hooks fire; VS Code untested | **Rule only** |

Verified end-to-end with a live agent: Claude Code. The other agents are covered by unit tests against their documented hook payloads; live verification is tracked in [TESTING.md](../TESTING.md).

## Workarounds for the gaps

**Rule.** The core package ships one short instruction: record each settled design decision in the same turn, including quick acceptances and choices made while implementing; when implementing an approved plan, record its decisions first. This is how decisions made in conversation get recorded, in every agent. APM installs it natively for Claude Code (`.claude/rules/`), Cursor and Copilot. Codex, Gemini CLI and OpenCode read it from `AGENTS.md`, which needs a one-time setup with `apm compile`, and a marked section if you already have an `AGENTS.md`: see [Add the Chronicle rule to AGENTS.md](getting-started.md#add-the-chronicle-rule-to-agentsmd-codex-gemini-cli-opencode). The rule steers the model; nothing enforces it. Plan hooks, the sweep, the git guard and audit mode cover what it misses.

**Audit mode.** Optional (`"judge": {"mode": "audit"}`). After each turn a small model checks your last message and the agent's reply, and logs decisions it sees and whether an ADR was written. It never messages or blocks the agent, so it behaves the same in every agent. `/chronicle-status` lists possible misses.

**Sweep.** `/chronicle-review` lists decisions in the current conversation that have no ADR and records the ones you pick. It works in every agent, including OpenCode and Copilot in VS Code.

**Git guard.** `chronicle-adr guard install` adds a pre-commit hook that warns (or blocks) when decision-heavy files change without a new ADR. It works with no agent at all.

## Per-agent notes

### Claude Code
Full support. Hooks: `SessionStart`, `UserPromptSubmit`, `PreToolUse(ExitPlanMode)`, `PostToolUse(ExitPlanMode|Edit|Write|MultiEdit|NotebookEdit)`, `Stop` (audit only). The rule is installed to `.claude/rules/chronicle.md` and is loaded every turn. The audit judge runs `claude -p --model haiku` with hooks disabled, no tools, no session persistence, in an empty temp directory.

### Codex
Codex has no plan-approval event (`update_plan` is a progress checklist), so everything rests on the rule in `AGENTS.md`. The hooks only matter for audit mode; they need trust in `/hooks`, and Codex re-asks after each update because trust is bound to the hook's hash. For audit mode, set `judge.model` to a small model; otherwise the CLI default is used.

### Gemini CLI
Note: Google replaced Gemini CLI with Antigravity CLI for free-tier and Google One users on June 18, 2026. Chronicle supports Gemini CLI only; Antigravity hasn't been looked at.

Hooks are fingerprinted and need trust. Plans are captured when the agent leaves plan mode itself (`exit_plan_mode`). Gemini does not fire hooks when you toggle plan mode manually. Decisions in conversation rely on the rule, which Gemini reads through `GEMINI.md` → `AGENTS.md`. No subagents are deployed; the `chronicle-adr` skill runs in the main context.

### Cursor
Cursor has no plan-mode hook, so decisions rest on the rule in `.cursor/rules/chronicle.mdc`. For audit mode, `afterAgentResponse` gives Chronicle the final reply, and the headless judge (`agent -p`) needs the Cursor CLI to be logged in (`agent login`) or `CURSOR_API_KEY` to be set; otherwise the audit logs `audit-unavailable`. Project hooks run from the project root, which matches the paths APM writes.

### GitHub Copilot
Hooks run in Copilot CLI and the cloud agent (`.github/hooks/`). For audit mode, the reply is read from the session transcript (the last `assistant.message` entry), because `agentStop` doesn't carry it.

**Copilot in VS Code.** VS Code has agent hooks, in preview, and reads `.github/hooks/*.json`, so Chronicle's Copilot hooks most likely run there too. This hasn't been tested, and VS Code's payloads may differ from the CLI's. VS Code also gets the rule, the agent and the prompt files (`/log-decision`, `/chronicle-review`), which work either way. If you also use Claude Code in the same repository, leave VS Code's `chat.useClaudeHooks` off. With it on, VS Code also runs the hooks in `.claude/settings.json`, so Chronicle would run twice per turn with the wrong payload format. To turn off hooks in VS Code, set `chat.useHooks` to `false`.

### OpenCode
No hook system. Decisions are recorded through the rule in `AGENTS.md` (one-time setup, see [Getting started](getting-started.md#add-the-chronicle-rule-to-agentsmd-codex-gemini-cli-opencode)), the `decision-logger` agent and the skills, with `/chronicle-review` and the git guard as safety nets. Plans have no hook, and there's no audit mode.

## Known limitations

- Hook commands for Codex, Gemini, Cursor and Copilot use paths relative to the repository root, as APM writes them. Cursor runs project hooks from the project root. For the others, start the agent from the repository root.
- Platforms: Linux, macOS and WSL. The hooks are bash scripts (bash 3.2 or later), so agents running natively on Windows can't run them. Only Linux has been tested; on macOS the judge timeout uses a built-in watchdog because `timeout` isn't installed by default.
- Decisions in conversation are only recorded if the agent follows the rule. How reliably it does depends on the model and the session; audit mode measures it.
- The audit judge uses your agent CLI and its credentials. If the CLI is missing, not logged in or too slow, Chronicle logs `audit-unavailable` and carries on.
