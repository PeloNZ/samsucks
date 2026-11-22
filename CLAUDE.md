# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

SamSUCKS is a Plex client for Samsung Tizen TVs. Source is plain ES modules, no framework, no npm. `deploy.sh` bundles it with esbuild for old TVs.

## Commands

Run every script in the Ubuntu amd64 dev container (`compose.yaml`). It matches the Ubuntu target machine and has the Tizen CLI, sdb, Node 22, esbuild and the checkers. The Tizen tools and certificates live in the `samsucks-home` Docker volume. The `devserver` service runs `tools/devserver.mjs` on port 8790; the `dev` service shares its network, so `localhost:8790` works on the host and in `dev`.

    ./scripts/dev.sh                           # shell in the dev container (repo at /work); also starts devserver
    ./scripts/dev.sh <command>                 # run one command, e.g. ./scripts/dev.sh ./scripts/setup.sh
    ./scripts/dev.sh ./scripts/check.sh        # Biome lint + format, Chromium 56 syntax, shellcheck, shfmt, unit tests
    ./scripts/dev.sh ./scripts/check.sh --fix  # apply lint fixes and formatting
    ./scripts/dev.sh node --import ./test/setup.mjs --test 'test/**/*.test.mjs'                 # unit tests
    ./scripts/dev.sh node --import ./test/setup.mjs --test --test-name-pattern='CueTrack' 'test/**/*.test.mjs'  # one test
    docker compose logs -f devserver           # TV logs from dev builds (also build/tv.log)
    npm run tizen-skills                       # on the host: install Samsung's tizen-sdk-skills for Claude Code

`npm run tizen-skills` installs Samsung's Tizen skills, agents and hooks into `.claude/` (gitignored; hooks go in `.claude/settings.local.json`), pinned in `tools/install-tizen-skills.sh`. `package.json` holds scripts only; the app has no npm dependencies.

Unit tests use Node's built-in `node:test` and `node:assert` (no npm). They import app modules directly from `app/js`. Modules that touch `document`, `window` or `localStorage` at load need small fakes for those globals in the test. Build globals come from `test/setup.mjs`.

`dev.sh` passes the host's LAN IP as `HOST_IP`; `setup.sh` uses it instead of the container's IP. `setup.sh` logs all tool output to `build/setup.log` and keeps the installer download in `build/downloads/`.

All TV commands read `.env` (made by `./scripts/setup.sh`): `TV_IP`, `TV_SDB_PORT`, `TIZEN_STUDIO`, `TIZEN_SIGN_PROFILE`, `DEV_HOST`, `DEV_SKIP_LOGIN`, `PLEX_SERVER_URL`, `TV_REMOTE_TOKEN`.

    ./scripts/setup.sh                # one-time: Tizen CLI, find TV, signing cert
    ./scripts/deploy.sh               # release build → package → install → launch
    ./scripts/deploy.sh --dev         # dev build: perf overlay, logs, remote control
    ./scripts/deploy.sh --build-only  # only write build/app (no TV needed)
    ./scripts/deploy.sh --package-only  # signed build/samsucks.wgt, no TV needed
    ./scripts/deploy.sh --no-run      # install, do not launch

A release build runs on the TV alone: it needs no dev host. Install it once from any computer with Developer Mode on the TV pointed at that computer, then turn Developer Mode off. An upgrade must use the same author certificate (the `samsucks` profile in the `samsucks-home` volume), or uninstall the app first.

Desktop browser: unbundled `app/` does not run (it needs the build globals). Run `./scripts/deploy.sh --build-only` (or `./scripts/build.sh`), then serve `build/app/` with any static server. The UI zooms the 1920×1080 layout to fit the window and uses `<video>` instead of AVPlay.

### Dev loop on the real TV
Chrome DevTools cannot attach to a retail TV. Dev builds talk to `tools/devserver.mjs` (port 8790) on `DEV_HOST`.

    docker compose up -d devserver                             # dev.sh starts it too; logs in build/tv.log
    curl 'localhost:8790/send?keys=down,right,enter'           # inject key actions
    tools/tveval.sh 'document.title'                           # run JS on the TV, print result
    tools/tveval.sh '__bench(["right","right"], 250)'          # fps / p50 / p95 / max frame times
    tools/tveval.sh "__css('.hero-art{display:none}')"         # live CSS A/B test
    node tools/remote.mjs KEY_DOWN:3 wait:500 KEY_ENTER        # real remote keys over the TV websocket

`DEV_SKIP_LOGIN=1` plus `PLEX_SERVER_URL` makes dev builds skip sign-in (server must allow unauthenticated LAN access).

## Build

`scripts/build.sh` (called by `deploy.sh`) copies `app/` to `build/app`, then bundles `js/main.js` with esbuild (`--format=iife --target=chrome56 --minify-syntax`) into one classic script, `build/app/js/main.js`, and removes `type="module"` from `index.html`.

Code reads four free globals that `build.sh` sets with esbuild `--define`: `__DEV__`, `__DEV_HOST__`, `__DEV_PLEX_URL__`, `__VERSION__`. Release: `__DEV__` false, host and Plex URL empty, version from `app/config.xml`. Dev (`--dev`): host from `DEV_HOST`; Plex URL from `PLEX_SERVER_URL` only when `DEV_SKIP_LOGIN=1`. `--minify-syntax` makes esbuild drop the dead dev branches, including the dynamic `import()` of `app/js/dev/`, so a release bundle holds no dev code. `check.sh` builds both bundles and fails if a release bundle contains `startDevRemote` or the devserver paths, or a dev bundle lacks `startDevRemote`.

Never edit `build/`. Load `app/js/dev/` only by dynamic `import()` behind `__DEV__` (as `app.js` does). Unit tests run with `node --import ./test/setup.mjs`, which sets the four globals to release values. App version, app ID and `required_version` live in `app/config.xml`.

## Architecture (app/js)

- `main.js` → `app.js` `boot()`: restores the session from `util/store.js` (localStorage, `ss.` prefix), paints Home from cache, then verifies the server in the background. A 401 sends the user to Login.
- Build globals: `__DEV__`, `__DEV_HOST__`, `__DEV_PLEX_URL__` and `__VERSION__` are free globals, not imports. There is no config module. Gate dev-only code on `__DEV__` so the bundler removes it from release builds.
- `router.js`: a screen stack. A screen is `{ el, onKey(action) -> bool?, onShow?, onHide?, destroy? }`. Screens below the top stay in the DOM, hidden, so Back is instant. Unhandled keys go to the global handler, then `back`.
- `nav.js`: the one place that opens screens. Screens import `nav.js`, not each other.
- `input.js`: maps keys to actions via `platform/tizen.js`. Arrow actions apply at most once per animation frame (extra presses collapse). A held key adds `.fast` to `<html>` to shorten transitions. `inject()` feeds the dev remote through the same path.
- `session.js`: token, user and current `Server`; `reconnect()` re-resolves the server URI from plex.tv.
- `plex/`: `client.js` (identity headers, also sent as query params because AVPlay cannot send headers), `auth.js` (plex.tv PIN sign-in, server discovery), `server.js` (Plex Media Server API).
- `platform/player.js`: one player API with two backends: Samsung AVPlay on the TV, `<video>` elsewhere.
- `ui/`: `row.js` and `grid.js` are virtualized. They reuse a fixed pool of tiles and move the track by `transform`; the focus ring stays still and content slides under it. `backdrop.js` draws the background as a 2×2 WebGL texture.

## Performance rules

The TV CPU is slow; the README records measurements. Keep these rules:
- Animate only `transform` and `opacity`. Never repaint large areas. A full-screen CSS gradient cost about 2 s per frame.
- Do not create DOM nodes while scrolling; reuse pooled tiles.
- Request images from Plex at the exact on-screen pixel size.
- Measure a UI change on the TV with `__bench` before and after.

## Plex quirks

- PMS 1.42 returns 400 for `start.m3u8` unless `/video/:/transcode/universal/decision` ran for the same session first.
- Send `X-Plex-Platform=Samsung`, not `Tizen`. `Tizen` selects the official app's server profile, which rejects these transcode requests.
- Samsung TVs from 2018 on cannot decode DTS. Plex copies the video and converts only the audio to AC3 5.1.

## Target

Tizen 4.0+ (2018 TVs, Chromium 56; the dev TV is a 2018 NU7090). The README measurements come from a 2022 Q60B (Tizen 6.5, Chromium 85). Chromium 56 has no ES modules, so the source runs on the TV only after bundling. esbuild lowers syntax to Chromium 56 but adds no polyfills: check every new web API and CSS feature against Chromium 56. `app/js/vendor/qrcode.js` is third-party; do not edit it.

## Agent skills

### Issue tracker

Issues are local markdown files under `project/<feature>/`. See `docs/agents/issue-tracker.md`.

### Triage labels

The five default labels, written as `Status:` lines in issue files. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
