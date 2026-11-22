# Build and CI

Status: ready-for-agent
Source: `notes/architecture-review.md` (B1, B2, CI/CD and signing); ADR 0005

## Problem Statement

The developer cannot make a release build without a TV and a `.env`. `deploy.sh` builds, signs, installs and runs in one script, and stops when `.env` is missing, so CI cannot use it. The build rewrites `config.js` with a heredoc and `sed` to set dev and version values. Every release build ships the dev remote (`dev/remote.js`, which runs `eval` on snippets from the devserver); only a runtime `if (DEV)` stops it, and no check proves it. Releases are signed by hand on one machine, and nothing stops a release whose version differs from `config.xml`.

## Solution

The build takes dev and version values as build-time constants, so a release build contains no dev code at all, and `check.sh` proves it. Three scripts replace the one: build, package, deploy. Build needs nothing but the repo. Package signs with the signing profile, made from env vars when missing. Deploy installs and runs on the TV. GitHub Actions on the PeloNZ fork runs `check.sh` on every PR and push to `main`. A `vX.Y.Z` tag that matches the `config.xml` version runs the checks, signs a release build with the existing author certificate from secrets, and publishes a GitHub Release with `samsucks.wgt`.

## User Stories

1. As the developer, I want a release build to contain no dev remote code, so that no shipped app can run `eval` on code from the network.
2. As the developer, I want `check.sh` to fail when a release bundle contains the dev remote, so that a regression cannot reach a release.
3. As the developer, I want `check.sh` to fail when a release bundle names the devserver, so that no dev host leaks into a release build.
4. As the developer, I want `check.sh` to fail when a dev bundle lacks the dev remote, so that the release check cannot pass because the build dropped dev code from both builds.
5. As the developer, I want the release bundle to carry the `config.xml` version, so that Settings and the Plex identity headers report the shipped version.
6. As the developer, I want dev and version values set at build time, not by rewriting source files, so that the build never edits copied source.
7. As the developer, I want the build to need no `.env`, no TV and no Tizen CLI, so that I and CI can build anywhere the dev image runs.
8. As the developer, I want `build.sh --dev` to make a dev build with my devserver host and optional skip-login server from `.env`, so that the dev loop on the TV works as before.
9. As the developer, I want a separate package step that signs the built app into `samsucks.wgt`, so that I can make a signed package without a TV.
10. As the developer, I want the package step to create the signing profile from env vars when it is missing, so that a fresh machine or CI runner can sign without `setup.sh`.
11. As the developer, I want the package step to write the profile passwords into `profiles.xml` when no keyring exists, so that signing does not stop at a password prompt in a container.
12. As the developer, I want `setup.sh` to use the same profile code as the package step, so that dev and CI sign the same way.
13. As the developer, I want `deploy.sh` to build, package, install and run with one command, so that my daily loop stays one command.
14. As the developer, I want `deploy.sh --dev` and `--no-run` to keep working, so that I do not relearn the dev loop.
15. As the developer, I want one Tizen CLI install script shared by `setup.sh` and CI, so that dev and CI use the same Tizen version.
16. As the developer, I want the Tizen CLI install to keep its failure checks (installer exits 0 on failure; existing folder refused), so that a broken install fails loudly.
17. As the developer, I want CI to run `check.sh` on every pull request, so that I see lint, syntax, shell and unit test failures before merge.
18. As the developer, I want CI to run `check.sh` on every push to `main`, so that `main` stays green.
19. As the developer, I want the check job to use the same Dockerfile as my dev container, so that CI uses the same tool versions as my machine.
20. As the developer, I want the check job to cache Docker layers, so that a PR check does not re-download Node, Biome and esbuild each run.
21. As the developer, I want a release to start from a `vX.Y.Z` tag, so that releasing is one `git push` of a tag.
22. As the developer, I want the release job to fail when the tag differs from the `config.xml` version, so that no release ships with a wrong version.
23. As the developer, I want the release job to run `check.sh` before it packages, so that a tag on a broken commit makes no release.
24. As the developer, I want the release job to sign with the existing author certificate from secrets, so that TVs with the app installed accept the upgrade (ADR 0005).
25. As the developer, I want the release job never to make a new author certificate, so that no release forces users to uninstall the app.
26. As the developer, I want the release job to cache the Tizen CLI install, so that a release does not download 280 MB each time.
27. As the developer, I want the release job to publish a GitHub Release with `samsucks.wgt` attached, so that I can install a release on any TV in Developer Mode.
28. As the developer, I want README steps that load the author certificate and its password into the fork's secrets, so that I can set up CI once without guesswork.
29. As the developer, I want README steps to keep a copy of the author certificate outside the Docker volume, so that losing the volume does not end upgrades.
30. As a TV user, I want each release to install over my current version, so that I keep my sign-in and settings.
31. As the developer, I want unit tests to run with the build-time constants set to release values, so that tests import app modules without a build.
32. As the developer, I want CLAUDE.md and the README to name the new scripts, so that the docs match the commands.

## Implementation Decisions

- Build-time constants: code reads four free globals, `__DEV__`, `__DEV_HOST__`, `__DEV_PLEX_URL__`, `__VERSION__`. The build sets each with esbuild `--define`. The config module goes; every module that imported from it reads the globals instead. esbuild then drops `if (__DEV__)` branches, and with them the dynamic import of the dev remote, from a release build.
- Release values: `__DEV__` false, dev host and Plex URL empty strings, `__VERSION__` from the `config.xml` widget version.
- Dev values: `__DEV__` true, `__DEV_HOST__` from `DEV_HOST`, `__DEV_PLEX_URL__` from `PLEX_SERVER_URL` only when `DEV_SKIP_LOGIN=1`.
- The build stays: copy `app/` to the output, bundle `main.js` to one IIFE script for Chromium 56, remove `type="module"` from `index.html`. The output directory is a build option, so `check.sh` can build into a temp directory.
- Unbundled `app/` in a desktop browser is not supported. The desktop path stays: build, then serve the build output.
- Build script: no `.env` needed. With `--dev`, it reads `.env` when present for the dev values.
- Package script: signs the build output into `build/samsucks.wgt` with `TIZEN_SIGN_PROFILE` (default `samsucks`). It reads `.env` when present. When the profile is missing, it adds it from `TIZEN_AUTHOR_P12` (a path) and `TIZEN_CERT_PASSWORD`. When no keyring `.pwd` file exists, it writes the author password and Samsung's public distributor password into `profiles.xml`, as setup does now, and points `cli-config` at that file.
- Setup keeps certificate creation, TV discovery and connect. It calls the shared Tizen CLI install script and the shared profile code.
- Deploy script: needs `.env`. Calls build, then package, then installs and runs. Keeps `--dev` and `--no-run`. Drops `--build-only` and `--package-only`.
- Tizen CLI install script: the current setup install step (installer download with resume, Apple Silicon workaround, failure checks, TV extension packages), parameterised by install directory and version.
- Check job: GitHub Actions on the PeloNZ fork, on `pull_request` and push to `main`. Builds the dev Dockerfile with buildx and the GHA layer cache, then runs `check.sh` in the image as the `dev` user.
- Release job: on tags `v*.*.*`. Steps: compare the tag (without `v`) to the `config.xml` version and fail on a difference; run `check.sh`; restore the Tizen CLI install from cache or run the install script; decode `TIZEN_AUTHOR_P12_BASE64` to a file; run build then package; create a GitHub Release for the tag with `samsucks.wgt`. Permissions: `contents: write` for this job only.
- Secrets: `TIZEN_AUTHOR_P12_BASE64` (the `samsucks.p12` from the `samsucks-home` volume) and `TIZEN_CERT_PASSWORD` (from `.env`). The decoded certificate never lands in the repo or in an uploaded artifact.
- Pin third-party actions by commit SHA.
- `check.sh` gains the build-output step (see Testing Decisions) and covers the new shell scripts with shellcheck and shfmt.

## Testing Decisions

- A good test checks behaviour you can see from outside: what the build writes, what a command prints or exits with. It does not check how a script is written.
- Primary seam: the bundle the build script writes. A new `check.sh` step builds a release bundle and a dev bundle into a temp directory, then fails when:
  - the release bundle contains `startDevRemote`;
  - the release bundle contains the devserver paths (`/cmd`, `/log`);
  - the release bundle does not contain the `config.xml` version string;
  - the dev bundle does not contain `startDevRemote`.
- Regression seam: the existing `node:test` suite (`test/input.test.mjs`, `test/images.test.mjs`, `test/subtitles.test.mjs`). A shared `test/setup.mjs`, loaded with `node --import`, sets the four globals to release values. `check.sh` and the documented test commands load it.
- Write the build-output step first and watch it fail on today's release build (it contains `startDevRemote`). Then make the build change.
- No automated tests for the package script, the Tizen CLI install script or the workflows. Verify by running them:
  - package script in the dev container with the existing profile, then with the profile removed and the env vars set;
  - deploy script to the dev TV, release and `--dev`;
  - a PR on the fork for the check job;
  - a throwaway release: on a branch, set `config.xml` to a spare version, push its tag to the fork, install the attached `.wgt` over the current app on the dev TV, then delete the release and tag;
  - a tag that differs from `config.xml` fails the release job.

## Out of Scope

- A new app ID or widget ID. The app keeps `SamSucks01.samsucks` (review: decide before a public release).
- Byte-identical builds (fixed zip timestamps).
- Runtime API checks for Chromium 56 (review item B3) and JSDoc types with `tsc`.
- A Samsung distributor certificate or DUID list.
- Publishing to the Samsung store.
- CI on upstream `rfaile313/samsucks`.
- A helper script to load secrets.

## Further Notes

- Unchecked: whether the base web-cli signs without the TV extension packages. The install script installs them, as setup does now; drop them from CI only after a test shows signing works without them.
- Known problem: "keystore password was incorrect" when signing on GitHub Actions (Samsung forum). The `profiles.xml` password patch is the planned fix; check it on the first tag run.
- Losing the author certificate or its password ends upgrades for every installed TV (ADR 0005).
