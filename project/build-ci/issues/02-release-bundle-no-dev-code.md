# 02: Release bundles carry no dev code

Status: ready-for-agent
Blocked by: 01
Parent: `project/build-ci/spec.md`

## What to build

A release bundle contains no dev remote code, and `check.sh` proves it. Code reads four free globals (`__DEV__`, `__DEV_HOST__`, `__DEV_PLEX_URL__`, `__VERSION__`) that `build.sh` sets with esbuild `--define`. The config module goes, and every module that imported from it reads the globals. esbuild then drops the dev branches, and the dynamic import of the dev remote, from a release build.

Release values: `__DEV__` false, dev host and Plex URL empty, version from `config.xml`. Dev values come from `DEV_HOST`, and from `PLEX_SERVER_URL` only when `DEV_SKIP_LOGIN=1`.

Unbundled `app/` in a desktop browser stops working. The desktop path is: build, then serve the build output. Update the CLAUDE.md lines that say otherwise.

## Acceptance criteria

- [ ] First, add the `check.sh` build-output step and watch it fail on today's release build because the bundle contains `startDevRemote`.
- [ ] The step builds a release bundle and a dev bundle into a temp directory and fails when:
  - the release bundle contains `startDevRemote`;
  - the release bundle contains the devserver paths (`/cmd`, `/log`);
  - the release bundle lacks the `config.xml` version string;
  - the dev bundle lacks `startDevRemote`.
- [ ] After the change, the step passes.
- [ ] `test/setup.mjs` sets the four globals to release values. `check.sh` and the documented test commands load it with `node --import`.
- [ ] The existing unit tests pass with that setup.
- [ ] `app/js/config.js` is gone and nothing imports it.
- [ ] A dev build still sends logs and takes remote keys: verify with `deploy.sh --dev` and `tools/tveval.sh 'document.title'` on the dev TV.
- [ ] Settings shows the right version and `(dev)` only in a dev build.
- [ ] CLAUDE.md "Build" and "Architecture" sections match the new build.
- [ ] `check.sh` passes.
