# W965 — Fleet SHA Fold into airo-wiring-ledger

**Lane**: W965. **Date**: 2026-10-07.
**Authority**: v26.10.6 campaign dispatch (post-W937 ledger refresh; W883/W937 receipts).
**Subject**: `/Users/sac/xaas/docs/cro/artifacts/airo-wiring-ledger.md` (docs-only;
no code, no commits, no build roots).

## What was done

1. Ran real `git -C <repo> rev-parse HEAD` per fleet repo (11 repos + the vendored
   submodule inside beam4pm). All match the W937 receipt's post-commit SHAs
   (`docs/sjira/v26.10.6/plans/w937-fleet-commits.md`).
2. Added a header note to the ledger: "Fleet SHAs updated post-W937 commit wave
   (W965, 2026-10-07); pre-commit SHAs in plans/w937-fleet-commits.md".
3. Added a "Fleet repo SHAs (post-W937 commit wave, W965)" table: repo | branch |
   full post-commit HEAD | wave-commit SHA | owning AIRo lane receipt.
4. Verified the beam4pm submodule gitlink is not dangling:
   `git -C beam4pm rev-parse HEAD:vendor/ggen-marketplace` =
   `6e4de9765e36392c09539afb1464e1eae4f9b2d8` = submodule HEAD.
5. Noted in the ledger that repos not touched by W937 (ash_a2a, ash_r2rml,
   ggen_igniter, ash_affidavit) retain their pre-wave HEADs.

The ledger's original consolidated table ("sha/parse proof" column) holds
artifact-content shas, not repo HEADs — no stale HEAD entries existed there to
overwrite; the fold lands as a new authoritative SHA table plus header note.

## Before/after SHA table (verified 2026-10-07)

| repo | branch | pre-commit HEAD (per w937) | post-commit HEAD (rev-parse, real) | wave commit |
|---|---|---|---|---|
| ggen-marketplace | feat/aaif-gcp-roadmap-v26.10.5 | 4bb5fbaff4ac… | `b58d7854142bacbd3aeffb83501646cae56c858a` | b58d78541 |
| ggen | feat/v26.10.5-release-cut | bc4d23909dbc… | `ba837d7437367dd84543c07b5179c88e214cbff4` | ba837d743 |
| beam4pm | main | 813eb924 | `560202484f5f61568e74fb0bfde13f6f6a67fdd2` | 56020248 |
| beam4pm/vendor/ggen-marketplace (submodule) | main | — | `6e4de9765e36392c09539afb1464e1eae4f9b2d8` | 6e4de9765 |
| ash_surface | main | d55c576d1 | `b70da9e1c2f5c3ff0bc61299b5a0dcc65bcdd1d3` | b70da9e1c |
| gymact | v26926/gymact-land-aloop-execution-kernel | 20b3fd7 | `2fa947cb71f91b6cfbc7f86cc5d69efc9f349337` | 2fa947c |
| autofde-lab | feat/doctrine-lab | 2a3d064e | `31e3decfbbbd2d0df8f5fb9085d5d9de32042911` | 31e3decf |
| wasm4pm | fix/v26.9.30-ci-fmt-tsc | 32deb59f6 | `d980a2a2941327a7d2b0bd892afbb2cf017e230e` | d980a2a29 |
| zcode-cli | fix/v26926-preview-publish-typed-skip | eb97f76 | `1e40596c6ce7ace3868484556827ff14e840f5a7` | 1e40596 |
| ex4pm | main | 46bfcc8 | `abac0d23e2a5517a13a605da514da417e651147a` | abac0d2 |
| ash_pplan | fix/ggen-verify-header | 7eeaaa1 | `343e52aebf299a18d12eb81e83c53df78650d15b` | 343e52a |
| ferroplan | main | c037876 | `e2c48d339cb084a94f0c5d6ae4cccc1904b74b1f` | e2c48d3 |

Dispatch noted "ash_pplan 7eeaaa1→? verify real": verified real post-commit HEAD is
`343e52a…` on branch `fix/ggen-verify-header`, matching the W937 receipt (commit
`343e52a`, "test: AIRo surface pin court (W682)"). 7eeaaa1 was the pre-commit HEAD.

## Commands / exits

```
for r in ggen-marketplace ggen beam4pm ash_surface gymact autofde-lab \
         wasm4pm zcode-cli ex4pm ash_pplan ferroplan; do
  git -C /Users/sac/$r rev-parse HEAD          # exit 0, all 11
done
git -C /Users/sac/beam4pm/vendor/ggen-marketplace rev-parse HEAD   # exit 0
git -C /Users/sac/beam4pm rev-parse HEAD:vendor/ggen-marketplace   # exit 0, == submodule HEAD
```

Edits: 1 Edit to the ledger (header note + SHA table section), verified on disk by
successful Edit application. No build roots created. No commits (per lane scope).

## Standing

ALIVE for the ledger fold: every SHA in the new table comes from a real
`git rev-parse HEAD` executed this session on the exact canonical checkouts;
each row matches the W937 receipt. No fabrication.

Open / out of scope: xaas-side integration commit of W883/W937/W965 artifacts
(reserved for coordinator); `ggen sync` re-projection against the new
marketplace pack commit.
