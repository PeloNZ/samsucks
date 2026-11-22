# 04: package.sh and a slimmer deploy.sh

Status: ready-for-human
Blocked by: 01
Parent: `project/build-ci/spec.md`

## What to build

A `package.sh` script that signs the built app into `build/samsucks.wgt` with no TV. It uses the signing profile named by `TIZEN_SIGN_PROFILE` (default `samsucks`) and reads `.env` when present. When the profile is missing, it adds it from `TIZEN_AUTHOR_P12` (a path to the author certificate) and `TIZEN_CERT_PASSWORD`. When no keyring `.pwd` file exists, it writes the author password and Samsung's public distributor password into `profiles.xml` and points `cli-config` at that file, as `setup.sh` does now.

`setup.sh` uses the same profile code, so dev and CI sign the same way. `deploy.sh` calls `build.sh`, then `package.sh`, then installs and runs. It keeps `--dev` and `--no-run` and drops `--build-only` and `--package-only`. It still needs `.env`.

## Acceptance criteria

- [ ] `./scripts/dev.sh ./scripts/build.sh && ./scripts/dev.sh ./scripts/package.sh` makes `build/samsucks.wgt` signed with the existing profile and needs no TV.
- [ ] With the profile removed and `TIZEN_AUTHOR_P12` and `TIZEN_CERT_PASSWORD` set, `package.sh` makes the profile and signs. Check that the `.wgt` author signature matches the one from the first run.
- [ ] Signing never stops at an "Author password:" prompt in the dev container.
- [ ] `setup.sh` calls the shared profile code and its result is unchanged.
- [ ] `deploy.sh` and `deploy.sh --dev` install and launch on the dev TV; `--no-run` installs only.
- [ ] `--build-only` and `--package-only` are gone from `deploy.sh`, and CLAUDE.md and the README name `build.sh` and `package.sh` instead.
- [ ] `check.sh` passes, including shellcheck and shfmt.
- [ ] Test-first does not apply (scripts); verification is the manual runs above. The ticket report says so.

## Comments

Implemented on `build-ci` (merge 552bc43). New: `scripts/package.sh`, `scripts/signing.sh` (shared with `setup.sh`). `deploy.sh` runs build, package, install, run; unknown options now exit with an error. Docs name `build.sh` and `package.sh`. Test-first skipped: scripts.

Checked: build then package with the real profile wrote `build/samsucks.wgt` with no TV and no env file; with the profile removed (in a copy of the volume) and `TIZEN_AUTHOR_P12` and `TIZEN_CERT_PASSWORD` set, `package.sh` made the profile and signed, and the author certificate and signature hash matched the first run; no password prompt (stdin is closed); `check.sh` exit 0.

Not checked (needs the TV): `deploy.sh`, `deploy.sh --dev` install and launch; `--no-run`; `setup.sh` end to end.

Open: the agent left the Docker volumes `samsucks-home-copy` and `samsucks-home-copy2`. Remove them with `docker volume rm`.
