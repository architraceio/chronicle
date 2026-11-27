---
description: Chronicle decision capture rule
applyTo: "**"
---

## Architectural decisions (Chronicle)

This repository records architectural and design decisions as ADRs in the directory configured in `.chronicle.json` (default `docs/decisions/`). Recording them is your job: Chronicle's hooks only step in for approved plans.

- When a design decision is settled, record it **in the same turn**, before you end it: use the `decision-logger` subagent if available, otherwise the `chronicle-adr` skill. One ADR per decision.
- This includes decisions the user settles briefly ("ok", "do that", "option B" after you laid out options), and decisions you make yourself while implementing: adding or dropping a dependency, picking a library, pattern, data model, storage or protocol, changing module boundaries or a convention.
- It does not include routine steps, bug fixes or refactors without a design change.
- When you start implementing an approved plan, record the plan's decisions first.
- Never record the same decision twice: check `chronicle-adr list`, and don't start a second `decision-logger` while one is still running for it.
- The user can run `/log-decision` to record a decision and `/chronicle-review` to find unrecorded ones; suggest `/chronicle-review` at the end of a long session.
