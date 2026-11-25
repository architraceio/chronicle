# Chronicle documentation

Chronicle captures architectural and design decisions made with AI coding agents as ADR markdown files in your repository. Local-first, no account, no telemetry.

```bash
apm install architraceio/chronicle
```

Approve or implement a plan, or settle a decision in conversation, and ADRs appear in `docs/decisions/`. Use `/log-decision` and `/chronicle-review` any time.

## Supported agents

| | Claude Code | Codex | Gemini CLI | Cursor | Copilot CLI | Copilot in VS Code | OpenCode |
|---|---|---|---|---|---|---|---|
| Plans turn into ADRs | ✅ | 📝 | ✅ | 📝 | ⚠️ | 📝 | 📝 |
| Decisions made in chat are recorded | ✅ | ✅ | ✅ ¹ | ✅ | ✅ | ⚠️ ³ | 📝 |
| `/log-decision`, `/chronicle-review` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| One-time setup | none | trust hooks in `/hooks`, add the rule ² | accept trust prompt | none | none | none | add the rule ² |

✅ automatic · 📝 the agent is instructed to do it (usually works, not guaranteed), plus the manual commands · ⚠️ expected to work, not tested yet · ¹ Gemini shows you a hint right away and the agent records it at its next step · ² Chronicle's rule has to be added to `AGENTS.md` once: [how](getting-started.md#add-the-chronicle-rule-to-agentsmd-codex-opencode) · ³ VS Code agent hooks are in preview and read Chronicle's Copilot hooks; [not tested yet](harnesses.md#github-copilot)

Only Claude Code has been tested end to end with a live agent so far. Details per agent: [agent support](harnesses.md).


## Contents

- [Getting started](getting-started.md)
- [How it works](how-it-works.md)
- [Agent support in detail](harnesses.md)
- [Behavior reference](behavior.md): in-depth, event by event
- [Customization](customization.md)
- [Why ADRs](why-adrs.md)
- [Scaling up](scaling-up.md)
