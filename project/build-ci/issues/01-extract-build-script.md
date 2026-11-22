# 01: Extract build.sh from deploy.sh

Status: ready-for-agent
Blocked by: None (can start immediately)
Parent: `project/build-ci/spec.md`

## What to build

A `build.sh` script that makes the app bundle with no `.env`, no TV and no Tizen CLI. `deploy.sh` calls it. This is a prefactor: the build output stays the same as today.

`build.sh` takes `--dev` and an output directory option. With `--dev` it reads `.env` when present for the dev values. Without `.env` it still makes a release build.

## Acceptance criteria

- [ ] `./scripts/dev.sh ./scripts/build.sh` makes a release build in a fresh clone with no `.env`.
- [ ] `./scripts/build.sh --dev` makes the same dev build as `deploy.sh --dev` does today (same `DEV_HOST` and skip-login handling).
- [ ] The output directory is an option, so a later check can build into a temp directory.
- [ ] `deploy.sh` calls `build.sh` and still builds, packages, installs and runs as before, including `--dev`, `--no-run`, `--build-only` and `--package-only`.
- [ ] The built `index.html` has no `type="module"` and the bundle is one classic script for Chromium 56.
- [ ] `check.sh` passes, including shellcheck and shfmt on the new script.
- [ ] Test-first does not apply (script move, no behaviour change). The ticket report says so.
