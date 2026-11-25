# Chronicle

> **Decisions that don't disappear.**

Chronicle captures the architectural and design decisions you make with an AI coding agent and writes them as ADR markdown files into your repository, while you work. Local-first, no account, no telemetry. Sponsored by [architrace](https://architrace.io).

It is distributed as an [APM](https://github.com/microsoft/apm) package and works with Claude Code, Codex, Gemini CLI, Cursor, GitHub Copilot and OpenCode, each as far as the agent allows (see [Supported agents](#supported-agents)).

## What it does

- **Plans become ADRs.** When a plan is approved, or when you start implementing a plan you discussed (even if you skipped the approval dialog), Chronicle archives the plan and has the agent write **one ADR per decision** in it.
- **Decisions made in conversation are caught.** At the end of each turn a free keyword filter checks for decision language. Only on a match does a cheap judge model (your agent's own CLI, e.g. `claude -p --model haiku`) confirm. If it finds an unrecorded decision, the agent records it before stopping.
- **Manual capture is always available.** `/log-decision` records a decision, `/chronicle-review` sweeps the conversation for unrecorded ones, `/chronicle-status` shows what Chronicle has been doing.
- **Deterministic bookkeeping.** Numbering, file names, templates, status changes and the index are handled by a script, not left to the model.
- **Loop-safe by design.** Six independent guards make sure a hook can never trap the agent in a loop or spawn recursive judge runs. The worst case per user message is one judge call and one extra turn.

## Supported agents

What happens automatically depends on what each agent lets hooks do:

| | Claude Code | Codex | Gemini CLI | Cursor | Copilot CLI | Copilot in VS Code | OpenCode |
|---|---|---|---|---|---|---|---|
| Plans turn into ADRs | ✅ | 📝 | ✅ | 📝 | ⚠️ | 📝 | 📝 |
| Decisions made in chat are recorded | ✅ | ✅ | ✅ ¹ | ✅ | ✅ | ⚠️ ³ | 📝 |
| `/log-decision`, `/chronicle-review` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| One-time setup | none | trust hooks in `/hooks`, add the rule ² | accept trust prompt | none | none | none | add the rule ² |

✅ automatic · 📝 the agent is instructed to do it (usually works, not guaranteed), plus the manual commands · ⚠️ expected to work, not tested yet · ¹ Gemini shows you a hint right away and the agent records it at its next step · ² Chronicle's rule has to be added to `AGENTS.md` once: [how](docs/getting-started.md#add-the-chronicle-rule-to-agentsmd-codex-opencode) · ³ VS Code agent hooks are in preview and read Chronicle's Copilot hooks; [not tested yet](docs/harnesses.md#github-copilot)

Only Claude Code has been tested end to end with a live agent so far. Details per agent: [agent support](docs/harnesses.md).

## Requirements

- [APM](https://github.com/microsoft/apm) ≥ 0.38 (`pip install apm-cli`, or run it via `uvx --from apm-cli apm`)
- `bash` (3.2 or later), `jq`, `git`
- Linux, macOS or Windows with WSL. The hooks are bash scripts, so agents running natively on Windows can't run them; the skills and manual commands still work there. Tested on Linux so far.
- One or more supported agents

## Install

From the root of your project:

```bash
apm install architraceio/chronicle
```

APM detects which agents you use and deploys the matching files. To pick explicitly: `apm install architraceio/chronicle --target claude,codex`. Commit `apm.yml` and `apm.lock.yaml` so your team gets the same version with a plain `apm install`.

One-time extra steps for some agents:

| Agent | Step |
|---|---|
| Codex | Trust the Chronicle hooks in `/hooks` (again after each update). |
| Gemini CLI | Accept the hook trust prompt. |
| Codex, OpenCode | Add Chronicle's rule to `AGENTS.md` with `apm compile`. If you already have an `AGENTS.md`, it needs a marked section first: see [Add the Chronicle rule to AGENTS.md](docs/getting-started.md#add-the-chronicle-rule-to-agentsmd-codex-opencode). |
| Any, with APM's executables gate on | `apm approve architraceio/chronicle` |

Optional: run `/chronicle-status` once. It shows the config, offers to create `.chronicle.json`, and lets you pick a template.

## Usage

Mostly: none. Work as usual.

- Approve a plan (or say "go ahead" and start implementing) → ADRs appear in `docs/decisions/`, the plan in `docs/decisions/_plans/`.
- Settle something in conversation ("let's go with SQLite instead of Redis") → the agent records it before ending the turn.
- `/log-decision [what you decided]` → record something by hand.
- `/chronicle-review` → at the end of a session, find decisions that slipped through.
- Review the ADRs in your diff like any other file, edit the prose, commit them with the code they explain.

Optional git safety net, independent of any agent:

```bash
bash .agents/skills/chronicle-adr/scripts/chronicle-adr guard install
```

This warns when a commit changes dependency manifests, Dockerfiles, IaC or CI config without adding an ADR (set `"guard": {"mode": "block"}` to enforce).

## What you get

```
docs/decisions/
  0001-postgres-for-primary-store.md   one ADR per decision (template of your choice)
  0002-sqlite-for-local-cache.md
  README.md                            generated index: number, title, status, date
  _plans/20261125T093815Z-cache-layer.md   approved plans, verbatim, linked from their ADRs
.chronicle.json                        config (optional, defaults apply)
.chronicle/                            local state and activity log (self-gitignored)
```

See [`examples/decisions/`](examples/decisions/) for well-formed ADRs.

## Configuration

`.chronicle.json` (all keys optional):

```json
{
  "version": 2,
  "decisionsDir": "docs/decisions",
  "template": "adr-nygard",
  "archivePlans": true,
  "capture": { "planAccept": true, "midSession": true, "mode": "auto", "maxBlocksPerSession": 5 },
  "judge": { "via": "cli", "model": null, "fallback": "self", "timeoutSec": 20 },
  "prefilterKeywords": [],
  "guard": { "mode": "warn" }
}
```

Details in [docs/customization.md](docs/customization.md). Templates: `adr-nygard` (default), `adr-extended` (frontmatter, alternatives, rationale), `adr-lightweight`.

## Update and uninstall

```bash
apm update architraceio/chronicle
apm uninstall architraceio/chronicle
```

Uninstall removes Chronicle's hooks, scripts, skills, agents and commands, and leaves your other hooks untouched. It doesn't touch `AGENTS.md`: delete the Chronicle text from it yourself (see [above](docs/getting-started.md#add-the-chronicle-rule-to-agentsmd-codex-opencode)). Your ADRs, plans and `.chronicle.json` stay: they are your records.

## Documentation

- [Getting started](docs/getting-started.md)
- [How it works](docs/how-it-works.md): capture flows, judge, loop safety
- [Agent support in detail](docs/harnesses.md): full matrix, workarounds, per-agent notes
- [Behavior reference](docs/behavior.md): every event, guard, message, file and log entry
- [Customization](docs/customization.md)
- [Why ADRs](docs/why-adrs.md)
- [Scaling up](docs/scaling-up.md)

## Contributing

PRs welcome. `make all` syncs the shared hook engine into each package, lints and runs the unit tests; `make test-apm` installs the package into a fixture project with APM. See [CONTRIBUTING.md](CONTRIBUTING.md), [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) and [SECURITY.md](SECURITY.md). Released under the [MIT license](LICENSE).
