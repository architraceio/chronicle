---
name: log-decision
description: Manually record an architectural decision as an ADR. Use when the user runs /log-decision (or $log-decision), asks to log, record or document a decision, or wants to record the plan being implemented.
---

# /log-decision

1. Work out what to record, in this order:
   - the decision the user described with the command, if any;
   - otherwise, if a plan was approved or is being implemented in this session and has no ADRs yet, its decisions;
   - otherwise, the most recent finalized decision in this conversation.
2. If the reason for the decision or the rejected alternatives are unclear, ask the user ONE focused question. Do not guess.
3. Record it with the **chronicle-adr** skill (delegate to the `decision-logger` subagent if your harness has it). One ADR per decision. Status `Accepted` if the user confirms it is final, otherwise `Proposed`.
4. Report each new ADR path in one line.
