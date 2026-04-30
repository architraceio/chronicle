# Chronicle

> **Decisions that don't disappear.**

Chronicle is an open-source companion for AI coding agents that captures architectural and design decisions as ADR markdown files in your repository. Local-first, no account, no telemetry. Sponsored by [architrace](https://architrace.io).

---

## Features

- Auto-captures an ADR when you accept a plan in Claude Code's plan mode
- Optional mid-session detection: a cheap keyword prefilter plus an LLM judge (~$0.001/turn with Haiku)
- Manual `/log-decision` slash command in both Claude Code and OpenCode
- Three ADR templates out of the box: Nygard classic, extended, lightweight
- Every ADR is a plain markdown file committed to your repo — no account, no telemetry, no external service

## Requirements

- Claude Code (with hooks support) or OpenCode
- `bash`, `jq`, and standard POSIX tools
- A project directory (typically a git repo)

## Install

Run from the **root of the project you want to add Chronicle to**:

```bash
curl -fsSL https://raw.githubusercontent.com/architraceio/chronicle/main/install.sh | bash
```

> **Want to see what it does first?** Append `-s -- --dry-run` to preview every change without writing anything:
> ```bash
> curl -fsSL https://raw.githubusercontent.com/architraceio/chronicle/main/install.sh | bash -s -- --dry-run
> ```

Prefer to inspect the script before running it? Clone the repo into a tools directory and run the installer against your target project:

```bash
git clone https://github.com/architraceio/chronicle.git ~/.chronicle
cd ~/path/to/your-project
~/.chronicle/install.sh
```

The installer is interactive by default. For non-interactive runs, pass any of (works with `bash -s --` after the curl one-liner too):

| Flag | Description |
| --- | --- |
| `--agent claude-code\|opencode\|both` | Install for specific agent(s) |
| `--decisions-dir DIR` | Where ADRs are stored (default: `docs/decisions`) |
| `--template NAME` | `adr-nygard` (default), `adr-extended`, or `adr-lightweight` |
| `--no-stop-hook` | Disable the auto-capture Stop hook (Claude Code only) |
| `--no-delegation-rule` | Don't append the delegation rule to `CLAUDE.md` / `AGENTS.md` |
| `--dry-run` | Print changes without applying them |

## What gets installed

- `.chronicle.json` at the project root (configuration)
- `<decisions-dir>/` (default `docs/decisions/`) for ADRs and an optional `_plans/` archive
- For Claude Code:
  - `.claude/agents/decision-logger.md`
  - `.claude/hooks/chronicle-save-plan.sh`, `.claude/hooks/chronicle-prefilter.sh`
  - `.claude/commands/log-decision.md`
  - Hook entries merged into `.claude/settings.json` (existing hooks preserved)
- For OpenCode:
  - `.opencode/agent/decision-logger.md`
  - `.opencode/command/log-decision.md`
- Optional delegation rule appended to `CLAUDE.md` (Claude Code) or `AGENTS.md` (OpenCode) — see [The delegation rule](#the-delegation-rule) below for the exact text

## Verify

The installer prints a self-check before exiting. To re-verify later:

```bash
cat .chronicle.json                       # your config
ls .claude/agents/decision-logger.md      # Claude Code adapter
ls .opencode/agent/decision-logger.md     # OpenCode adapter
```

## Usage

### Claude Code

1. Run `claude` and enter plan mode (`Shift+Tab` `Shift+Tab`).
2. Accept a plan — Chronicle archives the plan and writes a new ADR to your decisions directory.
3. Run `/log-decision` any time to capture a decision manually.

If the Stop hook is enabled, Chronicle also watches the end of each turn for undocumented decisions and prompts the `decision-logger` subagent when one is detected.

### OpenCode

Run `/log-decision` to capture a decision. Auto-capture isn't available in OpenCode by design — see [docs/opencode.md](docs/opencode.md) for the rationale.

### Try it

Not sure what counts as a decision? Open Claude Code in your project, enter plan mode (`Shift+Tab` `Shift+Tab`), and paste:

> *"Plan how this project should handle configuration. Compare environment variables vs. a YAML file. Pick one and explain the trade-offs."*

Accept the plan. Chronicle archives the plan to `<decisions-dir>/_plans/` and writes a fresh ADR (e.g. `0001-config-via-env-vars.md`) to your decisions directory. See [`examples/decisions/`](examples/decisions/) for what well-formed ADRs look like.

## Configuration

Chronicle reads `.chronicle.json` from the project root:

```json
{
  "version": 1,
  "decisionsDir": "docs/decisions",
  "template": "adr-nygard",
  "archivePlans": true,
  "agents": ["claude-code", "opencode"],
  "stopHook": {
    "enabled": true,
    "prefilterKeywords": [],
    "judgeModel": "claude-haiku-4-5-20251001"
  }
}
```

## Templates

Templates live in [`templates/`](templates/). The choice is made at install time and recorded in `.chronicle.json` under `template`.

- [`adr-nygard.md`](templates/adr-nygard.md) — Michael Nygard's classic format (Status / Context / Decision / Consequences). Recommended.
- [`adr-extended.md`](templates/adr-extended.md) — Adds YAML frontmatter, Alternatives Considered, and Rationale sections.
- [`adr-lightweight.md`](templates/adr-lightweight.md) — Four sections only: Title, Decision, Why, Trade-offs.

## The delegation rule

When you accept the prompt, the installer appends this block to your `CLAUDE.md` (Claude Code) or `AGENTS.md` (OpenCode), wrapped in markers so the uninstaller can remove it cleanly:

```markdown
<!-- chronicle:delegation:start -->
## Architectural Decisions (Chronicle)

When a meaningful architectural or design decision is made — choosing between
alternatives, adopting or dropping a library, changing data flow, picking a
pattern, or accepting a plan — invoke the `decision-logger` subagent to record
it as an ADR in the configured decisions directory (see `.chronicle.json`).

Trigger phrases include: "let's go with", "we'll use", "decided to",
"instead of", trade-off discussions, and accepting a plan in plan mode.

Use `/log-decision` to capture a decision manually at any time.
<!-- chronicle:delegation:end -->
```

Skip it with `--no-delegation-rule` if you'd rather copy it in by hand.

## Uninstall

From the **root of the project that has Chronicle installed**:

```bash
curl -fsSL https://raw.githubusercontent.com/architraceio/chronicle/main/uninstall.sh | bash
```

Or, if you cloned the repo locally:

```bash
~/.chronicle/uninstall.sh
```

The uninstaller reads `.chronicle.json`, removes the adapter files for each configured agent, strips the delegation rule from `CLAUDE.md` / `AGENTS.md` (between its markers), and deletes `.chronicle.json`. An empty decisions directory is removed; any ADRs you've already written stay in place.

## Documentation

- [Getting Started](docs/getting-started.md)
- [How It Works](docs/how-it-works.md)
- [Customization](docs/customization.md)
- [Claude Code Adapter](docs/claude-code.md)
- [OpenCode Adapter](docs/opencode.md)
- [Why Use ADRs](docs/why-adrs.md)
- [Scaling Up](docs/scaling-up.md)

## Examples

Sample ADRs live in [`examples/decisions/`](examples/decisions/).

## Contributing

PRs welcome. See [CONTRIBUTING.md](CONTRIBUTING.md), [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md), and [SECURITY.md](SECURITY.md). Released under the [MIT license](LICENSE).
