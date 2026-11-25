# Getting started

1. **Install APM** (once per machine): `pip install apm-cli`, or use `uvx --from apm-cli apm …` without installing.
2. **Add Chronicle** from your project root:
   ```bash
   apm install architraceio/chronicle
   ```
   Codex users: trust the hooks in `/hooks`. Gemini users: accept the trust prompt. Codex and OpenCode users: add the Chronicle rule to `AGENTS.md` ([below](#add-the-chronicle-rule-to-agentsmd-codex-opencode)).
3. **Check it**: run `/chronicle-status` in your agent. It shows the config and offers to create `.chronicle.json` with the template you prefer.
4. **Try it.** Ask your agent, in plan mode where available:
   > *Plan how this project should handle configuration. Compare environment variables vs. a YAML file. Pick one and explain the trade-offs.*

   Approve the plan, or just say "go ahead". Chronicle archives the plan to `docs/decisions/_plans/` and the agent writes an ADR such as `docs/decisions/0001-configuration-via-environment-variables.md`.
5. **Mid-session**: settle something in chat ("let's go with SQLite instead of Redis for the cache"). Before the turn ends, the agent records it.
6. **Commit** the ADRs with the code they explain. Run `/chronicle-review` at the end of longer sessions.

## What to expect in your agent

| | Claude Code | Codex | Gemini CLI | Cursor | Copilot CLI | Copilot in VS Code | OpenCode |
|---|---|---|---|---|---|---|---|
| Plans turn into ADRs | ✅ | 📝 | ✅ | 📝 | ⚠️ | 📝 | 📝 |
| Decisions made in chat are recorded | ✅ | ✅ | ✅ ¹ | ✅ | ✅ | ⚠️ ³ | 📝 |
| `/log-decision`, `/chronicle-review` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| One-time setup | none | trust hooks in `/hooks`, add the rule ² | accept trust prompt | none | none | none | add the rule ² |

✅ automatic · 📝 the agent is instructed to do it (usually works, not guaranteed), plus the manual commands · ⚠️ expected to work, not tested yet · ¹ Gemini shows you a hint right away and the agent records it at its next step · ² Chronicle's rule has to be added to `AGENTS.md` once: [how](#add-the-chronicle-rule-to-agentsmd-codex-opencode) · ³ VS Code agent hooks are in preview and read Chronicle's Copilot hooks; [not tested yet](harnesses.md#github-copilot)

Only Claude Code has been tested end to end with a live agent so far. Details per agent: [agent support](harnesses.md).

## Add the Chronicle rule to AGENTS.md (Codex, OpenCode)

Chronicle ships a short rule: "record finalized decisions before ending the turn; when implementing an approved plan, record its decisions first". Codex and OpenCode only read it from `AGENTS.md`. For OpenCode it's the main way capture happens without you asking, and for Codex it covers plans.

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

**Other agents** need no setup for the rule:

- Claude Code, Cursor and Copilot get it at install: `.claude/rules/chronicle.md`, `.cursor/rules/chronicle.mdc`, `.github/instructions/chronicle.instructions.md`.
- Gemini CLI reads `GEMINI.md`. Its hooks already cover capture, so the rule is optional there. If you want it, compile `AGENTS.md` as above. If you have no `GEMINI.md`, `apm compile` writes one that imports `AGENTS.md`. If you have your own, add the line `@./AGENTS.md` to it.

Want to know exactly what happens on each event? See the [behavior reference](behavior.md).
