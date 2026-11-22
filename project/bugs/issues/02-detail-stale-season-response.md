# Detail screen can apply a stale season response

Status: needs-triage
Source: `notes/architecture-deepening.html`, candidate 5

## Problem
`app/js/screens/detail.js` guards async results with the `alive` flag only. `alive` is false only after the screen is destroyed. It does not detect a newer request.

Three paths can start overlapping loads:
- Season switch: `onKey` calls `loadEpisodes(seasons[seasonIndex])` on each left or right press (`detail.js:266`).
- `toggleWatched` calls `load()` (`detail.js:192`).
- `onShow` calls `load()` when the user returns from the player (`detail.js:222`).

`loadEpisodes` (`detail.js:137`) writes `episodes.items` after its `await`. A slow response for an old season can arrive after a newer one and replace the episode row.

## Failure scenario
1. The user presses right twice on the season bar. Two requests start: season 2, then season 3.
2. Season 3 responds first and renders. Season 2 responds second and overwrites the episodes.
3. The season bar shows season 3. The episode row shows season 2.

## Fix notes
- Fix test-first (`/tdd`): fake `session.server.children` with a slow first response and a fast second. Assert that the last request wins.
- Library and Search already use a generation counter. Candidate 5 proposes one shared latest-request helper; apply the deletion test before building it. A local counter in `detail.js` is enough for this ticket.
- Home has no guard; note it, do not fix it here.
