# 06: Release workflow on version tags

Status: ready-for-agent
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
