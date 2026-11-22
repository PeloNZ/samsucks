# 03: Extract install-tizen.sh from setup.sh

Status: ready-for-agent
Blocked by: None (can start immediately)
Parent: `project/build-ci/spec.md`

## What to build

One Tizen CLI install script that `setup.sh` and CI both call, so dev and CI use the same Tizen version. It holds the current install step of `setup.sh`: the installer download with resume, the Apple Silicon workaround, the failure checks and the TV extension packages. It takes the install directory and the Tizen version as inputs. `setup.sh` behaves as before.

## Acceptance criteria

- [ ] `scripts/install-tizen.sh` installs the Tizen CLI and the TV extension packages into the directory it is given, and does nothing when they are already installed.
- [ ] It keeps the two failure checks: the installer exits 0 on failure, so it checks that the `tizen` binary exists; and it refuses an existing folder that has no `tizen` binary.
- [ ] It keeps the download in `build/downloads/` so a failed install does not download again.
- [ ] `setup.sh` calls it and its output, log file and result are unchanged. Verify by running `./scripts/dev.sh ./scripts/setup.sh` on a machine that already has the install (it reports "already installed").
- [ ] Verify a cold install in an empty directory in the dev container.
- [ ] `check.sh` passes, including shellcheck and shfmt.
- [ ] Test-first does not apply (script move). The ticket report says so.
