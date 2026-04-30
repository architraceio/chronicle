# Security Policy

## Supported Versions

This project is still in its initial development phase. Security updates will be provided for all versions.

## Reporting a Vulnerability

If you discover a security vulnerability within Chronicle, please send an email to contact@architrace.io. All security vulnerabilities will be addressed promptly.

We request that you do not publicly disclose the vulnerability until it has been addressed.

## Security Considerations

Chronicle is a minimal project that only generates markdown files and runs shell scripts. It does not:

- Collect telemetry or usage data
- Connect to external services
- Store or process sensitive information
- Have any web components or user interfaces

## Dependencies

Chronicle has no external dependencies beyond the shell scripts, which only use standard Unix utilities and `jq`.

## Responsible Disclosure

We encourage responsible disclosure of security vulnerabilities. Please provide a detailed explanation of how to reproduce the vulnerability and we'll work to address it as quickly as possible.