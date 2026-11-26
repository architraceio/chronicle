# Getting started

1. **Install APM** (once per machine): `pip install apm-cli`, or use `uvx --from apm-cli apm …` without installing.
2. **Add Chronicle** from your project root:
   ```bash
   apm install architraceio/chronicle
   ```
   Codex, Gemini CLI and OpenCode users: add the Chronicle rule to `AGENTS.md` ([below](#add-the-chronicle-rule-to-agentsmd-codex-gemini-cli-opencode)). Gemini users: also accept the hook trust prompt.
3. **Check it**: run `/chronicle-status` in your agent. It shows the config and offers to create `.chronicle.json` with the template you prefer.
4. **Try it.** Ask your agent, in plan mode where available:
   > *Plan how this project should handle configuration. Compare environment variables vs. a YAML file. Pick one and explain the trade-offs.*

   Approve the plan, or just say "go ahead". Chronicle archives the plan to `docs/decisions/_plans/` and the agent writes an ADR such as `docs/decisions/0001-configuration-via-environment-variables.md`.
5. **Mid-session**: settle something in chat ("let's go with SQLite instead of Redis for the cache"). The agent records it in the same turn, because Chronicle's rule tells it to.
6. **Commit** the ADRs with the code they explain. Run `/chronicle-review` at the end of longer sessions.

## What to expect in your agent

| | Claude Code | Codex | Gemini CLI | Cursor | Copilot CLI | Copilot in VS Code | OpenCode |
|---|---|---|---|---|---|---|---|
| Plans turn into ADRs | ✅ | 📝 | ✅ | 📝 | ⚠️ | 📝 | 📝 |
| Decisions made in chat are recorded | 📝 | 📝 ² | 📝 ² | 📝 | 📝 | 📝 | 📝 ² |
| `/log-decision`, `/chronicle-review` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Optional audit of missed decisions | ✅ | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ⚠️ ³ | — |
| One-time setup | none | add the rule ² | add the rule ², accept the hook trust prompt | none | none | none | add the rule ² |

✅ automatic, by a hook · 📝 the agent does it because Chronicle's rule tells it to (seen working in a live Claude Code session, not guaranteed); `/chronicle-review` catches what slipped through · ⚠️ expected to work, not tested yet · ² Chronicle's rule has to be added to `AGENTS.md` once: [how](#add-the-chronicle-rule-to-agentsmd-codex-gemini-cli-opencode) · ³ VS Code agent hooks are in preview and read Chronicle's Copilot hooks; [not tested yet](H#github-copilot)

Only Claude Code has been tested end to end with a live agent so far. Details per agent: [agent support](harnesses.md).

## Add the Chronicle rule to AGENTS.md (Codex, Gemini CLI, OpenCode)

Chronicle ships a short rule: "record each settled design decision in the same turn; when implementing an approved plan, record its decisions first". It is how decisions get recorded without you asking, on every agent. Codex and OpenCode only read it from `AGENTS.md`, and Gemini CLI reads it through `GEMINI.md`. Without this step these agents don't know about Chronicle unless you run `/log-decision` or `/chronicle-review`.

`apm install` never writes to `AGENTS.md`. `apm compile` does, and how depends on whether you already have one.

**You have no `AGENTS.md`.** Run:

```bash
apm compile
```

APM creates `AGENTS.md` and owns all of it. Each later `apm compile` regenerates the whole file and **overwrites anything you wrote in it**. If you want to keep your own instructions in `AGENTS.md`, set it up as in the next case instead.

**You have an `AGENTS.md`, or want to write in it yourself.** By default `apm compile` won't touch a hand-written `AGENTS.md`. It prints `Protected AGENTS.md: hand-authored file will not be overwritten` and does nothing. To give APM one section of the file:

1. Add this to your project's `apm.yml`:
   ```yaml
   compilation:
     agents_md:
       mode: managed_section
   ```
2. Add the two markers to `AGENTS.md` where the generated text should go:
   ```markdown
   <!-- apm:start -->
   <!-- apm:end -->
   ```
3. Run `apm compile`. APM fills in the text between the markers and leaves everything else in the file alone.

If you do step 1 without step 2, `apm compile` stops with `Managed-section markers not found in the target file`. You can choose other markers with `start_marker` / `end_marker` next to `mode`. Commit `apm.yml` and `AGENTS.md` so your team gets the same setup.

**When to compile again.** After `apm update` (the rule may change), and after installing or removing other APM packages that ship instructions.

**Uninstalling.** `apm uninstall` doesn't change `AGENTS.md`, and a later `apm compile` with nothing to compile writes nothing. Delete Chronicle's text yourself: the "Architectural decisions (Chronicle)" section between the markers, or the whole file if APM generated it.

**Gemini CLI** reads `GEMINI.md`. Compile `AGENTS.md` as above. If you have no `GEMINI.md`, `apm compile` writes one that imports `AGENTS.md`. If you have your own, add the line `@./AGENTS.md` to it.

**Claude Code, Cursor and Copilot** need no setup: they get the rule at install, in `.claude/rules/chronicle.md`, `.cursor/rules/chronicle.mdc` and `.github/instructions/chronicle.instructions.md`.

`/chronicle-status` checks whether your agent can see the rule.

## Audit mode (optional)

To find out how often the agent misses a decision, set this in `.chronicle.json`:

```json
{ "judge": { "mode": "audit" } }
```

At the end of every turn, a cheap model checks your last message and the agent's reply, through your agent's own CLI (`claude -p --model haiku` for Claude Code; set `judge.model` for the others, which otherwise use their default model). It logs the decisions it sees and whether an ADR was written. It never interrupts or messages the agent. Run `/chronicle-status` to see possible misses and record them. Each audited turn costs one small model call and adds a few seconds before the turn ends.

Want to know exactly what happens on each event? See the [behavior reference](behavior.md).
