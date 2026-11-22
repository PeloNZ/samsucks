# 04: package.sh and a slimmer deploy.sh

Status: ready-for-agent
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
