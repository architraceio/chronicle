# How It Works

Chronicle automatically captures architectural and design decisions as ADRs in your repository. It works with both Claude Code and OpenCode.

## Claude Code Adapter

The Claude Code adapter provides two modes of decision capture:

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

Both automatic capture methods require confirmation from you before proceeding.

## OpenCode Adapter

The OpenCode adapter provides manual capture only:

- A `/log-decision` slash command that invokes the `decision-logger` subagent
- No automatic detection, which is by design to keep the project minimal
- Integration that works similar to Claude Code but with a manual workflow

## Decision Logging Subagent

The `decision-logger` subagent is the core of Chronicle:

1. Reads `.chronicle.json` to determine configuration
2. Determines the next ADR number by counting existing ADRs
3. Reads and applies the configured ADR template
4. Generates a properly formatted ADR
5. Writes the ADR to the configured decisions directory
6. Prints the new ADR's path

## Configuration

Chronicle stores its configuration in `.chronicle.json` at the root of your project.

```json
{
  "version": 1,
  "decisionsDir": "docs/decisions",
  "template": "adr-nygard",
  "archivePlans": true,
  "agents": ["claude-code", "opencode"],
  "stopHook": {
    "enabled": true,
    "prefilterKeywords": [],
    "judgeModel": "claude-haiku-4-5-20251001"
  },
  "installDir": "/path/to/chronicle"
}
```