# W125 — EP-A pre-AC-04 eligibility sweep (v26.10.6 convergence)

Lane: integration W125, repo `/Users/sac/xaas`, branch `feat/playwright-surface`
(no git actions taken). Adjudication consumed: W116 — ggen_igniter `23c36c8`
(AC-04) made `origin_authority` required at `admit_work_order/1`, so sealed
pre-AC-04 episodes (`fmt-1`, its EP-A/EP-B) lawfully refuse admission.

## 1. Sweep (grep + read)

`grep -rn "EP-A" test/ lib/ --include="*.exs" --include="*.ex" | grep -v semantic_drive_anchor`
→ 60+ references across 6 test files + lib builders. Classification:

| file | EP-A usage | verdict |
|---|---|---|
| `test/xaas/receipt/r_projection_consistency_test.exs` | finds EP-A row in work.json written by the AC-04-compliant lib builder (`Xaas.Ultracode.SemanticDrive.Episode` pins `origin_authority` at `lib/xaas/ultracode/semantic_drive/episode.ex:183`) | passes; no change |
| `test/xaas/ultracode/semantic_drive_plan_next_test.exs` | already passes `origin_authority:` explicitly and already pins its absence as refusal | passes; no change |
| `test/xaas/ultracode/origin_authority_test.exs` | asserts EP-A eligible **with** pinned origin digest, blocked without | passes; no change |
| `test/xaas/ultracode/semantic_drive_test.exs` | prepares episodes through the AC-04-compliant lib builder | no AC-04 signature; residual failures are environment noise (see §4) |
| `test/xaas/ultracode/machine_experience_test.exs` | prepares through lib builder | no AC-04 signature; environment noise |
| `test/xaas/ultracode/semantic_replay_test.exs` | consumes the **sealed pre-AC-04 episode `docs/sjira/v26.9.23/episodes/fmt-1`** (work.json carries no `origin_authority`) | 6 tests assumed admission eligibility → pin-flipped |

Root cause verified directly: replaying fmt-1's `work.json` yields
`refused_work_order(missing_required_field, "origin_authority")` for both
EP-A and EP-B; frontier eligible `[]`, all standings UNKNOWN, replay
`DIVERGED` / `REFUSED(identity_mismatch)` vs the committed pre-AC-04 record.

## 2. Pin-flips (only `test/xaas/ultracode/semantic_replay_test.exs`)

Each flip carries a comment citing the AC-04 drift (ggen_igniter `23c36c8`)
and the W116 adjudication:

1. **Cold replay** (`:72`): pre-AC-04 `KNOWN_REPLAY` + digest/state equality
   with the committed record → pinned `DIVERGED`, digest != recorded,
   all-UNKNOWN standings, `eligible == []`, every blocked reason containing
   `origin_authority`, `reconcile_refused`/`mu_on_O` divergence present,
   replay status `REFUSED`. Kept the digest determinism assertion
   (`digest == SemanticReplay.digest(state)`).
2. **F5 deleted receipt** (`:149`): `eligible == ["EP-A"]` → `[]` with the
   blocked-`origin_authority` all-query; exact-list divergence match →
   membership assert `{"unreceipted_transition", "R_missing_replay"}`.
3. **F6 covered/kept** (`:176`): `eligible == ["EP-A"]` → `[]`; exact-list
   divergence → membership `{"subject_changed", "R_missing_identity"}` (the
   covered case short-circuits at the subject check, so `reconcile_refused`
   is absent there — witnessed, not assumed); out-of-scope case pinned
   `DIVERGED` with `reconcile_refused` present and `subject_changed` refuted.
4. **CLI `mix xaas.replay`** (`:249`): base branch exit 0/`KNOWN_REPLAY` →
   exit 4/`DIVERGED`, digest != recorded; F5 copy branch and bad-flags
   exit 2 unchanged.
5. **Crown directory-ledger** (`:446`): reconcile "applied"/exit 0 → exit 1,
   `"status":"refused"` + `origin_authority` in output, no ledger dir
   created.
6. **Crown file-ledger** (`:489`): `{:ok, equal: true}` → pinned typed
   `{:error, {:frontier_failed, 1, ~s(["ledger_refused",
   ["event_digest_mismatch", 1]])}}`.
7. **Crown absent-ledger** (`:498`): `equal == true` + EP-A eligible →
   `equal == false` with all-UNKNOWN standings.

No lib edits, no git commands, no fixture regeneration (the sealed episode
under `docs/sjira/v26.9.23/episodes/fmt-1` is untouched — re-sealing it is a
separate admitted transition, not a test pin-flip).

## 3. Verification (real output)

Lane build root `_build-laneW125` (same-checkout fan-out; shared `_build` is
contested by a concurrent OTP-29 session). Final witnessed runs:

- `mix test test/xaas/ultracode/semantic_replay_test.exs` → **12/13 passed**;
  the 13th (`mix xaas.replay` CLI court) failed only under live
  shared-`_build` consolidation contention in that run and **passed twice
  with identical code** when run without contention (full-file run 6 and
  isolated run 9: `1 passed, 12 excluded`).
- Five other EP-A files:
  `mix test test/xaas/receipt/r_projection_consistency_test.exs test/xaas/ultracode/semantic_drive_plan_next_test.exs test/xaas/ultracode/origin_authority_test.exs test/xaas/ultracode/semantic_drive_test.exs test/xaas/ultracode/machine_experience_test.exs`
  → **89/95 passed**; 6 residual failures in `semantic_drive_test.exs` /
  `machine_experience_test.exs` carry **zero AC-04 signatures** (no
  `missing_required_field origin_authority` anywhere in the run) and
  co-occur with `corrupt atom table` while loading Hex inside the
  no-LLM subprocess (`env -i` forces the repo default `_build`, which a
  concurrent OTP-29 elixir 1.20.4 session is churning). These same tests
  passed in earlier runs (e.g. drive `no_delta` passed run 2, failed run 10)
  — contention-flaky, not AC-04 drift. Left untouched per lane rules.

## 4. Standing

- W125 sweep: **ALIVE** for its narrow claim — no xaas test other than the
  fmt-1 consumers still assumes EP-A is admission-eligible; the fmt-1
  consumers now pin the typed refusal.
- Residual UNKNOWN (pre-existing, session-external): 6 contention-flaky
  subprocess tests in `semantic_drive_test.exs` / `machine_experience_test.exs`
  plus the shared-`_build` CLI court under concurrent load; all
  environment-bound, none related to origin_authority law.
- Open work order (not this lane): re-seal `fmt-1` (or record an AC-04
  successor episode) so the sealed-episode replay courts regain their
  pre-AC-04 purpose; test-only pins cannot restore that purpose.

## W212 isolated verify

2026-10-06, integration lane W212. W125's pin-flip on
`test/xaas/ultracode/semantic_replay_test.exs` (12/13, CLI court contention-flaky on
shared `_build`) re-verified in isolation with a lane build root.

Command:
`MIX_BUILD_ROOT=_build-laneW212 PATH=$HOME/.asdf/shims:$PATH GGEN_IGNITER_DIR=/Users/sac/ggen_igniter MIX_ENV=test mix test test/xaas/ultracode/semantic_replay_test.exs`

- Run 1 (cold lane root, ~30 min compile, killed at background cap mid-protocol-consolidation
  with a stray write to shared `_build/test/...consolidated/...beam`): resumed in run 2.
- Run 2 (warm lane root): **12/13 passed**, 1 failure at
  `test/xaas/ultracode/semantic_replay_test.exs:292` (`assert code == 4, log`) —
  same CLI court, `170.4s`.
- Run 3 (warm lane root, full log `/tmp/w212_run3.log`): **13/13 passed, 0 failures**,
  `201.3s` sync, seed 15974. Log at 14:39:34 shows the full app booting clean
  (AshA2A legacy_compat warnings and PromEx/Grafana nxdomain uploads are pre-existing
  environment noise, not test failures).

Classification: the 13th test (CLI court, line 292) is **contention-flaky on the shared
`_build`, environment-bound — not a semantic pin failure**. On the isolated lane build
root it passes (13/13). No fixes made, no git operations. Lane build root
`/Users/sac/xaas/_build-laneW212` (438M) left in place; delete at integration per the
cleanup law.
