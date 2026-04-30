# Chronicle Documentation

Chronicle is an open-source companion for AI coding agents that captures 
architectural and design decisions as ADR markdown files in your repository. 
Local-first, no account, no telemetry.

## Quick Start

Install Chronicle in 60 seconds and create your first ADR in 3 minutes:

```bash
curl -fsSL https://raw.githubusercontent.com/architraceio/chronicle/main/install.sh | bash
```

1. Run `claude` and use plan mode (Shift+Tab Shift+Tab)
2. Accept a plan — your first ADR will appear in `docs/decisions/`
3. Or run `/log-decision` to capture a decision manually

## Overview

Chronicle provides two adapters:
- **Claude Code adapter**: Supports both automatic capture (plan acceptance + mid-session detection) and manual capture
- **OpenCode adapter**: Supports manual capture only

## Contents

- [Getting Started](getting-started.md)
- [How It Works](how-it-works.md)
- [Customization](customization.md)
- [Claude Code Adapter](claude-code.md)
- [OpenCode Adapter](opencode.md)
- [Why Use ADRs](why-adrs.md)
- [Scaling Up](scaling-up.md)