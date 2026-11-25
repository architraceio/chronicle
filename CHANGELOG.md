# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-11-25

### Added
- Distribution as an APM package (`apm install architraceio/chronicle`) with one core package and per-agent hook packages for Claude Code, Codex, Gemini CLI, Cursor and GitHub Copilot.
- Shared hook engine `chronicle-hook`: keyword prefilter plus a headless judge through the agent's own CLI, a conversation window instead of only the last reply, one ADR per decision.
- Plan capture that survives a broken workflow: plans are tracked when proposed and promoted on approval or on the first project edit.
- Six independent loop guards, including a per-session cap and a fork guard for the judge.
- `chronicle-adr` script for numbering, templates, supersede, index and a git `guard` (pre-commit or CI).
- Skills `chronicle-adr`, `log-decision`, `chronicle-review`, `chronicle-status`; a shared rule for agents without full hook support; deferred delivery of reminders on the next prompt or tool result (Gemini always, every agent in nudge mode).
- Portable judge timeout: coreutils `timeout` where available, otherwise a shell watchdog (macOS).
- Unit tests (`make test`) and an APM install test (`make test-apm`).
- Docs: a simplified agent support table in the README and getting started guide, the detailed matrix in `docs/harnesses.md`, and an in-depth behavior reference in `docs/behavior.md`.

### Changed
- `.chronicle.json` version 2 (`capture`, `judge`, `guard`); version 1 files are migrated automatically.
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