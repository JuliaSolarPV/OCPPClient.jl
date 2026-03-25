# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OCPPClient.jl is a Julia package for OCPP (Open Charge Point Protocol) client functionality, owned by the JuliaSolarPV GitHub organization. Built from BestieTemplate.jl (strategy level 3). Requires Julia >= 1.10.

## Common Commands

### Testing
```bash
# Run all tests
julia --project=. -e 'using Pkg; Pkg.test()'

# Run tests via TestItemRunner (used by runtests.jl)
julia --project=. -e 'using TestItemRunner; @run_package_tests verbose=true'

# Run a single test file or tagged tests from VS Code / Julia REPL:
# TestItemRunner discovers @testitem blocks automatically — filter by tags like "unit", "fast", "slow", "integration", "validation"
```

### Formatting
```bash
# Format all Julia files (margin=92, indent=4, unix line endings)
julia -e 'using JuliaFormatter; format(".")'
```

### Linting / Pre-commit
```bash
pre-commit run --all-files
```

### Documentation
```bash
# Build docs locally
julia --project=docs docs/make.jl

# Live-serve docs (LiveServer is a docs dependency)
julia --project=docs -e 'using LiveServer; servedocs()'
```

## Architecture

- **`src/OCPPClient.jl`** — Main module entry point.
- **`test/`** — Tests use `TestItemRunner` with `@testitem` blocks (not standard `@testset`). Tests are tagged (e.g., `"unit"`, `"fast"`, `"slow"`) and support `@testsnippet` for shared setup and `@testmodule` for test helpers.
- **`docs/`** — Documenter.jl with auto-generated API reference via `@autodocs`. Has its own `Project.toml` workspace.

## Code Style

- **Indent:** 4 spaces for Julia, 2 spaces for YAML/TOML/JSON/Markdown
- **Line length:** 92 characters (Julia), enforced by JuliaFormatter
- **Line endings:** LF (unix) everywhere
- **Formatter config:** `.JuliaFormatter.toml`

## CI/CD

- Tests run on Julia LTS + latest across Ubuntu/macOS/Windows
- Coverage target: 90% (codecov)
- Pre-commit hooks validate formatting, JSON/TOML/YAML syntax, markdown lint, and link checking
- Docs deploy to GitHub Pages via Documenter.jl
- TagBot handles automated releases from JuliaRegistrator
