# How it works

This is the overview. The [behavior reference](behavior.md) covers every event, message, state file and log entry in detail.

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

## Decisions made in conversation

The agent records them itself. The rule Chronicle installs tells it to record each settled design decision in the same turn, with the `decision-logger` subagent or the `chronicle-adr` skill. That covers a choice you state ("let's go with SQLite"), a short acceptance of the agent's proposal ("ok, do that") and choices the agent makes while implementing (a new dependency, a library, a data model). No hook is involved, so this works the same in every agent that sees the rule, including OpenCode.

Earlier designs had an end-of-turn hook with a keyword filter and a judge that made the agent continue. In live tests the agent had already started `decision-logger` before the hook ran, and the keyword filter missed most real phrasings while matching ordinary ones. So the hook no longer decides anything.

What slips through is caught by:

- `/chronicle-review`: the agent goes through the conversation, lists decisions without an ADR and records the ones you pick. Use it at the end of longer sessions.
- `chronicle-adr guard`: a git hook or CI step that warns when dependency manifests, Dockerfiles, IaC or CI config change without a new ADR.
- **Audit mode** (optional, `"judge": {"mode": "audit"}`): at the end of each turn, a small model reads your last message and the agent's reply and logs the decisions it sees and whether an ADR was written. It never messages or blocks the agent. `/chronicle-status` lists possible misses. Use it to find out how well the rule works for your agent and your way of working.

The audit judge is your agent's CLI with a small model, run in an empty temp directory with `CHRONICLE_JUDGE=1` and hooks disabled where possible, under a single-judge lock, so its own session can't run Chronicle again. It reads only text from documented hook fields (your prompt, the agent's reply), not the transcript.

Everything Chronicle does is logged to `.chronicle/log.jsonl`. `/chronicle-status` summarizes it. Any internal error in the engine results in "allow": Chronicle can fail, but it can't wedge your agent.

## Bookkeeping

`chronicle-adr new --title … --status …` allocates the next 4-digit number, slugifies the title, refuses duplicates, fills the template and prints the path. `supersede N --by M` is the only edit ever made to an existing ADR. `index` regenerates `docs/decisions/README.md`. `guard` checks commits for decision-heavy changes without an ADR.
