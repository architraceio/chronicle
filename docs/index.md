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
| Decisions made in chat are recorded | 📝 | 📝 ² | 📝 ² | 📝 | 📝 | 📝 | 📝 ² |
| `/log-decision`, `/chronicle-review` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Optional audit of missed decisions | ✅ | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ⚠️ ³ | — |
| One-time setup | none | add the rule ² | add the rule ², accept the hook trust prompt | none | none | none | add the rule ² |

✅ automatic, by a hook · 📝 the agent does it because Chronicle's rule tells it to (seen working in a live Claude Code session, not guaranteed); `/chronicle-review` catches what slipped through · ⚠️ expected to work, not tested yet · ² Chronicle's rule has to be added to `AGENTS.md` once: [how](getting-started.md#add-the-chronicle-rule-to-agentsmd-codex-gemini-cli-opencode) · ³ VS Code agent hooks are in preview and read Chronicle's Copilot hooks; [not tested yet](harnesses.md#github-copilot)

Only Claude Code has been tested end to end with a live agent so far. Details per agent: [agent support](harnesses.md).


## Contents

- [Getting started](getting-started.md)
- [How it works](how-it-works.md)
- [Agent support in detail](harnesses.md)
- [Behavior reference](behavior.md): in-depth, event by event
- [Customization](customization.md)
- [Why ADRs](why-adrs.md)
- [Scaling up](scaling-up.md)
