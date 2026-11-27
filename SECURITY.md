# Security Policy

## Supported Versions

This project is still in its initial development phase. Security updates will be provided for all versions.

## Reporting a Vulnerability

If you discover a security vulnerability within Chronicle, please send an email to contact@architrace.io. All security vulnerabilities will be addressed promptly.

We request that you do not publicly disclose the vulnerability until it has been addressed.

## Security Considerations

Chronicle generates markdown files and runs shell scripts (bash + jq) as hooks inside your coding agent. It does not:

- Collect telemetry or usage data
- Run a server, open ports, or have any web components
- Require an account

What it does that you should know about:

- **Hooks execute code on your machine.** They are installed by APM; with APM's executables gate enabled they only run after `apm approve`. Codex and Gemini additionally require you to trust them.
- **Audit mode sends the last exchange to a model.** Only if you set `"judge": {"mode": "audit"}`: after each turn Chronicle runs your agent's own CLI (`claude -p`, `codex exec`, `gemini -p`, `agent -p`, `copilot -p`) with your last prompt, the agent's reply and your ADR titles. This goes to the same provider and under the same credentials your agent already uses; nothing goes anywhere else. It's off by default.
- **Local state** (`.chronicle/`) contains session ids, hashes and an activity log with decision titles. It is excluded from git by its own `.gitignore`.

## Dependencies

`bash`, `jq`, `git` and standard POSIX tools. Installation and updates go through [APM](https://github.com/microsoft/apm).

## Responsible Disclosure

We encourage responsible disclosure of security vulnerabilities. Please provide a detailed explanation of how to reproduce the vulnerability and we'll work to address it as quickly as possible.