# Contributing to DNdistresS

Thank you for your interest in contributing to DNdistresS.

## How to contribute

1. Fork the repository.
2. Create a branch:
   - `feature/<short-name>` for features
   - `fix/<short-name>` for fixes
3. Make focused changes.
4. Open a Pull Request using the PR template.
5. Respond to review feedback.

## Development notes

- Keep changes small and readable.
- Preserve POSIX shell compatibility (`#!/bin/sh`). This is not optional.
- Avoid adding hard dependencies unless absolutely required.
- Update help texts or documentation when behavior changes.

## Quality checks (recommended)

If available, run:

- `shellcheck dndistress`
- `shfmt -w dndistress`

Also verify:

- `./dndistress --help`
- `./dndistress --version`

## Commit style (simple)

Use clear, imperative messages:

- `fix: validate duration parsing for mixed units`
- `docs: add bug report template`

## Reporting bugs

Use the Bug Report issue template and include:

- Reproduction steps
- Expected vs actual behavior
- Command used
- Environment details (OS, shell, resolver/tool)
- Any relevant logs or error messages
