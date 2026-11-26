---
name: chronicle-status
description: Show whether Chronicle is set up and working in this repository (config, whether the agent can see the rule, hook activity, audit results, pending plans) and help fix problems. Use when the user runs /chronicle-status or asks whether Chronicle is working.
disable-model-invocation: true
---

# /chronicle-status

Report briefly, in this order:

1. **Config**: run `chronicle-adr config` (script path: see the chronicle-adr skill). Show decisions dir, template and `judge.mode` (`off` or `audit`). If `.chronicle.json` is missing, offer to create it with `chronicle-adr init` and ask which template the user wants (`adr-nygard` default, `adr-extended`, `adr-lightweight`).
2. **Rule**: the agent records decisions because of the Chronicle rule, so check that it can see it:
   - Claude Code: `.claude/rules/chronicle.md`. Cursor: `.cursor/rules/chronicle.mdc`. Copilot: `.github/instructions/chronicle.instructions.md`.
   - Codex and OpenCode: `AGENTS.md` contains "Architectural decisions (Chronicle)". Gemini CLI: the same, and `GEMINI.md` imports `@./AGENTS.md`.
   - If it is missing, explain that the agent won't record decisions on its own and point to "Add the Chronicle rule to AGENTS.md" in Chronicle's getting-started guide.
3. **Records**: number of ADRs (`chronicle-adr list`) and the three most recent.
4. **Hook activity**: read `.chronicle/log.jsonl`. Summarize plans pending and archived (`plan-pending`, `plan-promoted`).
   - With `judge.mode: audit`, also summarize `audit` entries: turns audited, decisions the judge saw, and how many had `adr_this_turn: false`. For those, compare the titles with `chronicle-adr list` by meaning (a background `decision-logger` may have finished after the turn ended). List the ones with no matching ADR as possible misses and offer `/log-decision`. Mention `audit-unavailable` entries (the judge CLI is missing, not logged in, or timed out).
   - If the log is empty and a plan was approved, hooks may not be running. Tell the user how to enable them for their harness:
     - Codex: open `/hooks` and trust the Chronicle hooks (needed again after each update).
     - Gemini CLI: accept the hook trust prompt; hooks only run in trusted folders.
     - APM approval gate on: run `apm approve chronicle`.
     - OpenCode and Copilot in VS Code have no Chronicle hooks; that is fine, the rule, `/log-decision` and `/chronicle-review` work there.
5. **Pending**: list files `.chronicle/state/*/pending-plan.json` (plans proposed but not yet implemented). Offer `/log-decision` for them.
