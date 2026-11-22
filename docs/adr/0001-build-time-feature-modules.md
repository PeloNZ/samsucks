# Features are modules registered at build time

New features (music, photos, Plex Home users, content-rating limits, library filters) are ES modules that register with the core at build time. esbuild bundles all of them into one script, and every build ships every feature. There are no runtime plugins and no second media backend: Plex is the only source. Runtime loading would add a loader to a Chromium 56 TV with a slow CPU, and nothing needs it.
