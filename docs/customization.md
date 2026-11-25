# Customization

Everything is configured in `.chronicle.json` at the project root. All keys are optional; `chronicle-adr config` prints the effective configuration. Version 1 files (with `stopHook`) are migrated automatically when read.

```json
{
  "version": 2,
  "decisionsDir": "docs/decisions",
  "template": "adr-nygard",
  "archivePlans": true,
  "capture": { "planAccept": true, "midSession": true, "mode": "auto", "maxBlocksPerSession": 5 },
  "judge": { "via": "cli", "model": null, "fallback": "self", "timeoutSec": 20 },
  "prefilterKeywords": [],
  "guard": { "mode": "warn", "paths": ["package.json", "go.mod", "Dockerfile*", "*.tf", "..."] }
}
```

| Key | Values | Meaning |
|---|---|---|
| `decisionsDir` | path | Where ADRs, `_plans/` and the index go. |
| `template` | `adr-nygard`, `adr-extended`, `adr-lightweight`, or a path such as `./docs/my-adr-template.md` | Template for new ADRs. Custom templates may use `{number}`, `{title}`, `{ISO date}`, `{uuid}` and the status placeholder `{Proposed \| Accepted \| Deprecated \| Superseded by ADR-XXXX}`. |
| `archivePlans` | bool | Keep approved plans verbatim in `_plans/`. |
| `capture.planAccept` | bool | Turn plans into ADRs. |
| `capture.midSession` | bool | Run the end-of-turn filter and judge. |
| `capture.mode` | `auto`, `nudge` | `auto`: the agent records the decision before stopping. `nudge`: you get a hint (not in Cursor and Copilot, which have no channel for it), and the agent gets a reminder on the next prompt or tool result. |
| `capture.maxBlocksPerSession` | int | Hard cap on how often Chronicle may make the agent continue in one session. |
| `judge.via` | `cli`, `self` | `cli`: a cheap model through your agent's CLI. `self`: no extra call; the main agent checks itself on a keyword match. |
| `judge.model` | model id or `null` | `null` = `haiku` for Claude Code, the CLI default elsewhere. Set a small model for Codex, Gemini, Cursor and Copilot. |
| `judge.fallback` | `self`, `nudge`, `off` | What to do when the judge CLI is unavailable. |
| `prefilterKeywords` | strings | Extra trigger phrases, matched literally and case-insensitively, added to the defaults. |
| `guard.mode` | `warn`, `block` | Behavior of `chronicle-adr guard`. |
| `guard.paths` | globs | Files that usually carry a decision. |

## Changing the ADR prose style

Edit the quality bar in the `chronicle-adr` skill (`.claude/skills/chronicle-adr/SKILL.md` or `.agents/skills/chronicle-adr/SKILL.md`). APM treats locally edited files as yours and won't overwrite them on update unless you pass `--force`. Prefer contributing changes upstream.

## Turning parts off

- No mid-session judge: `"capture": {"midSession": false}`. Plans and manual capture keep working.
- Hints only, never interrupt: `"capture": {"mode": "nudge"}`.
- One agent only: `apm install architraceio/chronicle --target claude`.
