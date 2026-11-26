# Behavior reference

This page describes exactly what Chronicle does, event by event: what it reads, what it writes, what it tells the agent, and what it never does. It is meant for people who want to understand, debug or extend Chronicle. For a shorter overview, see [How it works](how-it-works.md).

Everything here describes Chronicle 0.2. The source of truth is `packages/engine/chronicle-hook` (the hook engine) and `packages/core/.apm/skills/chronicle-adr/scripts/chronicle-adr` (the bookkeeping script).

## Contents

1. [Components](#1-components)
2. [Session lifecycle](#2-session-lifecycle)
3. [Event reference](#3-event-reference)
4. [Plan capture in detail](#4-plan-capture-in-detail)
5. [Decisions made in conversation](#5-decisions-made-in-conversation)
6. [Audit mode and the judge](#6-audit-mode-and-the-judge)
7. [Loop safety](#7-loop-safety)
8. [What the agent is told](#8-what-the-agent-is-told)
9. [Writing an ADR](#9-writing-an-adr)
10. [Files and state](#10-files-and-state)
11. [The activity log](#11-the-activity-log)
12. [Failure behavior](#12-failure-behavior)
13. [Per-agent differences](#13-per-agent-differences)
14. [What Chronicle does not capture](#14-what-chronicle-does-not-capture)
15. [Privacy and data flow](#15-privacy-and-data-flow)

## 1. Components

| Component | Where it lives after install | Job |
|---|---|---|
| Hook engine `chronicle-hook` | `.claude/hooks/…/scripts/`, `.codex/hooks/…`, etc. (one copy per agent) | Reacts to the agent's hook events: plan capture, ADR write tracking and the optional audit. Never writes ADR prose itself and never blocks a turn. |
| Judge prompt `judge-prompt.md` | next to the engine | Instructions for the small model used in audit mode. |
| `chronicle-adr` script | inside the `chronicle-adr` skill folder | Numbering, file names, templates, status changes, index, git guard. Deterministic. |
| `chronicle-adr` skill | `.claude/skills/`, `.agents/skills/` | Procedure and quality bar for writing an ADR. |
| `decision-logger` subagent | the agent's agents folder | Runs the skill in its own context so ADR writing doesn't fill up the main conversation. |
| `log-decision`, `chronicle-review`, `chronicle-status` | skills, plus commands or prompts where the agent supports them | Manual capture, sweep and diagnostics. |
| Rule | `.claude/rules/`, `.cursor/rules/`, `.github/instructions/` at install; `AGENTS.md` (and `GEMINI.md` via import) after a one-time `apm compile` setup ([how](getting-started.md#add-the-chronicle-rule-to-agentsmd-codex-gemini-cli-opencode)) | The standing instruction to record each settled decision in the same turn. This is how decisions made in conversation get recorded. It works without hooks, but nothing enforces it. |

The engine is called as `chronicle-hook --harness <claude|codex|gemini|cursor|copilot> <event>`. It reads the agent's hook JSON on stdin and always prints exactly one JSON object and exits 0.

## 2. Session lifecycle

A typical session in Claude Code, which supports every path:

```
session starts ──► SessionStart        remind about an unimplemented plan from an earlier session (if any)
user prompt   ──► UserPromptSubmit     record the turn start and the prompt text
agent plans   ──► PreToolUse(ExitPlanMode)   store plan as pending
  approved    ──► PostToolUse(ExitPlanMode)  promote: archive plan, ask for one ADR per decision
  or rejected ──► (pending stays) … first project edit ──► PostToolUse(Edit) promotes it
user and agent settle something ──► the agent records it itself (the rule), via decision-logger or the skill
agent edits   ──► PostToolUse(Edit…)   ADR written? remember the time. Plan pending? promote.
turn ends     ──► Stop                 audit mode only: judge the exchange and log the result
```

Other agents follow the same lifecycle with their own event names (section 13). Where an event doesn't exist, that step is skipped.

## 3. Event reference

Each row is one logical engine event. The engine maps it to the agent's native name.

| Engine event | Claude Code | Codex | Gemini CLI | Cursor | Copilot | What Chronicle does |
|---|---|---|---|---|---|---|
| `session-start` | `SessionStart` | `SessionStart` | `SessionStart` | `sessionStart` | `sessionStart` | Deletes session state older than 7 days. If any session left an unpromoted plan, adds context: "there are unlogged items from earlier sessions… offer the user /log-decision". |
| `prompt` | `UserPromptSubmit` | `UserPromptSubmit` | `BeforeAgent` | `beforeSubmitPrompt` | `userPromptSubmitted` | Records when the turn started and stores the prompt text (the documented `prompt` field) for audit mode. Outputs nothing. |
| `pre-tool` | `PreToolUse(ExitPlanMode)` | — | `BeforeTool(exit_plan_mode)` | — | `preToolUse` | If the tool is the plan tool, stores the plan as pending. Never blocks the tool. |
| `post-tool` | `PostToolUse(ExitPlanMode\|Edit\|Write\|MultiEdit\|NotebookEdit)` | `PostToolUse(apply_patch\|Edit\|Write)` | `AfterTool(exit_plan_mode\|write_file\|replace)` | `postToolUse` (all tools) | `postToolUse` | Plan tool: promote (Claude Code) or store as pending (others). Edit tool: note ADR writes, promote a pending plan on the first project edit. Other tools: nothing. |
| `reply` | — | — | — | `afterAgentResponse` | — | Stores the final reply text for the following `stop` in audit mode (Cursor's `stop` doesn't include it). |
| `stop` | `Stop` | `Stop` | `AfterAgent` | `stop` | `agentStop` | Audit mode only (section 6). Always returns "allow". |

Chronicle never registers `SubagentStop`.

## 4. Plan capture in detail

A plan moves through three states: **none → pending → promoted**. Promotion happens at most once per plan.

### Pending

- **Trigger:** the agent calls its plan tool (`ExitPlanMode` / `exit_plan_mode`). The `pre-tool` hook fires *before* the user sees the approval dialog, so a plan is stored as pending even if the user rejects it or presses Esc.
- **What is stored:** the plan text (from the tool input), the plan file path if the agent has one (`planFilePath`, Gemini's `plan_path` / `plan_filename`, Copilot's session `plan.md`), and a timestamp. It goes into `.chronicle/state/<session>/pending-plan.json`.
- **Revisions:** a later plan-tool call overwrites the pending plan. Only the latest one counts.
- **Logged as** `plan-pending`.

### Promoted

Whichever of these comes first:

| Trigger | Agents | Why it exists |
|---|---|---|
| `PostToolUse(ExitPlanMode)` | Claude Code | This event only fires when the user approved the plan. |
| First edit of a file inside the project while a plan is pending | Claude Code, Gemini, Codex*, Cursor*, Copilot | Covers "Esc → ask a question → go ahead": you never approved the dialog, but implementation started. |
| `/log-decision` with no arguments | all | Manual promotion. The skill picks up the plan being implemented. |

\* Codex and Cursor have no plan tool event, so they never have a pending plan. The edit trigger only matters where a plan was stored.

Edits that **don't** promote a plan: files in the decisions directory (including `_plans/` and ADRs), files in `.chronicle/`, and files outside the project (for example Claude Code's own plan file under `~/.claude/plans/`).

**On promotion** Chronicle:

1. Re-reads the plan file if there is one, so edits the agent made to the plan after proposing it are included.
2. Deletes the pending state.
3. If `archivePlans` is on (the default), writes the plan word for word to `<decisionsDir>/_plans/<UTC timestamp>-<slug of the first line>.md`.
4. Adds context to the agent. The agent's turn is **not** interrupted. The message asks it to record one ADR per distinct decision in the plan, with Status Accepted, passing `--plan <archive>` so each ADR links back to the plan, and to skip task steps that involve no choice.
5. Logs `plan-promoted` with the archive path.

If `capture.planAccept` is `false`, the plan is dropped without archiving and nothing is asked of the agent.

### Never implemented

A pending plan that is never promoted produces no ADR and no archive. At the next session start, Chronicle reminds the agent that there is "an unimplemented plan from <date>", and the agent offers `/log-decision`. Pending state is deleted after 7 days.

## 5. Decisions made in conversation

No hook decides whether a decision was made. The agent does, following the rule that Chronicle installs:

- Record each settled design decision **in the same turn**, with the `decision-logger` subagent if available, otherwise the `chronicle-adr` skill. One ADR per decision.
- This includes decisions the user settles briefly ("ok", "do that", "option B" after options were laid out) and decisions the agent makes while implementing: adding or dropping a dependency, picking a library, pattern, data model, storage or protocol, changing module boundaries or a convention.
- Routine steps, bug fixes and refactors without a design change are not recorded.
- When implementing an approved plan, record its decisions first.
- Never record a decision twice: check `chronicle-adr list`, and don't start a second `decision-logger` for the same decision.

The rule's full text is in `packages/core/.apm/instructions/chronicle.instructions.md`. Where each agent reads it is listed in section 13. An agent that can't see the rule (Codex, Gemini CLI or OpenCode without the `AGENTS.md` setup) records nothing on its own.

**Why not a hook?** Earlier 0.2 previews ran a keyword filter and a judge at every end of turn and made the agent continue when they found something. In a live Claude Code test the agent had already started `decision-logger` before the hook ran, so the hook only added a redundant turn. The keyword filter missed most real phrasings ("ok do that", "use Postgres", "I'll use SQLite") and matched ordinary ones ("use a map instead of a loop", and Chronicle's own script name). Reading the conversation from each agent's transcript also picked up injected text that wasn't conversation. So detection was handed to the agent, and the judge became an optional audit.

**What catches misses:**

| Safety net | When | Works in |
|---|---|---|
| Plan capture (section 4) | a plan is approved or implemented | Claude Code, Gemini CLI, Copilot CLI |
| `/chronicle-review` | you run it, usually at the end of a session | every agent |
| `chronicle-adr guard` | at commit or in CI: dependency manifests, Dockerfiles, IaC or CI config changed without a new ADR | no agent needed |
| Audit mode (section 6) | after every turn, if switched on; logs only | every agent with hooks |

## 6. Audit mode and the judge

Audit mode is off by default. Switch it on with `"judge": {"mode": "audit"}`. It measures how well the rule works; it doesn't record anything or talk to the agent.

At every `stop`:

1. If `judge.mode` isn't `audit`, allow. Nothing else happens; this is the default.
2. If the agent signals a continuation caused by some stop hook (`stop_hook_active` / `stopHookActive`), or on Cursor the turn didn't complete (`status` other than `completed`), allow.
3. Get the reply from the documented hook field: `last_assistant_message` (Claude Code, Codex), `prompt_response` (Gemini), the stored `afterAgentResponse` text (Cursor). Copilot's `agentStop` has no reply field, so Chronicle reads the last top-level `assistant.message` entry from the transcript. Claude Code and Codex fall back to the transcript the same way if the field is empty, accepting only their own assistant entries (`type: "assistant"`, or Codex `agent_message` events). If there is no reply, allow.
4. Build the input: `USER:` the prompt stored at the last prompt event (up to 3,000 characters) and `ASSISTANT:` the reply (up to 5,000 characters). Nothing else from the conversation is used.
5. Note whether an ADR was written during this turn (the last ADR write is newer than the turn start).
6. Run the judge under the lock. Log `audit` with the decisions and `adr_this_turn`, or `audit-unavailable` if the judge couldn't run or answered with something unparseable.
7. Allow. Always.

`/chronicle-status` compares the audited decisions that had no ADR in their turn with `chronicle-adr list` by meaning, so a background `decision-logger` that finished after the turn isn't counted as a miss, and offers `/log-decision` for the rest.

**Cost:** one small-model call per turn, and the end of each turn waits for it (usually a few seconds; at most `judge.timeoutSec`).

### The judge call

A single non-interactive call to your agent's own CLI:

| Agent | Command |
|---|---|
| Claude Code | `claude -p --model haiku --output-format json --tools "" --no-session-persistence --settings '{"disableAllHooks":true}'` |
| Codex | `codex exec -s read-only --ephemeral --skip-git-repo-check -c features.hooks=false [-m <model>] -` |
| Gemini CLI | `gemini --output-format json [-m <model>] -p <prompt>` |
| Cursor | `agent -p --mode ask --output-format json [--model <model>] <prompt>` |
| Copilot | `copilot -s --no-custom-instructions --no-ask-user [--model <model>] -p <prompt>` |

- **Model:** `judge.model`. If unset, Claude Code uses `haiku` and the other agents use their CLI's default. Set a small model there.
- **Environment:** an empty temporary directory as the working directory (so no project hooks or instructions load), `CHRONICLE_JUDGE=1`, and a timeout of `judge.timeoutSec` (default 20 s). The timeout uses `timeout` where it's installed, otherwise a shell watchdog that ends the judge and its child processes (on macOS, for example). The temporary directory is deleted afterwards.
- **Input:** the judge prompt, the titles of up to 60 existing ADRs, and the prompt/reply pair.
- **Expected output:** `{"decisions":[{"title":"<noun phrase>","final":true|false}]}`. Chronicle accepts the answer wrapped in the CLI's JSON envelope or surrounded by text. Titles are cut to 120 characters.
- **What counts as a decision:** a *settled* choice between alternatives, adopting, replacing or dropping a dependency, a change to data flow, boundaries, storage, deployment or security, or a new convention. It doesn't count options listed without a choice, routine implementation, decisions already covered by an existing ADR, or text that only reports that an ADR was written.
- **Override for testing:** `CHRONICLE_JUDGE_CMD="<shell command>"` replaces the CLI. The prompt arrives on stdin.

## 7. Loop safety

Chronicle's hooks never block a turn, never make the agent continue and never retry, so they can't cause a continue loop. The only remaining risk is a **fork loop** in audit mode: the judge is itself an agent session that could load the same hooks and start another judge. Guards against it:

- `CHRONICLE_JUDGE=1` makes the engine exit before doing anything.
- The judge runs in an empty temp directory, so project hooks don't load, and with hooks disabled where the CLI allows it (Claude Code, Codex).
- A lock (`.chronicle/state/judge.lock`, cleared after 60 s if stale) allows only one judge at a time.

Each is tested on its own. Chronicle never hooks `SubagentStop`.

## 8. What the agent is told

Chronicle talks to the agent in exactly these situations. The wording is in the engine.

| Situation | Channel | Interrupts the turn? |
|---|---|---|
| Plan promoted | added context on the tool result | no |
| Unimplemented plan from an earlier session | added context at session start | no |

Everything else the agent knows about Chronicle comes from the rule and the skills. Audit mode tells the agent nothing.

## 9. Writing an ADR

The agent (usually the `decision-logger` subagent) follows the `chronicle-adr` skill:

1. Split the input into distinct decisions. One ADR per decision. Task steps with no choice are left out.
2. Run `chronicle-adr list`. Same subject and same choice → skip it. Same subject with a different choice → the new ADR supersedes the old one, and the user is told.
3. Status: Accepted if approved or being implemented, Proposed otherwise, or whatever status Chronicle's message gave.
4. `chronicle-adr new --title "<noun phrase>" --status <S> [--supersedes N] [--plan <archive>]`:
   - takes the next 4-digit number (highest existing number + 1, gaps are kept);
   - turns the title into a slug and **refuses** if an ADR with that slug already exists;
   - fills in number, title, date, status and an id (extended template);
   - prints the path;
   - records the time in `.chronicle/state/last-adr`, which audit mode reads.
5. The agent fills in Context, Decision, Consequences and, where the template has them, Alternatives / Rationale, using only what is in the conversation. If the reason is missing, it asks you one question instead of making one up.
6. When superseding, `chronicle-adr supersede N --by M` changes the old ADR's Status line. It's the only change ever made to an existing ADR.
7. `chronicle-adr index` regenerates `<decisionsDir>/README.md`.

Chronicle also notices ADRs that an agent writes without the script. Any edit to `<decisionsDir>/NNNN-*.md` counts as an ADR written.

## 10. Files and state

**In your repository (commit these):**

| Path | Content |
|---|---|
| `docs/decisions/NNNN-<slug>.md` | One ADR per decision |
| `docs/decisions/_plans/<ts>-<slug>.md` | Approved plans, word for word |
| `docs/decisions/README.md` | Generated index |
| `.chronicle.json` | Config (optional) |
| `apm.yml`, `apm.lock.yaml` | Your APM dependencies |

**Local, gitignored** (`.chronicle/` writes its own `.gitignore`):

| Path | Content |
|---|---|
| `.chronicle/log.jsonl` | Activity log (section 11) |
| `.chronicle/state/last-adr` | Time of the last ADR write (all sessions) |
| `.chronicle/state/judge.lock` | Present while a judge runs |
| `.chronicle/state/<session>/turn-start` | Turn start time |
| `…/last-prompt` | Your last prompt in this session (used only by audit mode) |
| `…/pending-plan.json` | Plan waiting for promotion |
| `…/last-reply` | Cursor only: the last reply text |

Session folders are deleted after 7 days. You can delete `.chronicle/` at any time; Chronicle then forgets pending plans.

## 11. The activity log

Each line of `.chronicle/log.jsonl` has `ts`, `harness`, `event`, `session` and `action`:

| `action` | Meaning |
|---|---|
| `plan-pending` | A plan was stored as pending |
| `plan-promoted` | A plan was promoted; `archive` holds its path |
| `audit` | Audit mode judged a turn; `decisions` holds its answer, `adr_this_turn` whether an ADR was written in that turn |
| `audit-unavailable` | Audit mode couldn't run the judge (CLI missing, not logged in, timeout, unparseable answer, or another judge still running) |

With audit mode off, a normal turn logs nothing. `/chronicle-status` summarizes the log. For a bug report, the relevant lines are usually enough.

## 12. Failure behavior

- **Any internal error** (missing `jq`, unreadable state, malformed input, a crash): the engine prints `{}`, which means "allow", and exits 0. Chronicle can fail to capture, but it can't block or break your agent.
- **Judge failure (audit mode):** logged as `audit-unavailable`; the turn ends normally.
- **Hook timeout:** the stop hook is registered with a 60 s timeout and all other hooks with 10 s. The audit judge's own timeout (20 s by default) keeps the stop hook well inside its limit.
- **Malformed `.chronicle.json`:** the hooks fall back to built-in defaults. `chronicle-adr` itself stops with "invalid JSON in .chronicle.json", so the agent will report it when it tries to write an ADR.
- **Platforms:** the scripts need bash 3.2 or later, `jq` and standard Unix tools. They run on Linux, macOS and WSL, but not in agents running natively on Windows. Only Linux has been tested.
- **Version 1 config** (`stopHook` keys): `stopHook.judgeModel` becomes `judge.model` in memory; the other v1 keys and keys from earlier 0.2 previews (`prefilterKeywords`, `capture.mode`, `judge.via`, …) are ignored. The file isn't rewritten.

## 13. Per-agent differences

| | Claude Code | Codex | Gemini CLI | Cursor | Copilot |
|---|---|---|---|---|---|
| Where the agent reads the rule | `.claude/rules/chronicle.md` | `AGENTS.md` (set up once) | `GEMINI.md` → `@./AGENTS.md` (set up once) | `.cursor/rules/chronicle.mdc` | `.github/instructions/chronicle.instructions.md` |
| Plan events | pre and post `ExitPlanMode` | none | `BeforeTool` / `AfterTool(exit_plan_mode)` | none | `pre`/`postToolUse` (unverified) |
| Plan promotion | approval or first edit | — | first write (`AfterTool` doesn't prove approval) | — | first edit |
| Audit: prompt from | `UserPromptSubmit.prompt` | `UserPromptSubmit.prompt` | `BeforeAgent.prompt` | `beforeSubmitPrompt.prompt` | `userPromptSubmitted.prompt` |
| Audit: reply from | `last_assistant_message` | `last_assistant_message`, otherwise the rollout's last `agent_message` | `prompt_response` | `afterAgentResponse.text`, stored for `stop` | transcript, last `assistant.message` |
| Hook commands | absolute (`${CLAUDE_PROJECT_DIR}`) | relative to repo root | relative | relative | relative |

OpenCode has no hooks: it reads the rule from `AGENTS.md`, and there is no plan capture or audit mode.

## 14. What Chronicle does not capture

- Decisions made outside an agent session (meetings, chat, code written by hand). Use `/log-decision`.
- Decisions the agent doesn't recognize or forgets to record despite the rule. `/chronicle-review` and the git guard are the safety nets; audit mode shows how often it happens.
- Anything in Codex, Gemini CLI or OpenCode without the `AGENTS.md` setup, unless you run `/log-decision` or `/chronicle-review`.
- Plans in Codex, Cursor and OpenCode as plans. The rule asks the agent to record a plan's decisions when it starts implementing, but the plan isn't archived.
- Copilot in VS Code most likely runs Chronicle's Copilot hooks (VS Code agent hooks, preview), but this is untested.

## 15. Privacy and data flow

- Chronicle has no server, no account and no telemetry.
- By default nothing leaves your machine beyond what your agent already sends.
- In audit mode, each turn makes one **judge call**: your last prompt (up to 3,000 characters), the agent's reply (up to 5,000 characters) and your existing ADR titles, sent through *your* agent CLI with *your* credentials to the same provider your agent already uses. No other conversation content, instructions or files are included.
- `.chronicle/log.jsonl` contains decision titles, and `.chronicle/state/<session>/last-prompt` your last prompt. Both stay local and are gitignored.
- The hooks run shell scripts from the package with your user's permissions. Review them before you install, as with any package that ships hooks. See [SECURITY.md](../SECURITY.md).
