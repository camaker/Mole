# Mole AI Agent Documentation

> **READ THIS FIRST**: This file serves as the single source of truth for any AI agent trying to work on the Mole repository. It aggregates architectural context, development workflows, and behavioral guidelines.

## 1. Philosophy & Guidelines

### Core Philosophy

- **Safety First**: Never risk user data. Always use `safe_*` wrappers. When in doubt, ask.
- **Incremental Progress**: Break complex tasks into manageable stages.
- **Clear Intent**: Prioritize readability and maintainability over clever hacks.
- **Native Performance**: Use Go for heavy lifting (scanning), Bash for system glue.

### Eight Honors and Eight Shames

- **Shame** in guessing APIs, **Honor** in careful research.
- **Shame** in vague execution, **Honor** in seeking confirmation.
- **Shame** in assuming business logic, **Honor** in human verification.
- **Shame** in creating interfaces, **Honor** in reusing existing ones.
- **Shame** in skipping validation, **Honor** in proactive testing.
- **Shame** in breaking architecture, **Honor** in following specifications.
- **Shame** in pretending to understand, **Honor** in honest ignorance.
- **Shame** in blind modification, **Honor** in careful refactoring.

### Quality Standards

- **English Only**: Comments and code must be in English.
- **No Unnecessary Comments**: Code should be self-explanatory.
- **Pure Shell Style**: Use `[[ ]]` over `[ ]`, avoid `local var` assignments on definition line if exit code matters.
- **Go Formatting**: Always run `gofmt` (or let the build script do it).

## 2. Project Identity

- **Name**: Mole
- **Purpose**: A lightweight, robust macOS cleanup and system analysis tool.
- **Core Value**: Native, fast, safe, and dependency-free (pure Bash + static Go binary).
- **Mechanism**:
  - **Cleaning**: Pure Bash scripts for transparency and safety.
  - **Analysis**: High-concurrency Go TUI (Bubble Tea) for disk scanning.
  - **Monitoring**: Real-time Go TUI for system status.

## 3. Technology Stack

- **Shell**: Bash 3.2+ (macOS default compatible).
- **Go**: Latest Stable (Bubble Tea framework).
- **Testing**:
  - **Shell**: `bats-core`, `shellcheck`.
  - **Go**: Native `testing` package.

## 4. Repository Architecture

### Directory Structure

- **`bin/`**: Standalone entry points.
  - `mole`: Main CLI wrapper.
  - `clean.sh`, `uninstall.sh`: Logic wrappers calling `lib/`.
- **`cmd/`**: Go applications.
  - `analyze/`: Disk space analyzer (concurrent, TUI).
  - `status/`: System monitor (TUI).
- **`lib/`**: Core Shell Logic.
  - `core/`: Low-level utilities (logging, `safe_remove`, sudo helpers).
  - `clean/`: Domain-specific cleanup tasks (`brew`, `caches`, `system`).
  - `ui/`: Reusable TUI components (`menu_paginated.sh`).
- **`scripts/`**: Development tools (`run-tests.sh`, `build-analyze.sh`).
- **`tests/`**: BATS integration tests.

## 5. Key Workflows

### Development

1. **Understand**: Read `lib/core/` to know what tools are available.
2. **Implement**:
    - For Shell: Add functions to `lib/`, source them in `bin/`.
    - For Go: Edit `cmd/app/*.go`.
3. **Verify**: Use dry-run modes first.

**Commands**:

- `./scripts/run-tests.sh`: **Run EVERYTHING** (Lint, Syntax, Unit, Go).
- `./bin/clean.sh --dry-run`: Test cleanup logic safely.
- `go run ./cmd/analyze`: Run analyzer in dev mode.

### Building

- `./scripts/build-analyze.sh`: Compiles `analyze-go` binary (Universal).
- `./scripts/build-status.sh`: Compiles `status-go` binary.

### Release

- Versions managed via git tags.
- Build scripts embed version info into binaries.

## 6. Implementation Details

### Safety System (`lib/core/file_ops.sh`)

- **Crucial**: Never use `rm -rf` directly.
- **Use**:
  - `safe_remove "/path"`
  - `safe_find_delete "/path" "*.log" 7 "f"`
- **Protection**:
  - `validate_path_for_deletion` prevents root/system deletion.
  - `checks` ensure path is absolute and safe.

### Go Concurrency (`cmd/analyze`)

- **Worker Pool**: Tuned dynamically (16-64 workers) to respect system load.
- **Throttling**: UI updates throttled (every 100 items) to keep TUI responsive (80ms tick).
- **Memory**: Uses Heaps for top-file tracking to minimize RAM usage.

### TUI Unification

- **Keybindings**: `j/k` (Nav), `space` (Select), `enter` (Action), `R` (Refresh).
- **Style**: Compact footers ` | ` and standard colors defined in `lib/core/base.sh` or Go constants.

## 7. Common AI Tasks

- **Adding a Cleanup Task**:
    1. Create/Edit `lib/clean/topic.sh`.
    2. Define `clean_topic()`.
    3. Register in `lib/optimize/tasks.sh` or `bin/clean.sh`.
    4. **MUST** use `safe_*` functions.
- **Modifying Go UI**:
    1. Update `model` struct in `main.go`.
    2. Update `View()` in `view.go`.
    3. Run `./scripts/build-analyze.sh` to test.
- **Fixing a Bug**:
    1. Reproduce with a new BATS test in `tests/`.
    2. Fix logic.
    3. Verify with `./scripts/run-tests.sh`.
