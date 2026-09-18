# Repository Guidelines

## Project Structure & Module Organization

This repository contains two Bash tools for YashanDB administration:

- `yinstall/` is a Linux installer for primary and standby hosts. Its entry
  point is `yinstall/yinstall.sh`; reusable helpers live in `lib/`, workflow
  stages in `steps/`, CLI tests in `tests/`, and VM scenarios in
  `TEST_CASES.md`.
- `myas/` is the local multi-instance manager. Its entry point is
  `myas/myas.sh`; reusable logic lives in `myas/lib/` and CLI tests in
  `myas/tests/`. It delegates installation to `yinstall`.

Keep installer behavior in the appropriate `yinstall/steps/*.sh` module and
shared shell utilities in `yinstall/lib/`. Do not put generated logs, database
packages, credentials, or machine-specific instance state under version
control.

## Build, Test, and Development Commands

These are Bash projects; no compilation step is configured. Run commands from
the repository root:

```bash
bash -n yinstall/yinstall.sh yinstall/lib/*.sh yinstall/steps/*.sh yinstall/tests/test_cli.sh
bash -n myas/myas.sh myas/lib/*.sh myas/tests/test_cli.sh
yinstall/tests/test_cli.sh
bash yinstall/tests/test_ports.sh
myas/tests/test_cli.sh
bash yinstall/yinstall.sh --help
myas/myas.sh list
```

The `bash -n` commands catch syntax errors. `test_cli.sh` exercises installer
argument validation and confirms `--dry-run` does not invoke remote copy.
`--help` and `list` provide non-destructive command smoke checks. Use
`--precheck` or `--dry-run` before any installer command targeting real hosts;
follow `yinstall/TEST_CASES.md` for VM integration coverage.

## Coding Style & Naming Conventions

Write Bash 4.3+-compatible code with `#!/usr/bin/env bash`, strict mode
(`set -Eeuo pipefail`), quoted variable expansions, and explicit `--` before
path operands where applicable. Match each file's existing indentation rather
than reformatting unrelated code: `yinstall` uses tabs and `ysdb.sh` uses four
spaces. Use lowercase, descriptive function and variable names such as
`run_db_install` and `SSH_PORT`; name installer stages by responsibility
(`steps/standby.sh`). Add ShellCheck directives only for understood, local
exceptions.

## Testing Guidelines

Add or update `yinstall/tests/test_*.sh` for installer CLI behavior. Tests
should be self-contained, use temporary directories and fake external tools,
and verify both successful and rejected input paths. Add `myas/tests/test_*.sh`
for configuration, environment, and lifecycle behavior. Tests must isolate
`MYAS_CONFIG_DIR` and use fake `yinstall` or `yasboot` executables.

## Commit & Pull Request Guidelines

The root Git repository has no history. The nested `yinstall` history uses a
short imperative subject (`Add YashanDB installer lite`); follow that form,
for example `Validate standby target hosts`. Keep commits focused. PRs should
state operational impact, list commands run, link relevant issues, and include
sanitized output or screenshots only when they clarify behavior. Never include
passwords, SSH keys, host inventories, or production paths.

## Operational Runbooks

Step-by-step operational instructions live in `myas/docs/`. Before preparing or
executing a release, read `myas/docs/README.md` and follow the numbered documents in
`myas/docs/release/` in order. Each step defines its prerequisites, commands, stop
conditions, and completion criteria.

Do not infer permission to commit, tag, push, create a GitHub Release, upload
packages, or change a real host from a request to inspect or prepare a release.
These operations require explicit user authorization. In particular,
`myas/tools/release.sh` performs remote deployment and recreates the `psftdb`
instance; do not run it as a packaging-only command.

Never stop, delete, or reconfigure a database instance on a real host unless the
current request explicitly names that instance; a generic "delete the test
instances" or "clean up leftovers" request authorizes only instances named in
the conversation or provable leftovers of the current test run. Test hosts also
carry in-use databases — see `myas/docs/MYAS-AGENT-GUIDE.md` ("实例清理边界").
