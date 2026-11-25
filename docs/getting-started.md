# Getting started

1. **Install APM** (once per machine): `pip install apm-cli`, or use `uvx --from apm-cli apm …` without installing.
2. **Add Chronicle** from your project root:
   ```bash
   apm install architraceio/chronicle
   ```
   Codex users: trust the hooks in `/hooks`. Gemini users: accept the trust prompt.
3. **Check it**: run `/chronicle-status` in your agent. It shows the config and offers to create `.chronicle.json` with the template you prefer.
4. **Try it.** Ask your agent, in plan mode where available:
   > *Plan how this project should handle configuration. Compare environment variables vs. a YAML file. Pick one and explain the trade-offs.*

   Approve the plan, or just say "go ahead". Chronicle archives the plan to `docs/decisions/_plans/` and the agent writes an ADR such as `docs/decisions/0001-configuration-via-environment-variables.md`.
5. **Mid-session**: settle something in chat ("let's go with SQLite instead of Redis for the cache"). Before the turn ends, the agent records it.
6. **Commit** the ADRs with the code they explain. Run `/chronicle-review` at the end of longer sessions.

Not every agent supports every capture path; see the [support matrix](harnesses.md).
