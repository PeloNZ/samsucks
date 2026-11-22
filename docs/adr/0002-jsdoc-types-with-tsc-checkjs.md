# Types are JSDoc checked by tsc, not .ts sources

Sources stay `.js`. Types live in JSDoc comments and `.d.ts` files, and `tsc --checkJs --noEmit` checks them with `lib: ["ES2017", "DOM"]` (pinned in the Dockerfile). We rejected `.ts` sources: they stop unbundled `app/` from running in desktop Chrome, need Node type-stripping flags for `node --test`, and rename 3,900 lines. The types carry over if we move to `.ts` later.

`lib: ["ES2017"]` also flags JS built-ins newer than Chromium 56 (for example `.flat()`). It does not flag DOM APIs; `check.sh` needs a deny-list for those.
