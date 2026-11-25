---
name: chronicle-status
description: Show whether Chronicle is set up and working in this repository (config, recent hook activity, judge results, pending plans) and help fix problems. Use when the user runs /chronicle-status or asks whether Chronicle is working.
disable-model-invocation: true
---

# /chronicle-status

Report briefly, in this order:

1. **Config**: run `chronicle-adr config` (script path: see the chronicle-adr skill). Show decisions dir, template, capture mode and judge settings. If `.chronicle.json` is missing, offer to create it with `chronicle-adr init` and ask which template the user wants (`adr-nygard` default, `adr-extended`, `adr-lightweight`).
2. **Records**: number of ADRs (`chronicle-adr list`) and the three most recent.
3. **Hook activity**: read the last 20 lines of `.chronicle/log.jsonl`. Summarize: prefilter misses, judge verdicts, `judge-unavailable` events (the judge CLI is missing or not logged in; Chronicle then falls back to `judge.fallback`), plans archived, deferred deliveries.
   - If the file does not exist or has no entries, hooks have never run. Tell the user how to enable them for their harness:
     - Codex: open `/hooks` and trust the Chronicle hooks (needed again after each update).
     - Gemini CLI: accept the hook trust prompt; hooks only run in trusted folders.
     - APM approval gate on: run `apm approve chronicle`.
     - OpenCode and Copilot in VS Code have no Chronicle hooks; use `/log-decision` and `/chronicle-review`.
4. **Pending**: list files `.chronicle/state/*/pending-plan.json` (plans proposed but not yet implemented) and undelivered entries in `.chronicle/state/*/flagged.json`. Offer `/log-decision` for them.
