# OpenCode Adapter

The OpenCode adapter for Chronicle provides manual decision capture only.

## Features

### Manual Capture

The OpenCode adapter provides a `/log-decision` slash command that allows you to manually capture architectural decisions at any time:

1. Type `/log-decision` in OpenCode
2. OpenCode will prompt you for details about the decision
3. Chronicle will invoke the `decision-logger` subagent to create the ADR

## Limitations

Chronicle is intentionally minimal. The OpenCode adapter only provides manual capture capabilities because:

1. OpenCode plugins are TypeScript, not shell
2. There's no built-in prompt-type hook for sending turn content to a fast LLM judge
3. Adding this capability would put code back into the project, which would be scope creep

This asymmetry is by design, not a limitation. The Claude Code adapter is more advanced due to the richer hook system available in Claude Code.

## Manual Capture

There's a fundamental difference in how manual capture works between the two adapters:

- **Claude Code**: You can also benefit from automatic decision detection
- **OpenCode**: Manual capture only via the `/log-decision` command

The OpenCode adapter keeps the same quality bar for decision logging as Claude Code.

## Installation Requirements

The OpenCode adapter requires:

- OpenCode version with slash command support
- The ability to modify `AGENTS.md` with delegation rule comments
- The ability to place command files in `.opencode/command/`
- The ability to place agent files in `.opencode/agent/`

## Configuration

OpenCode adapter configuration options are the same as Claude Code, as they share the same core subagent:

```json
{
  "agents": ["opencode"],
  "stopHook": {
    "enabled": false
  }
}
```

The `stopHook` is intentionally disabled for OpenCode because the underlying architecture doesn't support it.