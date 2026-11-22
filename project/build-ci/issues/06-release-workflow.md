# 06: Release workflow on version tags

Status: ready-for-human
Blocked by: 02, 03, 04, 05
Parent: `project/build-ci/spec.md`

## What to build

A GitHub Actions workflow on the PeloNZ fork that turns a `vX.Y.Z` tag into a signed GitHub Release with `samsucks.wgt` attached. It signs with the existing author certificate from secrets, never a new one (ADR 0005).

Steps, in order: compare the tag (without `v`) to the `config.xml` version and fail on a difference; run `check.sh`; restore the Tizen CLI install from cache, or run the install script; decode the secret `TIZEN_AUTHOR_P12_BASE64` to a file outside the repo; run build, then package with `TIZEN_AUTHOR_P12` and the secret `TIZEN_CERT_PASSWORD`; create the Release with `samsucks.wgt`. Only this job has `contents: write`.

## Acceptance criteria

- [ ] `.github/workflows/release.yml` runs on tags `v*.*.*`.
- [ ] A tag that differs from the `config.xml` version fails the job before the build, with a message that names both versions.
- [ ] A tag on a commit that fails `check.sh` makes no Release.
- [ ] The Tizen CLI install is cached, keyed on the Tizen version. Report cold and cached run times.
- [ ] The decoded certificate never lands in the repo, in a Release asset or in an uploaded artifact. Secrets do not appear in logs.
- [ ] The job never makes a certificate (no `tizen certificate` call).
- [ ] Third-party actions are pinned by commit SHA.
- [ ] Signing works on the runner. If it fails with "keystore password was incorrect", fix it with the `profiles.xml` password patch from ticket 04 and report the cause.
- [ ] Report whether signing works without the TV extension packages. Drop them from the CI install only if it does.
- [ ] A Release exists for a matching tag with `samsucks.wgt` attached.

## Comments

Implemented on `build-ci` (merges 47dc0e9, 64451c3): `.github/workflows/release.yml`, `scripts/tizen-version`. The tag-versus-`config.xml` check ran locally: `v0.1.0` passes; `v0.2.0` fails naming both versions. Actions pinned by SHA; `contents: write` on the release job only; no `tizen certificate` call; the p12 is decoded into `RUNNER_TEMP`, mounted read-only and removed in an `always()` step. Code review found the cache-miss path failed (an empty `tizen-sdk` directory); fixed in 64451c3.

Not checked (needs GitHub and the real secrets): any workflow run; a tag on a failing commit makes no Release; signing on the runner (if it fails with "keystore password was incorrect", the `profiles.xml` patch from ticket 04 is already in `package.sh`); cold and cached timings; whether signing works without the TV extension packages (the install still installs them).

A cache saved on a tag run is scoped to that tag, so a later tag would miss it (story 26). `.github/workflows/tizen-cache.yml` seeds the cache from `main` under the same key: on a push to `main` that changes `scripts/tizen-version` or `scripts/install-tizen.sh`, weekly (which keeps the cache from the 7-day unused eviction), and on `workflow_dispatch`. Not run on GitHub. After the first push to `main`, run it once by hand. The cache is about 4 GB; the repo limit is 10 GB, shared with the Docker layer cache. Also `package.sh` passes the password as a command-line argument (`tizen security-profiles add -p`); GitHub masks it in logs.
