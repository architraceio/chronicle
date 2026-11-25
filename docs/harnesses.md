# Agent support in detail

This is the full matrix for people who want specifics. The short version is in the [README](../README.md#supported-agents) and [Getting started](getting-started.md#what-to-expect-in-your-agent); event-level behavior is in the [behavior reference](behavior.md#13-per-agent-differences).

Chronicle ships one APM package with a shared core (skill, templates, agent, rule) and one hook package per agent. APM installs only the hook packages for the agents you target. What works depends on what each agent's hook system allows.

✅ works · ⚠️ partial · ❌ not available

| Capability | Claude Code | Codex | Gemini CLI | Cursor | Copilot | OpenCode |
|---|---|---|---|---|---|---|
| Hooks installed by APM | ✅ `.claude/settings.json` | ✅ `.codex/hooks.json` | ✅ `.gemini/settings.json` | ✅ `.cursor/hooks.json` | ✅ `.github/hooks/` (CLI, cloud agent; VS Code reads it too, untested) | ❌ no hook system |
| Extra step before hooks run | none | trust in `/hooks` | trust prompt | none | none | n/a |
| Plan approved → ADRs | ✅ | ❌ no plan event (rule + judge) | ✅ via `exit_plan_mode` | ❌ no plan event (rule + judge) | ⚠️ CLI `exit_plan_mode` (unverified) | ❌ |
| Plan implemented without approval → ADRs | ✅ first edit promotes the plan | ❌ | ✅ first write promotes the plan | ❌ | ⚠️ (unverified) | ❌ |
| Plan archived verbatim | ✅ | ❌ | ✅ | ❌ | ⚠️ | ❌ |
| Mid-session detection (filter + judge) | ✅ | ✅ | ✅ | ✅ | ✅ (transcript) | ❌ |
| Agent records it in the same turn | ✅ | ✅ | ⚠️ next tool call or prompt (deferred) | ✅ follow-up message | ✅ | ❌ |
| Reminder after a hint (`capture.mode: nudge`) | next prompt or tool call | next prompt or tool call | next prompt or tool call | next tool call, no hint shown | next tool call, no hint shown | ❌ |
| Judge CLI | `claude -p` | `codex exec` | `gemini -p` | `agent -p` | `copilot -p` | n/a |
| `decision-logger` subagent | ✅ | ✅ | ❌ skill in main context | ✅ | ✅ | ✅ |
| `chronicle-adr` skill | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `/log-decision`, `/chronicle-review`, `/chronicle-status` | ✅ skills | ✅ `$log-decision` … | ✅ commands | ✅ skills | ✅ skills (CLI), prompts (VS Code) | ✅ skills |
| Rule (instructions) | ✅ `.claude/rules/` | ⚠️ `AGENTS.md`, set up once | optional, `GEMINI.md` → `AGENTS.md` | ✅ `.cursor/rules/` | ✅ `.github/instructions/` | ⚠️ `AGENTS.md`, set up once |
| **Overall** | **Full** | **Strong** (no plan hook) | **Strong** (deferred delivery) | **Strong** (no plan hook) | **Good** in CLI; VS Code untested | **Manual** |

Verified end-to-end with a live agent: Claude Code. The other agents are covered by unit tests against their documented hook payloads; live verification is tracked in [TESTING.md](../TESTING.md).

## Workarounds for the gaps

**Rule.** The core package ships one short instruction ("record finalized decisions before ending the turn; when implementing an approved plan, record its decisions first"). APM installs it natively for Claude Code (`.claude/rules/`), Cursor and Copilot. Codex and OpenCode read it from `AGENTS.md`, which needs a one-time setup with `apm compile`, and a marked section if you already have an `AGENTS.md`: see [Add the Chronicle rule to AGENTS.md](getting-started.md#add-the-chronicle-rule-to-agentsmd-codex-opencode). The rule is advisory: it steers the model but enforces nothing. This is the main workaround for Codex and Cursor plans and for OpenCode.

**Deferred delivery.** Gemini's end-of-turn hook can only force a retry by discarding the reply, so Chronicle never does that. It shows you a hint immediately and injects "unrecorded decision: …" into the agent's context at the next tool call or prompt. The same happens in every agent with `capture.mode: "nudge"`. Cursor's and Copilot's prompt hooks can't add context, so there the reminder comes with the result of the agent's next tool call. Those two agents also have no channel for showing you a hint, so in nudge mode you won't see one there.

**Sweep.** `/chronicle-review` lists decisions in the current conversation that have no ADR and records the ones you pick. It works in every agent, including OpenCode and Copilot in VS Code.

**Git guard.** `chronicle-adr guard install` adds a pre-commit hook that warns (or blocks) when decision-heavy files change without a new ADR. It works with no agent at all.

## Per-agent notes

### Claude Code
Full support. Hooks: `SessionStart`, `UserPromptSubmit`, `PreToolUse(ExitPlanMode)`, `PostToolUse(ExitPlanMode|Edit|Write|MultiEdit|NotebookEdit)`, `Stop`. The judge runs `claude -p --model haiku` with hooks disabled, no tools, no session persistence, in an empty temp directory.

### Codex
Hooks need trust in `/hooks`. Codex re-asks after each update because trust is bound to the hook's hash. Codex has no plan-approval event (`update_plan` is a progress checklist), so plans are covered by the rule and by the judge reading the plan reply. Set `judge.model` to a small model; otherwise the CLI default is used.

### Gemini CLI
Note: Google replaced Gemini CLI with Antigravity CLI for free-tier and Google One users on June 18, 2026. Chronicle supports Gemini CLI only; Antigravity hasn't been looked at.

Hooks are fingerprinted and need trust. Plans are captured when the agent leaves plan mode itself (`exit_plan_mode`). Gemini does not fire hooks when you toggle plan mode manually. No subagents are deployed; the `chronicle-adr` skill runs in the main context.

### Cursor
`afterAgentResponse` gives Chronicle the final reply; the `stop` hook makes the agent continue via a follow-up message, with `loop_limit: 1`. Cursor has no plan-mode hook. The headless judge (`agent -p`) needs the Cursor CLI to be logged in (`agent login`) or `CURSOR_API_KEY` to be set. Otherwise Chronicle falls back to the self-check. Project hooks run from the project root, which matches the paths APM writes.

### GitHub Copilot
Hooks run in Copilot CLI and the cloud agent (`.github/hooks/`). Copilot sets `stop_hook_active` on a continued turn and ends the turn itself after 8 blocks in a row; Chronicle's own guards 3–6 apply as well.

**Copilot in VS Code.** VS Code has agent hooks, in preview, and reads `.github/hooks/*.json`, so Chronicle's Copilot hooks most likely run there too. This hasn't been tested, and VS Code's payloads may differ from the CLI's. VS Code also gets the rule, the agent and the prompt files (`/log-decision`, `/chronicle-review`), which work either way. If you also use Claude Code in the same repository, leave VS Code's `chat.useClaudeHooks` off. With it on, VS Code also runs the hooks in `.claude/settings.json`, so Chronicle would run twice per turn with the wrong payload format. To turn off hooks in VS Code, set `chat.useHooks` to `false`.

### OpenCode
No hook system, so capture is manual: the `decision-logger` agent, the skills, the rule in `AGENTS.md` (one-time setup, see [Getting started](getting-started.md#add-the-chronicle-rule-to-agentsmd-codex-opencode)), `/chronicle-review` and the git guard.

## Known limitations

- Hook commands for Codex, Gemini, Cursor and Copilot use paths relative to the repository root, as APM writes them. Cursor runs project hooks from the project root. For the others, start the agent from the repository root.
- Platforms: Linux, macOS and WSL. The hooks are bash scripts (bash 3.2 or later), so agents running natively on Windows can't run them. Only Linux has been tested; on macOS the judge timeout uses a built-in watchdog because `timeout` isn't installed by default.
- The judge uses your agent CLI and its credentials. If the CLI is missing or not logged in, Chronicle falls back to `judge.fallback` (`self` asks the main agent to check, `nudge` only hints, `off` does nothing) and logs `judge-unavailable`.
- Decisions phrased without any decision language are not caught by the filter. Add terms via `prefilterKeywords`, or use `/chronicle-review`.
