## What and why

Fixes #

## Agents affected

- [ ] Claude Code
- [ ] Codex
- [ ] Gemini CLI
- [ ] Cursor
- [ ] Copilot
- [ ] OpenCode
- [ ] none (core / docs only)

## Checklist

- [ ] Engine edited only in `packages/engine/`, then `make sync`
- [ ] `make all` passes (sync check, shellcheck, unit tests)
- [ ] `make test-apm` passes if manifests, hook files or package layout changed
- [ ] New behavior has a test in `tests/run.sh`; hook changes keep the "stop never blocks" and fork-guard tests passing
- [ ] Live smoke test from `TESTING.md` run for affected agents (say which)
- [ ] Docs updated (`README.md`, `docs/behavior.md` if engine behavior changed, support tables if support changed, `CHANGELOG.md`)
