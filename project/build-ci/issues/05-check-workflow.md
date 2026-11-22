# 05: Check workflow on PRs and pushes to main

Status: ready-for-agent
Blocked by: None (can start immediately)
Parent: `project/build-ci/spec.md`

## What to build

A GitHub Actions workflow on the PeloNZ fork that runs `check.sh` on every pull request and every push to `main`. The job builds the repo `Dockerfile` with buildx and the GHA layer cache, then runs `check.sh` in that image as the `dev` user. CI then uses the same tool versions as the dev container.

## Acceptance criteria

- [ ] `.github/workflows/check.yml` runs on `pull_request` and on `push` to `main`.
- [ ] The job builds the `Dockerfile` with the GHA layer cache and runs `./scripts/check.sh` in it.
- [ ] Third-party actions are pinned by commit SHA.
- [ ] The workflow sets read-only `contents` permission.
- [ ] A PR on the fork with a failing check (for example a Biome error) makes the job fail; a clean PR passes. Report both runs.
- [ ] A second run on the same Dockerfile reuses the cached layers: report both durations.
- [ ] The workflow holds no secrets.
