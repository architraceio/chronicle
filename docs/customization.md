# Customization

Everything is configured in `.chronicle.json` at the project root. All keys are optional; `chronicle-adr config` prints the effective configuration. Version 1 files (with `stopHook`) are migrated automatically when read; only `stopHook.judgeModel` is carried over, as `judge.model`.

The most effective setting isn't in this file: it's the rule the agent follows. If you want it stricter or looser for your project ("record every new dependency", "don't record test tooling"), add a line to your own `AGENTS.md`, `CLAUDE.md` or rules next to Chronicle's.

```json
{
  "version": 2,
  "decisionsDir": "docs/decisions",
  "template": "adr-nygard",
  "archivePlans": true,
  "capture": { "planAccept": true },
  "judge": { "mode": "off", "model": null, "timeoutSec": 20 },
  "guard": { "mode": "warn", "paths": ["package.json", "go.mod", "Dockerfile*", "*.tf", "..."] }
}
```

| Key | Values | Meaning |
|---|---|---|
| `decisionsDir` | path | Where ADRs, `_plans/` and the index go. |
| `template` | `adr-nygard`, `adr-extended`, `adr-lightweight`, or a path such as `./docs/my-adr-template.md` | Template for new ADRs. Custom templates may use `{number}`, `{title}`, `{ISO date}`, `{uuid}` and the status placeholder `{Proposed \| Accepted \| Deprecated \| Superseded by ADR-XXXX}`. |
| `archivePlans` | bool | Keep approved plans verbatim in `_plans/`. |
| `capture.planAccept` | bool | Turn plans into ADRs. |
| `judge.mode` | `off`, `audit` | `audit`: after every turn a small model checks your last message and the agent's reply and logs decisions it sees and whether an ADR was written. It never interrupts the agent. See [audit mode](getting-started.md#audit-mode-optional). |
| `judge.model` | model id or `null` | `null` = `haiku` for Claude Code, the CLI default elsewhere. Set a small model for Codex, Gemini, Cursor and Copilot. |
| `judge.timeoutSec` | int | How long an audit judge call may take before it is stopped and logged as `audit-unavailable`. |
| `guard.mode` | `warn`, `block` | Behavior of `chronicle-adr guard`. |
| `guard.paths` | globs | Files that usually carry a decision. |

## Changing the ADR prose style

Edit the quality bar in the `chronicle-adr` skill (`.claude/skills/chronicle-adr/SKILL.md` or `.agents/skills/chronicle-adr/SKILL.md`). APM treats locally edited files as yours and won't overwrite them on update unless you pass `--force`. Prefer contributing changes upstream.

## Turning parts off

- No plan capture: `"capture": {"planAccept": false}`. The rule and manual capture keep working.
- One agent only: `apm install architraceio/chronicle --target claude`.
