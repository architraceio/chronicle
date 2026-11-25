# Behavior reference

This page describes exactly what Chronicle does, event by event: what it reads, what it writes, what it tells the agent, and what it never does. It is meant for people who want to understand, debug or extend Chronicle. For a shorter overview, see [How it works](how-it-works.md).

Everything here describes Chronicle 0.2. The source of truth is `packages/engine/chronicle-hook` (the hook engine) and `packages/core/.apm/skills/chronicle-adr/scripts/chronicle-adr` (the bookkeeping script).

## Contents

1. [Components](#1-components)
2. [Session lifecycle](#2-session-lifecycle)
3. [Event reference](#3-event-reference)
4. [Plan capture in detail](#4-plan-capture-in-detail)
5. [Mid-session capture in detail](#5-mid-session-capture-in-detail)
6. [The judge](#6-the-judge)
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
| Hook engine `chronicle-hook` | `.claude/hooks/…/scripts/`, `.codex/hooks/…`, etc. (one copy per agent) | Reacts to the agent's hook events. Decides whether to capture, and tells the agent what to do. Never writes ADR prose itself. |
| Judge prompt `judge-prompt.md` | next to the engine | Instructions for the small model that confirms decisions. |
| `chronicle-adr` script | inside the `chronicle-adr` skill folder | Numbering, file names, templates, status changes, index, git guard. Deterministic. |
| `chronicle-adr` skill | `.claude/skills/`, `.agents/skills/` | Procedure and quality bar for writing an ADR. |
| `decision-logger` subagent | the agent's agents folder | Runs the skill in its own context so ADR writing doesn't fill up the main conversation. |
| `log-decision`, `chronicle-review`, `chronicle-status` | skills, plus commands or prompts where the agent supports them | Manual capture, sweep and diagnostics. |
| Rule | `.claude/rules/`, `.cursor/rules/`, `.github/instructions/` at install; `AGENTS.md` (and `GEMINI.md` via import) after a one-time `apm compile` setup ([how](getting-started.md#add-the-chronicle-rule-to-agentsmd-codex-opencode)) | A short standing instruction to record finalized decisions. It works without hooks, but nothing enforces it. |

The engine is called as `chronicle-hook --harness <claude|codex|gemini|cursor|copilot> <event>`. It reads the agent's hook JSON on stdin and always prints exactly one JSON object and exits 0.

## 2. Session lifecycle

A typical session in Claude Code, which supports every path:

```
session starts ──► SessionStart        remind about leftovers from earlier sessions (if any)
user prompt   ──► UserPromptSubmit     turn counter +1; deliver pending reminders (nudge mode)
agent plans   ──► PreToolUse(ExitPlanMode)   store plan as pending
  approved    ──► PostToolUse(ExitPlanMode)  promote: archive plan, ask for one ADR per decision
  or rejected ──► (pending stays) … first project edit ──► PostToolUse(Edit) promotes it
agent edits   ──► PostToolUse(Edit…)   ADR written? remember the time. Plan pending? promote. Reminders pending? deliver.
turn ends     ──► Stop                 guards → window → prefilter → judge → maybe continue once
(continuation turn ends) ──► Stop      guard stops it: no second block in the same turn
```

Other agents follow the same lifecycle with their own event names (section 13). Where an event doesn't exist, that step is skipped.

## 3. Event reference

Each row is one logical engine event. The engine maps it to the agent's native name.

| Engine event | Claude Code | Codex | Gemini CLI | Cursor | Copilot | What Chronicle does |
|---|---|---|---|---|---|---|
| `session-start` | `SessionStart` | `SessionStart` | `SessionStart` | `sessionStart` | `sessionStart` | Deletes session state older than 7 days. If any session left an unpromoted plan or an undelivered decision, adds context: "there are unlogged items from earlier sessions… offer the user /log-decision". |
| `prompt` | `UserPromptSubmit` | `UserPromptSubmit` | `BeforeAgent` | `beforeSubmitPrompt` | `userPromptSubmitted` | Increments the turn counter and records when the turn started. On Claude Code, Codex and Gemini, it also delivers decisions flagged in nudge mode that haven't been delivered yet. Cursor's `beforeSubmitPrompt` can only allow or block, and Copilot ignores `userPromptSubmitted` output, so there delivery waits for the next tool result. |
| `pre-tool` | `PreToolUse(ExitPlanMode)` | — | `BeforeTool(exit_plan_mode)` | — | `preToolUse` | If the tool is the plan tool, stores the plan as pending. Never blocks the tool. |
| `post-tool` | `PostToolUse(ExitPlanMode\|Edit\|Write\|MultiEdit\|NotebookEdit)` | `PostToolUse(apply_patch\|Edit\|Write)` | `AfterTool(exit_plan_mode\|write_file\|replace)` | `postToolUse` (all tools) | `postToolUse` | Plan tool: promote (Claude Code) or store as pending (others). Edit tool: note ADR writes, promote a pending plan on the first project edit. Any other tool result: deliver undelivered reminders, unless a plan was just promoted. |
| `reply` | — | — | — | `afterAgentResponse` | — | Stores the final reply text for the following `stop` (Cursor's `stop` doesn't include it). |
| `stop` | `Stop` | `Stop` | `AfterAgent` | `stop` (`loop_limit: 1`) | `agentStop` | Mid-session capture (section 5). |

Chronicle never registers `SubagentStop`. When the `decision-logger` subagent finishes, nothing is judged.

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

## 5. Mid-session capture in detail

This runs at the end of every turn (`stop` event). The steps run in this order, and any step can end the run with "allow", which means the agent stops normally:

1. **Disabled?** If `capture.midSession` is `false`, allow.
2. **Harness loop flag** (guard 2). If `stop_hook_active` is true (Claude Code, Codex), or on Cursor `loop_count` > 0 or `status` isn't `completed` (aborted or errored turn), allow.
3. **Record this stop.** Chronicle saves the time of this stop and keeps the previous one.
4. **One block per turn** (guard 3). If Chronicle already blocked in this turn, allow.
5. **ADR already written** (guard 4). If an ADR file was written since the previous stop, Chronicle moves the transcript offset to the end and allows. Logged as `skip-adr-written`. This covers turns where a plan was just captured, where the agent recorded a decision on its own, and where a background `decision-logger` reports back in a new turn.
6. **Build the window.** Chronicle reads the transcript from the stored offset (the point of the last verdict) to the end, as `USER:` / `ASSISTANT:` lines. It appends the final reply if the transcript doesn't contain it yet, and keeps the last 16,000 characters. With no transcript it uses the final reply alone. If the window is empty, allow.
7. **Seen before?** If a hash of the reply (or the window) was already judged in this session, allow.
8. **Prefilter.** Chronicle matches the window against a case-insensitive regex. The defaults include phrases like *let's go with / use / pick / switch*, *we'll use / adopt*, *decided*, *going with*, *trade-off*, *instead of*, *rather than*, *in favor of*, *switch to / from*, *migrate to / from*, *replace X with*, *adopt*, *drop X for*, *architecture*, *ADR*, and your `prefilterKeywords` are added. On no match: allow, logged as `prefilter-miss`. **Most turns end here and cost nothing.**
9. **Judge.** With `judge.via: "cli"` (the default), Chronicle runs the judge under a lock (section 6). Then it records the hash as seen and moves the offset to the end, so the next window starts after this point.
10. **Judge unavailable** (CLI missing, not logged in, timeout, unparseable answer, or `judge.via: "self"`). Logged as `judge-unavailable`, then `judge.fallback` decides:
    - `self` (default): the agent continues once with "if this turn finalized a decision that isn't recorded, record it; otherwise stop without comment". In nudge mode, on Gemini, or past the block cap, you get a hint instead.
    - `nudge`: a hint only.
    - `off`: nothing.
11. **Verdict.** Logged as `judged` with the decision list. Titles already flagged in this session are removed (guard 5, case-insensitive). If nothing is left, allow.
12. **Act.** Chronicle marks this turn as blocked and counts the block. Past `capture.maxBlocksPerSession` (default 5), it switches to nudge mode (guard 6). Then:
    - **auto** (Claude Code, Codex, Cursor, Copilot): the agent continues with the list of decisions and their status (Accepted if final, otherwise Proposed). It's told to record each one with `decision-logger` or the skill, report the paths, and stop.
    - **nudge**, or **Gemini**: you see the list as a hint. The decisions are stored as *undelivered* and handed to the agent at the next point where a hook can add context. On Claude Code, Codex and Gemini that's your next prompt or the next tool result, whichever comes first. On Cursor and Copilot it's the next tool result. Each is delivered exactly once. Undelivered decisions left at the end of a session come back as a session-start reminder.

**Cost per user message:** at most one judge call and at most one extra agent turn. Usually zero of both.

## 6. The judge

The judge is a single non-interactive call to your agent's own CLI:

| Agent | Command |
|---|---|
| Claude Code | `claude -p --model haiku --output-format json --tools "" --no-session-persistence --settings '{"disableAllHooks":true}'` |
| Codex | `codex exec -s read-only --ephemeral --skip-git-repo-check -c features.hooks=false [-m <model>] -` |
| Gemini CLI | `gemini --output-format json [-m <model>] -p <prompt>` |
| Cursor | `agent -p --mode ask --output-format json [--model <model>] <prompt>` |
| Copilot | `copilot -s --no-custom-instructions --no-ask-user [--model <model>] -p <prompt>` |

- **Model:** `judge.model`. If unset, Claude Code uses `haiku` and the other agents use their CLI's default. Set a small model there.
- **Environment:** an empty temporary directory as the working directory (so no project hooks or instructions load), `CHRONICLE_JUDGE=1`, and a timeout of `judge.timeoutSec` (default 20 s). The timeout uses `timeout` where it's installed, otherwise a shell watchdog that ends the judge and its child processes (on macOS, for example). The temporary directory is deleted afterwards.
- **Input:** the judge prompt, the titles of up to 60 existing ADRs, and the conversation window.
- **Expected output:** `{"decisions":[{"title":"<noun phrase>","final":true|false}]}`. Chronicle accepts the answer wrapped in the CLI's JSON envelope or surrounded by text. Titles are cut to 120 characters.
- **What counts as a decision:** a *settled* choice between alternatives, adopting, replacing or dropping a dependency, a change to data flow, boundaries, storage, deployment or security, or a new convention. It doesn't count options listed without a choice, routine implementation, decisions already covered by an existing ADR, or text that only reports that an ADR was written.
- **`final`** is true when the user agreed or the decision is being implemented. It becomes the ADR status: Accepted if final, otherwise Proposed.
- **Override for testing:** `CHRONICLE_JUDGE_CMD="<shell command>"` replaces the CLI. The prompt arrives on stdin.

## 7. Loop safety

Two kinds of loops are possible with end-of-turn hooks:

- **Continue loop:** the hook makes the agent continue, the continuation ends in another stop, and the hook fires again.
- **Fork loop:** the judge is itself an agent session that can load the same hooks and start another judge.

Chronicle has six guards. Each one is enough for the case it covers, and each one is tested on its own with the others switched off.

| # | Guard | Where | Stops |
|---|---|---|---|
| 1 | `CHRONICLE_JUDGE=1` → the engine exits before doing anything. The judge also runs in an empty temp directory, with hooks disabled where the CLI allows it, and under a lock (`.chronicle/state/judge.lock`, cleared after 60 s if stale). | engine entry, `run_judge` | fork loops; parallel judges |
| 2 | The agent's own flag: `stop_hook_active` (Claude Code, Codex), `loop_count` with `loop_limit: 1` (Cursor) | step 2 | continue loops, as far as the agent tracks them |
| 3 | At most one block per user turn, using Chronicle's own turn counter | step 4 | continue loops, even if the agent's flag is missing or resets |
| 4 | Skip if an ADR was written since the previous stop | step 5 | re-judging the turn that recorded the decision, or the turn in which a background `decision-logger` reports back |
| 5 | Never flag the same title twice per session | step 11 | repeated reminders when the agent ignores one |
| 6 | At most `capture.maxBlocksPerSession` blocks per session (default 5), then hints only | step 12 | any remaining runaway case |

Two more properties help:

- Chronicle never hooks `SubagentStop`.
- Every reminder text tells the agent to stop after reporting the ADR paths.

## 8. What the agent is told

Chronicle talks to the agent in exactly these situations. The wording is in the engine.

| Situation | Channel | Interrupts the turn? |
|---|---|---|
| Plan promoted | added context on the tool result | no |
| Decisions found, auto mode | continue / follow-up message | yes, one extra turn |
| Judge unavailable, `self` fallback | continue / follow-up message ("record it if real, otherwise stop without comment") | yes, one extra turn |
| Decisions found, nudge mode or Gemini | hint shown to *you* (`systemMessage`) | no |
| Deferred reminder | added context on the next prompt (Claude Code, Codex, Gemini) or the next tool result (all) | no |
| Leftovers from earlier sessions | added context at session start | no |

Cursor's and Copilot's end-of-turn hooks have no field for a message to you, so in nudge mode you see no hint there. The agent still gets the reminder with its next tool result.

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
   - records the time in `.chronicle/state/last-adr`, which guard 4 reads.
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
| `.chronicle/state/<session>/turn`, `turn-start` | Turn counter and turn start time |
| `…/last-stop`, `offset` | Previous stop time; transcript line where the next window starts |
| `…/seen` | Hashes of judged replies |
| `…/blocked`, `blocks` | Turn of the last block; block count in this session |
| `…/flagged.json` | Decisions flagged in this session, with a delivered flag |
| `…/pending-plan.json` | Plan waiting for promotion |
| `…/last-reply` | Cursor only: the last reply text |

Session folders are deleted after 7 days. You can delete `.chronicle/` at any time. Chronicle then forgets which decisions it already flagged.

## 11. The activity log

Each line of `.chronicle/log.jsonl` has `ts`, `harness`, `event`, `session` and `action`:

| `action` | Meaning |
|---|---|
| `plan-pending` | A plan was stored as pending |
| `plan-promoted` | A plan was promoted; `archive` holds its path |
| `prefilter-miss` | Turn ended, no decision language, no judge call |
| `judged` | The judge ran; `decisions` holds its answer (before title dedupe) |
| `judge-unavailable` | The judge couldn't be used; `via` and `fallback` say what happened instead |
| `skip-adr-written` | Turn skipped because an ADR was written since the previous stop |
| `deferred-delivery` | Stored decisions were delivered; `via` is `prompt` or `post-tool` |

Turns that end at guards 2–3 or the seen-hash check aren't logged. `/chronicle-status` summarizes the log. For a bug report, the relevant lines are usually enough.

## 12. Failure behavior

- **Any internal error** (missing `jq`, unreadable state, malformed input, a crash): the engine prints `{}`, which means "allow", and exits 0. Chronicle can fail to capture, but it can't block or break your agent.
- **Judge failure:** handled by `judge.fallback` (section 5, step 10).
- **Hook timeout:** the stop hook is registered with a 60 s timeout and all other hooks with 10 s. The judge's own timeout (20 s by default) keeps the stop hook well inside its limit.
- **Malformed `.chronicle.json`:** the hooks fall back to built-in defaults. `chronicle-adr` itself stops with "invalid JSON in .chronicle.json", so the agent will report it when it tries to write an ADR.
- **Platforms:** the scripts need bash 3.2 or later, `jq` and standard Unix tools. They run on Linux, macOS and WSL, but not in agents running natively on Windows. Only Linux has been tested.
- **Version 1 config** (`stopHook` keys): migrated in memory when read. The file isn't rewritten.

## 13. Per-agent differences

| | Claude Code | Codex | Gemini CLI | Cursor | Copilot |
|---|---|---|---|---|---|
| Where the reply text comes from | `last_assistant_message` | `last_assistant_message`, otherwise the transcript | `prompt_response` | `afterAgentResponse.text`, stored for `stop` | transcript (`transcriptPath`) |
| Transcript for the window | yes | yes (rollout file) | no, reply only | no, reply only | yes |
| How the agent is made to continue | `decision: block` | `decision: block` | never: hint plus deferred delivery | `followup_message` | `decision: block` |
| Plan events | pre and post `ExitPlanMode` | none | `BeforeTool` / `AfterTool(exit_plan_mode)` | none | `pre`/`postToolUse` (unverified) |
| Plan promotion | approval or first edit | — | first write (`AfterTool` doesn't prove approval) | — | first edit |
| Deferred reminders arrive | next prompt or tool result | next prompt or tool result | next prompt or tool result | next tool result | next tool result |
| Loop flag | `stop_hook_active` | `stop_hook_active` | — (never blocks) | `loop_count`, `loop_limit: 1` | `stop_hook_active` / `stopHookActive`; Copilot also stops after 8 blocks |
| Hook commands | absolute (`${CLAUDE_PROJECT_DIR}`) | relative to repo root | relative | relative | relative |

Gemini never gets a `deny` from Chronicle. In Gemini, `deny` on `AfterAgent` throws the reply away and makes the agent retry, which costs you the answer you were reading.

## 14. What Chronicle does not capture

- Decisions made outside an agent session (meetings, chat, code written by hand). Use `/log-decision`.
- Decisions the agent makes silently in code without saying so. The git guard is the safety net here.
- Decisions phrased without any of the keywords. Add phrases to `prefilterKeywords`, or run `/chronicle-review`.
- Decisions the judge misses or rejects. The judge is a small model and errs on the side of fewer ADRs.
- In OpenCode, nothing automatically. It relies on the rule, `/log-decision` and `/chronicle-review`. Copilot in VS Code most likely runs Chronicle's Copilot hooks (VS Code agent hooks, preview), but this is untested.
- Plans in Codex and Cursor as plans. Their decisions can still be caught by the end-of-turn judge, but the plan isn't archived.

## 15. Privacy and data flow

- Chronicle has no server, no account and no telemetry.
- The only data that leaves your machine is the **judge call**: the conversation window (up to 16,000 characters) and your existing ADR titles, sent through *your* agent CLI with *your* credentials to the same provider your agent already uses. It only happens on turns that pass the prefilter. To avoid it, set `"judge": {"via": "self"}` (the main agent checks itself) or `"capture": {"midSession": false}`.
- `.chronicle/log.jsonl` contains decision titles. It stays local and is gitignored.
- The hooks run shell scripts from the package with your user's permissions. Review them before you install, as with any package that ships hooks. See [SECURITY.md](../SECURITY.md).
