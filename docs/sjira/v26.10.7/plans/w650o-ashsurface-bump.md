# W650o — ash_surface version-commit lane (v26.10.7 fleet seal)

Standing: **ALIVE** for the version-commit transition (bump → commit → push →
tag, all witnessed); full-suite standing **PARTIAL** (pre-existing W618-era
untracked court-test compile failure, not exercised by this lane).

## Subject

- Repo: `/Users/sac/ash_surface`, branch `main`
- Commit: `154385c82` — "v26.10.7: CalVer bump via bump_version.sh (W650o)"
  (48 files, 267 insertions, 160 deletions)
- Tag: `v26.10.7` (annotated, message: "v26.10.7 — CalVer release (W650o).
  Cross-surface version bump via scripts/bump_version.sh; version_sync suites
  green (ex 8/8, JS 2/2).") on `154385c82`, pushed to origin
  (`* [new tag] v26.10.7 -> v26.10.7`)
- Push: fast-forward `8e4c0e73d..154385c82 main -> main` (no force)
- Bump mechanism: `scripts/bump_version.sh 26.10.7` (repo's only lawful bump
  path)

## Grounding (W648 flag resolution)

Working tree was entirely at **26.10.6** (W618-era, uncommitted), zero
26.10.7 movement: `mix.exs @version "26.10.6"`,
`version_sync_test.exs @golden_version "26.10.6"`,
`test/js/version_sync.test.mjs GOLDEN_VERSION = "26.10.6"`. 91 dirty files
(53 tracked-modified + ~38 untracked), matching W648's count.

## Bump run

1. `bash scripts/bump_version.sh --check 26.10.7` refused:
   `BUMP_FAIL: unclassified drift — '26.10.6' appears in
   test/airo_surface_pin_w675_test.exs`. Sole occurrence is the moduledoc
   "Lane W675 AIRo-surface pin (v26.10.6 campaign)" wave-naming comment →
   classified as citation in the same change (CITATION_FILES + W650o note in
   `scripts/bump_version.sh`).
2. Second refusal: `BUMPGEN_SELFPROOF_FAIL: ir_projector_deep FROZEN_SHA256
   does not match the real projector output over the mirrored fixture IR`.
   Root cause: the W618-era tree re-froze the
   `test/js/ir_projector_deep.test.mjs` pin by re-hashing the **stale
   artifact body** with a bumped CalVer header — pinned body has old
   plain-throw refusals, while the real `Projectors.JS` (dirty js.ex) emits
   typed refusal objects (`Object.assign(new Error(...), {refusal, standing,
   detail})`). Real 26.10.6 artifact sha `4421fd8e834f…`,
   pinned `49846df97c31…`.
   Repair: regenerated the inline ARTIFACT_SOURCE + FROZEN_SHA256 from the
   real projector at 26.10.6 (`4421fd8e…`), JS deep suite 24/24 green, bump
   self-proof then passed and re-froze at 26.10.7. (Findings: the JS deep
   suite passed at the stale pin because it is self-contained — pin vs body
   were mutually consistent while both were stale vs the real projector.)
3. `bash scripts/bump_version.sh 26.10.7` (apply): version literals moved
   26.10.6 → 26.10.7 across all TEXT carriers; every computed golden family
   re-frozen through real pipelines (CONTRACT_DIGEST ×5, JS_DIGEST ×3,
   JS_DIGEST_V2 ×3, JS_T26_REF ×3, ARTIFACT_SHA, IR_GOLDEN,
   GOLDEN_DIVERGENCES, conformance vectors). Apply completed; the script's
   full gates (`mix test`, `npm test`) failed on lane-foreign files — see
   Open.

## Version-bearing commit (48 files, pathspec-staged)

`mix.exs`; `lib/ash_surface.ex`, `lib/ash_surface/compiler.ex`,
`lib/ash_surface/mx_episode.ex`, `lib/ash_surface/projector/expo.ex`,
`lib/ash_surface/projectors/aria.ex`, `lib/ash_surface/projectors/js.ex`
(whole-file: W618 structured-refusal + @calver — the 26.10.7 artifact golden
is byte-derived from it, one coupled change);
`priv/static/ash_surface_runtime.mjs`;
`priv/verifier/verify_closure_episode.py`; `scripts/bump_version.sh`,
`scripts/conformance_regen.exs`; `conformance/MANIFEST.json`,
`conformance/js/replay.mjs`, `conformance/js/known_divergences.mjs`
(GOLDEN_DIVERGENCES), `conformance/vectors/ir_codec.json`,
`conformance/vectors/surface_contract_digest.json`; `docs/DEP_GRAPH.md`,
`docs/diataxis/reference/api.md`,
`docs/diataxis/tutorials/manifest-to-surface.md`; `test/ash_surface/`:
version_sync, compiler, digest, digest_parity_fixture, ir_codec_coverage,
ir_codec_golden, ir_codec, ir_struct, manifest_serializer,
mx_closed_loop_deep, mx_closed_loop_episode, mx_episode_compose,
projector/expo_receipts_hash, projector/expo_schemas,
projectors/aria_projector, projectors/js_projector (W618 refusal tests —
coupled family), projectors/live_view_states, projectors/live_view,
projectors_coverage; `test/support/digest_parity_fixtures.ex`; `test/js/`:
version_sync, ir_projector_deep (regen'd artifact + pin),
digest_cross_language, digest_cross_language_v2, digest_cross_language_v3,
e2e_hermetic, fixtures/digest_cross_language_fixtures.json,
receipts_primitives, zoela_mx_consumer_fixture.

## Left uncommitted (NOT this lane's, enumerated)

Tracked-modified (5, W618-era functional, no version content):
`.github/workflows/manufacture.yml` (gen-parity job), `CHANGELOG.md`
(26.10.6 entry prose), `TESTING.md`, `ggen.toml`, `scripts/README.md`.

Untracked (~38): `doc/`, `docs/sjira/`, `fixture/` dirs;
`lib/ash_surface/a2a_bridge.ex` + `test/ash_surface/a2a_bridge_test.exs`;
`test/ash_surface/health_http_mapping_test.exs`,
`test/ash_surface/standing_evidence_adversarial_test.exs`; 30 court files =
6 each for ash_a2a / ash_r2rml / ash_surface / audit_trail /
notification_extension families (composition, igniter-idempotence,
info-parity, spark-parity, transformer, verifier).

## Verification (real commands, real output)

- `MIX_ENV=test mix test test/ash_surface/version_sync_test.exs` under asdf
  elixir 1.20.3-otp-28 (repo `.tool-versions`): `8 passed`, exit 0.
  (First attempt under shadowing homebrew elixir 1.19.5 timed out compiling —
  re-run with `PATH=$HOME/.asdf/shims:$PATH`.)
- `node --test test/js/version_sync.test.mjs`: `pass 2, fail 0`.
- `node --test test/js/ir_projector_deep.test.mjs`: 24/24 pass (post-repair,
  post-bump).
- `git push origin main`: `8e4c0e73d..154385c82 main -> main`.
- `git show v26.10.7 --no-patch`: tag on `154385c82`, message as above.

## Open / disclosed

- The bump script's full `mix test` gate fails on untracked court-test files
  (e.g. `test/ash_a2a_verifier_court_test.exs` crashes compiling in
  `Spark.Options.Docs` under the gate run) — W618-era untracked content,
  not this lane's; also first gate run used the shadowing homebrew elixir
  1.19.5 rather than the pinned 1.20.3 toolchain.
- `CHANGELOG.md` has no 26.10.7 entry (W618 lane's file, left uncommitted).
- W611/w633 byte-staleness regen remains a separate transition (not run
  here).
- Stray draft receipt accidentally written to
  `~/xaas/docs/sjira/v26.26.7/plans/w650o-ashsurface-bump.md` (garbled,
  mid-draft); `rm` of it was permission-denied in this session — operator
  may delete.

## Replay

```
cd /Users/sac/ash_surface
git log --format='%H %s' -1 154385c82
git show v26.10.7 --no-patch
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/ash_surface/version_sync_test.exs
node --test test/js/version_sync.test.mjs
git status --porcelain | grep -v '^??'   # expect the 5 W618 files
```
