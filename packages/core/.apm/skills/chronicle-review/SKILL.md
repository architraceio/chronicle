---
name: chronicle-review
description: Sweep the current conversation for architectural decisions that have no ADR yet and offer to record them. Use when the user runs /chronicle-review, at the end of a working session, or before committing a larger change.
---

# /chronicle-review

1. Run `chronicle-adr list` (see the chronicle-adr skill for the script path) to see what is already recorded.
2. Go through this conversation from the start. List every decision that was **finalized** (chosen between alternatives, adopted or dropped a dependency, changed data flow, storage, boundaries or a convention) and is not covered by an existing ADR. Ignore open questions and routine implementation steps.
3. Show the user a short numbered list: title (noun phrase), one-line summary, proposed status. If there is nothing, say so in one line and stop.
4. Ask which ones to record (all / numbers / none). Record the chosen ones with the chronicle-adr skill, one ADR per decision, and report the paths.
