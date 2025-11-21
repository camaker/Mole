# Contributing to Mole

## Setup

```bash
# Install development tools
brew install shfmt shellcheck bats-core
```

## Development

Run all quality checks before committing:

```bash
./scripts/check.sh
```

This command runs:

- Code formatting check
- ShellCheck linting
- Unit tests

Individual commands:

```bash
# Format code
./scripts/format.sh

# Run tests only
./tests/run.sh
```

## Code Style

- Bash 3.2+ compatible
- 4 spaces indent
- Use `set -euo pipefail`
- Quote all variables
- BSD commands not GNU

Config: `.editorconfig` and `.shellcheckrc`

## Requirements

- macOS 10.14 or newer, works on Intel and Apple Silicon
- Default macOS Bash 3.2+ plus administrator privileges for cleanup tasks
- Install Command Line Tools with `xcode-select --install` for curl, tar, and related utilities
- Go 1.24+ required when building the `mo status` or `mo analyze` TUI binaries locally

## Go Components

`mo status` and `mo analyze` use Go for the interactive dashboards.

- Format code with `gofmt -w ./cmd/...`
- Run `go test ./cmd/...` before submitting Go changes (ensures packages compile)
- Build universal binaries locally via `./scripts/build-status.sh` and `./scripts/build-analyze.sh`

## Pull Requests

1. Fork and create branch
2. Make changes
3. Run checks: `./scripts/check.sh`
4. Commit and push
5. Open PR

CI will verify formatting, linting, and tests.
