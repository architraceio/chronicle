# Agent support matrix

Chronicle ships one APM package with a shared core (skill, templates, agent, rule) and one hook package per agent. APM installs only the hook packages for the agents you target. What works depends on what each agent's hook system allows.

✅ works · ⚠️ partial · ❌ not available

| Capability | Claude Code | Codex | Gemini CLI | Cursor | Copilot | OpenCode |
|---|---|---|---|---|---|---|
| Hooks installed by APM | ✅ `.claude/settings.json` | ✅ `.codex/hooks.json` | ✅ `.gemini/settings.json` | ✅ `.cursor/hooks.json` | ✅ `.github/hooks/` (CLI, cloud agent) | ❌ no hook system |
| Extra step before hooks run | none | trust in `/hooks` | trust prompt | none | none | n/a |
| Plan approved → ADRs | ✅ | ❌ no plan event (rule + judge) | ✅ via `exit_plan_mode` | ❌ no plan event (rule + judge) | ⚠️ CLI `exit_plan_mode` (unverified) | ❌ |
| Plan implemented without approval → ADRs | ✅ first edit promotes the plan | ❌ | ✅ first write promotes the plan | ❌ | ⚠️ (unverified) | ❌ |
| Plan archived verbatim | ✅ | ❌ | ✅ | ❌ | ⚠️ | ❌ |
| Mid-session detection (filter + judge) | ✅ | ✅ | ✅ | ✅ | ✅ (transcript) | ❌ |
| Agent records it in the same turn | ✅ | ✅ | ⚠️ next tool call or prompt (deferred) | ✅ follow-up message | ✅ | ❌ |
| Judge CLI | `claude -p` | `codex exec` | `gemini -p` | `agent -p` | `copilot -p` | n/a |
| `decision-logger` subagent | ✅ | ✅ | ❌ skill in main context | ✅ | ✅ | ✅ |
| `chronicle-adr` skill | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `/log-decision`, `/chronicle-review`, `/chronicle-status` | ✅ skills | ✅ `$log-decision` … | ✅ commands | ✅ skills | ✅ skills (CLI), prompts (VS Code) | ✅ skills |
| Rule (instructions) | via `apm compile` | `AGENTS.md` via `apm compile` | `GEMINI.md` via `apm compile` | ✅ `.cursor/rules/` | ✅ `.github/instructions/` | `AGENTS.md` via `apm compile` |
| **Overall** | **Full** | **Strong** (no plan hook) | **Strong** (deferred delivery) | **Strong** (no plan hook) | **Good** in CLI, manual in VS Code | **Manual** |

Verified end-to-end with a live agent: Claude Code. The other agents are covered by unit tests against their documented hook payloads; live verification is tracked in [TESTING.md](../TESTING.md).

## Workarounds for the gaps

**Rule.** The core package ships one short instruction ("record finalized decisions before ending the turn; when implementing an approved plan, record its decisions first"). APM places it natively for Cursor and Copilot. For `AGENTS.md`, `GEMINI.md` and `CLAUDE.md`, run `apm compile` after installing. The rule is advisory: it steers the model but enforces nothing. This is the main workaround for Codex and Cursor plans and for OpenCode.

**Deferred delivery (Gemini).** Gemini's end-of-turn hook can only force a retry by discarding the reply, so Chronicle never does that. It shows you a hint immediately and injects "unrecorded decision: …" into the agent's context at the next tool call or prompt.

**Sweep.** `/chronicle-review` lists decisions in the current conversation that have no ADR and records the ones you pick. It works in every agent, including OpenCode and Copilot in VS Code.

**Git guard.** `chronicle-adr guard install` adds a pre-commit hook that warns (or blocks) when decision-heavy files change without a new ADR. It works with no agent at all.

## Per-agent notes

### Claude Code
Full support. Hooks: `SessionStart`, `UserPromptSubmit`, `PreToolUse(ExitPlanMode)`, `PostToolUse(ExitPlanMode|Edit|Write|MultiEdit|NotebookEdit)`, `Stop`. The judge runs `claude -p --model haiku` with hooks disabled, no tools, no session persistence, in an empty temp directory.

### Codex
Hooks need trust in `/hooks`. Codex re-asks after each update because trust is bound to the hook's hash. Codex has no plan-approval event (`update_plan` is a progress checklist), so plans are covered by the rule and by the judge reading the plan reply. Set `judge.model` to a small model; otherwise the CLI default is used.

### Gemini CLI
Hooks are fingerprinted and need trust. Plans are captured when the agent leaves plan mode itself (`exit_plan_mode`). Gemini does not fire hooks when you toggle plan mode manually. No subagents are deployed; the `chronicle-adr` skill runs in the main context.

### Cursor
`afterAgentResponse` gives Chronicle the final reply; the `stop` hook makes the agent continue via a follow-up message, with `loop_limit: 1`. Cursor has no plan-mode hook. Requires `CURSOR_API_KEY` for the headless judge, otherwise Chronicle falls back to the self-check.

### GitHub Copilot
Hooks run in Copilot CLI and the cloud agent (`.github/hooks/`). Copilot in VS Code gets the rule, the agent and the prompt files (`/log-decision`, `/chronicle-review`), but no Chronicle hooks.

### OpenCode
No hook system, so capture is manual: the `decision-logger` agent, the skills, the rule in `AGENTS.md` (after `apm compile`), `/chronicle-review` and the git guard.

## Known limitations

- Hook commands for Codex, Gemini, Cursor and Copilot use paths relative to the repository root, as APM writes them. Start the agent from the repository root.
- The judge uses your agent CLI and its credentials. If the CLI is missing or not logged in, Chronicle falls back to `judge.fallback` (`self` asks the main agent to check, `nudge` only hints, `off` does nothing) and logs `judge-unavailable`.
- Decisions phrased without any decision language are not caught by the filter. Add terms via `prefilterKeywords`, or use `/chronicle-review`.
