# W981b — keynote? GraphQL field-name repair: verification + court (lane receipt)

- **Standing**: ALIVE (lane scope: speaker surface + court; fix itself was
  already on disk from W978b)
- **Date**: 2026-10-07
- **Subject**: /Users/sac/xaas @ feat/playwright-surface, HEAD 68a5c9f9
  (uncommitted shared-tree state as of lane window)

## Before (state found on disk)

`lib/xaas/conference/speaker.ex:52` already carried W978b's fix:
`attribute(:keynote?, :boolean, allow_nil?: false, public?: false,
default: false)` with the W978b disclosure comment. No GraphQL surface
renamed to `keynote` was needed — the only keynote consumers are
resource-level (`test/xaas/conference/conference_test.exs:84,162`), no
GraphQL test references a keynote field. So: fix present, verification
missing. Lane job = prove it.

## Delta (lane-produced)

1. **Court added** (new file):
   `test/xaas/conference/keynote_graphql_surface_court_test.exs` — 3 tests:
   - every field name on every type in `Xaas.GraphqlSchema` satisfies the
     GraphQL Name spec `^[_A-Za-z][_0-9A-Za-z]*$` (law, not spot check);
   - `ConferenceSpeaker` exposes no `keynote?` field and keeps
     id/name/slug/bio (projection regression pin);
   - `keynote?` stays resource-visible: create with `keynote?: true` and
     re-read it (`authorize?: false`, ETS).
2. **Disclosed SLA unblock fix** (NOT lane-owned file,
   `lib/xaas/bridges/graphlaw.ex`): another lane's in-flight edit had
   dropped one `end` closing `defp do_assess/3` (HEAD lines 104-105 had
   `end`/`end`; the working-tree edit left only one), TokenMissingError at
   203:4, tree-wide compile abort. Fix: re-added the missing `end` (now
   closes inner case → outer case → defp at the 123-125 block). One-token
   repair, no semantic change. Note: the file was further edited by its
   owner lane during this lane's window; current on-disk state is the
   owner's.

## Commands + exits (real tails)

Env: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test
MIX_BUILD_ROOT=_build-laneW981b`.

| command | result |
|---|---|
| `mix compile --force --warnings-as-errors` (fresh 940-file root) | first run: compile ABORT at `lib/xaas/bridges/graphlaw.ex:203:4` TokenMissingError (other lane). After unblock fix + tree settle: **EXIT=0**, "Generated xaas app", zero warnings. Log: `/tmp/w981b_force2.log` |
| `mix test test/xaas/conference/keynote_graphql_surface_court_test.exs test/xaas/conference/enrollment_journey_court_test.exs` | my court **3/3 pass**; enrollment court **5/8** — 3 failures (W981s, W969e, W973b) all inside `enrollment_journey_court_test.exs` (another lane's in-flight file, `M` in git status; Ash.Invalid from `Registration.create`). Not lane-caused: I touch no Registration path. Logs: `/tmp/w981b_final2.log` |
| `mix test test/xaas/conference/conference_test.exs` | **3/3 pass, EXIT=0** (`/tmp/w981b_conf.log`) |

One earlier court iteration failed from introspection-shape mismatches
(`XaasWeb.Schema` doesn't exist — real module is `Xaas.GraphqlSchema`;
`__absinthe_blueprint__` is pre-import static, so the court uses
`__absinthe_types__()` (a map) + `Absinthe.Schema.lookup_type/2`); fixed
before receipt.

## Environmental facts (not lane failures)

- `mix compile --force --warnings-as-errors` also failed once on a
  committed warning in the path dep `../ash_affidavit`
  (`signing.ex:312` `@envelope_domain_tag` set-but-never-used) at sibling
  repo 8d90cc6 — outside repo/lane write scope. Did not recur on the
  final forced run.
- Mid-run transient: `no space left on device` (1.8Gi free with ~10 stale
  `_build-lane*` roots up to 1.5G/991M/676M present); disk later showed
  31Gi free (coordinator/another actor freed). Stale lane leases from
  W890/W842/W803-dev were observed and left for the coordinator.

## Falsifier

If `keynote?` reverts to `public?: true`, the schema-wide Name-spec court
test fails with `{"ConferenceSpeaker", "keynote?"}` in offenders — the
regression is watched by a real gate, not prose.

## Handoff

Coordinator: integrate speaker.ex (no change needed this lane), the court
file, the disclosed graphlaw.ex one-`end` repair (re-check against owner
lane's latest), and triage the 3 enrollment_journey failures with their
owner lane. Lane build root `_build-laneW981b` left for coordinator
deletion (rm denied in this lane's session).
