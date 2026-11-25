# How it works

Chronicle has three parts:

- **`chronicle-adr`** (in the `chronicle-adr` skill): a bash script that owns numbering, file names, templates, status changes, the index and the git guard. The model only writes prose.
- **`chronicle-hook`**: one hook engine shared by all agents. Each agent's hook package calls it with `--harness <name>`, and it translates that agent's hook payloads and outputs.
- **Skills, agent, rule**: `chronicle-adr` (procedure and quality bar), `log-decision`, `chronicle-review`, `chronicle-status`, the `decision-logger` subagent, and a short instruction.

## Plan capture

1. **Proposed.** When the agent presents a plan (`PreToolUse(ExitPlanMode)` in Claude Code, `BeforeTool(exit_plan_mode)` in Gemini), Chronicle stores it as *pending*. This also happens when you reject the dialog.
2. **Promoted**, whichever comes first:
   - the plan is approved (`PostToolUse(ExitPlanMode)`), or
   - the first file edit inside the project while a plan is pending, i.e. you started implementing some other way (Esc → question → "go ahead"), or
   - `/log-decision` with no arguments.
3. **On promotion** Chronicle re-reads the plan file, so later revisions count, and archives it to `<decisionsDir>/_plans/`. It then tells the agent to record **one ADR per decision** in the plan, Status Accepted, linked to the archive. This is extra context; it doesn't interrupt the turn.
4. A plan that is never implemented produces no ADR. You get a reminder at the next session start.

## Mid-session capture

At the end of every turn (`Stop`, `AfterAgent`, `stop`, `agentStop`):

1. **Guards** run first (see below).
2. **Window.** The conversation since the last verdict, from the transcript where available (user messages included), plus the final reply, up to 16k characters.
3. **Prefilter.** A case-insensitive keyword regex ("let's go with", "instead of", "trade-off", "decided", …, plus your `prefilterKeywords`). No match → done. This costs nothing and is what happens on most turns.
4. **Judge.** Your agent's CLI with a small model, run in an empty temp directory with `CHRONICLE_JUDGE=1` and hooks disabled where possible. It returns `{"decisions":[{"title","final"}]}` and ignores decisions already in your ADR list.
5. **Result.** If there are new decisions, the agent is asked to record them now: Status Accepted if final, otherwise Proposed. On Gemini, or with `capture.mode: "nudge"`, you get a hint, and the agent gets the reminder at the next tool call or prompt.

Everything Chronicle does is logged to `.chronicle/log.jsonl`. `/chronicle-status` summarizes it.

## Loop safety

A blocking end-of-turn hook makes the agent continue, and the continuation ends in another stop. A judge that is itself an agent session can trigger the same hooks. Chronicle guards against each of these separately:

| # | Guard | Prevents |
|---|---|---|
| 1 | `CHRONICLE_JUDGE=1` makes the engine exit immediately; the judge also runs outside the project with hooks disabled, under a single-judge lock | the judge's own session triggering a judge (fork bomb) |
| 2 | the harness flag (`stop_hook_active`, Cursor `loop_count`/`loop_limit: 1`) | block → continue → block |
| 3 | at most one block per user turn (own turn counter) | the same, independent of the harness flag |
| 4 | skip if an ADR was written since the previous stop | double capture after a plan, and re-judging after a background `decision-logger` reports back |
| 5 | never flag the same decision title twice per session | repeated reminders if the agent ignores one |
| 6 | at most `capture.maxBlocksPerSession` blocks (default 5), then hints only | any remaining runaway case |

Any internal error in the engine results in "allow": Chronicle can fail, but it can't wedge your agent.

## Bookkeeping

`chronicle-adr new --title … --status …` allocates the next 4-digit number, slugifies the title, refuses duplicates, fills the template and prints the path. `supersede N --by M` is the only edit ever made to an existing ADR. `index` regenerates `docs/decisions/README.md`. `guard` checks commits for decision-heavy changes without an ADR.
