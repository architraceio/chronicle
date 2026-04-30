---
description: Manually capture an architectural decision as an ADR.
---
Invoke the `decision-logger` subagent. Pass it the decision the user wants to record, including: the context that led to it, the choice made, alternatives considered, and the rationale.

If the user hasn't provided enough information for a complete ADR, ask one focused clarifying question before invoking the subagent.