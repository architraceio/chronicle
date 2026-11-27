# Contributing to Chronicle

Thank you for your interest in contributing to Chronicle! This project accepts contributions of all kinds: documentation improvements, bug fixes, feature additions, and more.

## Code of Conduct

Please note that this project is released with a Contributor Code of Conduct. By participating in this project you agree to abide by its terms.

## How to Contribute

1. Fork the repository
2. Create a new branch for your feature/fix
3. Commit your changes
4. Push to your fork
5. Submit a pull request

## Reporting Issues

If you find a bug or have a feature request, please open an issue on GitHub. Include a clear description of the problem and steps to reproduce if possible.

## Pull Request Guidelines

- Make sure your code follows the existing style
- Add tests for new features
- Update documentation as needed
- Keep commits small and focused
- Write clear, descriptive commit messages

## Development Setup

You need `bash`, `jq`, `git` and [uv](https://docs.astral.sh/uv/) (used to run shellcheck and APM without installing them).

- `packages/core/`: skills, templates, the `chronicle-adr` script, the `decision-logger` agent and the rule. Works in every agent.
- `packages/engine/`: the shared hook engine. **Edit it here only**, then run `make sync` to copy it into each `packages/hooks-<agent>/`.
- `packages/hooks-<agent>/`: per-agent hook wiring (`targets:` restricts each to its agent).

If you change what the engine does (events, messages, state files, log actions, the rule), update [docs/behavior.md](docs/behavior.md) as well, and the support tables if an agent's support changes (README, `docs/getting-started.md`, `docs/index.md`, `docs/harnesses.md`).

`make all` syncs, checks the sync, lints and runs the unit tests. `make test-apm` installs the package into a fixture project with APM. See [TESTING.md](TESTING.md) for the live smoke tests.

## License

By contributing to Chronicle, you agree that your contributions will be licensed under the MIT license.