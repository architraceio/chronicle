---
description: Chronicle decision capture rule
applyTo: "**"
---

## Architectural decisions (Chronicle)

This repository records architectural and design decisions as ADRs in the directory configured in `.chronicle.json` (default `docs/decisions/`).

- When a design decision is finalized (choosing between alternatives, adopting or dropping a dependency, changing data flow, storage, module boundaries or a convention), record it before you end the turn: use the `decision-logger` subagent if available, otherwise the `chronicle-adr` skill. One ADR per decision.
- When you start implementing an approved plan, record the plan's decisions first.
- Chronicle hooks may also remind you; never record the same decision twice (check `chronicle-adr list`).
- The user can run `/log-decision` to record a decision and `/chronicle-review` to find unrecorded ones; suggest `/chronicle-review` at the end of a long session.
