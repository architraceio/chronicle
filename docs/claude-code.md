# Claude Code Adapter

The Claude Code adapter for Chronicle provides both manual and automatic decision capture capabilities.

## Features

### Plan Acceptance Auto-Capture

When you accept a plan in Claude Code's plan mode, Chronicle automatically generates an ADR from that plan:

1. Claude Code's `PostToolUse` hook fires on `ExitPlanMode`
2. Chronicle saves the raw plan to `docs/decisions/_plans/`
3. Chronicle prompts Claude to invoke the `decision-logger` subagent with the plan content
4. The subagent generates a properly formatted ADR

### Mid-Session Decision Auto-Capture

When you're in a Claude Code conversation, Chronicle can detect undocumented decisions using:

1. A keyword prefilter that scans for decision-related terms
2. An LLM judge that evaluates whether a decision should be documented
3. Automatic invocation of the `decision-logger` subagent when a decision is detected

The automatic decision detection is optional and can be disabled during installation. The prefilter reduces costs by around 90% by filtering out non-decision turns.

## Limitations

Chronicle is intentionally minimal. The Claude Code adapter provides automatic capture via the following hooks:

- **PostToolUse**: Captures plans when they are accepted
- **Stop**: Detects mid-session decisions through keyword prefilter + LLM judge

This is different from more advanced tools that might include CI gateways, cross-repo decision reconciliation, or other sophisticated features.

## Manual Capture

In addition to automatic capture, you can use the `/log-decision` slash command for manual capture at any time:

1. Type `/log-decision` in Claude Code
2. Claude will prompt you for details
3. Chronicle will invoke the `decision-logger` subagent to create the ADR

## Installation Requirements

The Claude Code adapter requires:

- Claude Code version with hooks support
- A `CLAUDE_PROJECT_DIR` environment variable pointing to your project
- The ability to modify `.claude/settings.json`
- The ability to modify `CLAUDE.md` with delegation rule comments

## Configuration

Additional configuration options for Claude Code are available in `.chronicle.json`:

```json
{
  "stopHook": {
    "enabled": true,
    "prefilterKeywords": [],
    "judgeModel": "claude-haiku-4-5-20251001"
  }
}
```