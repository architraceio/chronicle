# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-11-25

### Added
- Distribution as an APM package (`apm install architraceio/chronicle`) with one core package and per-agent hook packages for Claude Code, Codex, Gemini CLI, Cursor and GitHub Copilot.
- Rule-first capture: a shared rule, installed for every agent, tells the agent to record each settled decision in the same turn (including quick acceptances and choices made while implementing), one ADR per decision.
- Shared hook engine `chronicle-hook` for plan capture and ADR write tracking. It never blocks a turn or makes the agent continue.
- Optional audit mode (`"judge": {"mode": "audit"}`): after each turn a small model, run through the agent's own CLI, checks the last prompt and reply and logs decisions it sees and whether an ADR was written. `/chronicle-status` lists possible misses.
- Plan capture that survives a broken workflow: plans are tracked when proposed and promoted on approval or on the first project edit.
- Fork guard for the audit judge: `CHRONICLE_JUDGE=1`, an empty working directory, hooks disabled, a single-judge lock.
- `chronicle-adr` script for numbering, templates, supersede, index and a git `guard` (pre-commit or CI).
- Skills `chronicle-adr`, `log-decision`, `chronicle-review`, `chronicle-status` (which also checks that the agent can see the rule).
- Portable judge timeout: coreutils `timeout` where available, otherwise a shell watchdog (macOS).
- Unit tests (`make test`) and an APM install test (`make test-apm`).
- Docs: a simplified agent support table in the README and getting started guide, the detailed matrix in `docs/harnesses.md`, and an in-depth behavior reference in `docs/behavior.md`.

### Changed
- `.chronicle.json` version 2 (`capture.planAccept`, `judge`, `guard`); version 1 files are migrated automatically.
- Before release, the end-of-turn keyword prefilter, blocking judge, deferred reminders, nudge mode and loop guards 2–6 were dropped in favour of the rule. In a live test the agent had already started recording before the hook ran; the keyword filter missed most real phrasings and matched ordinary ones; and reading agent transcripts pulled injected, non-conversation text (including private context) into the judge. The judge now only reads the prompt and reply from documented hook fields.
- ADR numbers are always 4 digits; example ADRs renamed accordingly.
- Templates moved into the `chronicle-adr` skill; the lightweight template now carries date and status.

### Removed
- `install.sh` and `uninstall.sh` (use `apm install` / `apm uninstall`).
- `claude-code/` and `opencode/` adapter directories.

### Fixed
- The v0.1 prefilter was a stub, and the prompt-hook judge ran on every turn in parallel with it, never saw the conversation and could loop.
- Curl installs lost the templates (`installDir` pointed to a deleted temp directory).

## [0.1.0] - 2026-04-29

### Added
- Initial release of Chronicle
- Install script (`install.sh`) that supports both Claude Code and OpenCode
- Full Claude Code adapter with plan acceptance auto-capture and mid-session decision detection
- OpenCode adapter with manual capture only
- Three ADR templates (Nygard classic, extended, lightweight)
- Documentation set including getting-started, how-it-works, customization guides
- Example ADRs in the examples/decisions directory
- GitHub workflows for shellcheck and release automation

### Changed
- None

### Deprecated
- None

### Removed
- None

### Fixed
- None

### Security
- None

[Unreleased]: https://github.com/architraceio/chronicle/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/architraceio/chronicle/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/architraceio/chronicle/releases/tag/v0.1.0