# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

SamSUCKS is a Plex client for Samsung Tizen TVs. Plain ES modules, no framework, no npm, no bundler, no build step beyond a copy. There are no tests, linter or formatter.

## Commands

All TV commands read `.env` (made by `./scripts/setup.sh`): `TV_IP`, `TV_SDB_PORT`, `TIZEN_STUDIO`, `TIZEN_SIGN_PROFILE`, `DEV_HOST`, `DEV_SKIP_LOGIN`, `PLEX_SERVER_URL`, `TV_REMOTE_TOKEN`.

    ./scripts/setup.sh                # one-time: Tizen CLI, find TV, signing cert
    ./scripts/deploy.sh               # release build → package → install → launch
    ./scripts/deploy.sh --dev         # dev build: perf overlay, logs, remote control
    ./scripts/deploy.sh --build-only  # only write build/app (no TV needed)
    ./scripts/deploy.sh --no-run      # install, do not launch

Desktop browser: run `--build-only`, then serve `build/app/` with any static server. The UI zooms the 1920×1080 layout to fit the window and uses `<video>` instead of AVPlay.

### Dev loop on the real TV
Chrome DevTools cannot attach to a retail TV. Dev builds talk to `tools/devserver.mjs` (port 8790) on `DEV_HOST`.

    node tools/devserver.mjs                                   # logs to stdout and build/tv.log
    curl 'localhost:8790/send?keys=down,right,enter'           # inject key actions
    tools/tveval.sh 'document.title'                           # run JS on the TV, print result
    tools/tveval.sh '__bench(["right","right"], 250)'          # fps / p50 / p95 / max frame times
    tools/tveval.sh "__css('.hero-art{display:none}')"         # live CSS A/B test
    node tools/remote.mjs KEY_DOWN:3 wait:500 KEY_ENTER        # real remote keys over the TV websocket

`DEV_SKIP_LOGIN=1` plus `PLEX_SERVER_URL` makes dev builds skip sign-in (server must allow unauthenticated LAN access).

## Build

`deploy.sh` copies `app/` to `build/app`, then:
- dev: rewrites `build/app/js/config.js` (`DEV`, `DEV_HOST`, `DEV_PLEX_URL`, `VERSION`).
- release: deletes `js/dev/` and sets `VERSION` from `app/config.xml`.
- both: injects a `<link rel="modulepreload">` for every module into `index.html`.

Edit `app/js/config.js` only for defaults. Never edit `build/`. Release builds delete `app/js/dev/`, so load those files only by dynamic `import()` behind `DEV` (as `app.js` does). A static import breaks release builds. App version and app ID live in `app/config.xml`.

## Architecture (app/js)

- `main.js` → `app.js` `boot()`: restores the session from `util/store.js` (localStorage, `ss.` prefix), paints Home from cache, then verifies the server in the background. A 401 sends the user to Login.
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

Chromium 69+ on Tizen 5.5+ (tested: 2022 Q60B, Tizen 6.5, Chromium 85). Check new JS and CSS features against that engine. `app/js/vendor/qrcode.js` is third-party; do not edit it.
