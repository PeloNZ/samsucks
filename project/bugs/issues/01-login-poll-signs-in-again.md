# Login poll signs in again after connect fails

Status: needs-triage
Source: `notes/architecture-deepening.html`, candidate 3

## Problem
In `app/js/screens/login.js`, the poll calls `finish(token)` inside the same `try` as `checkPin`. If `finish` throws (for example, the server connect fails), the `catch` logs "pin poll failed" and the poll schedules the next tick. The next tick calls `checkPin` again, gets the same token, and runs `finish` again. The sign-in sequence (`getUser`, `signIn`, `getServers`, `connect`, `useServer`) repeats every 2 s.

## Failure scenario
1. The user approves the PIN on plex.tv.
2. `checkPin` returns a token. `finish` signs in, then `connect` throws.
3. The catch logs "pin poll failed". The poll runs again in 2 s and repeats step 2.
4. The screen shows no real error, and the session is signed in again on every loop.

## Fix notes
- Fix test-first (`/tdd`): write a test that fails because `finish` runs twice after a connect error.
- `finish` must leave the poll `try`. A `finish` error must stop the poll and show an error with a retry.
- The login flow is hard to test inside the screen. Candidate 3 (a connection module that owns PIN poll, server pick and connect) removes the problem. If candidate 3 runs first, close this ticket as covered.
