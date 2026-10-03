# XAAS-DOD — v26.10.2 docs Definition-of-Done draft (lane C6)

DRAFT ONLY. The repo's `CHANGELOG.md`, `README.md`, and `docs/claude/diataxis/**` are
USER-DIRTY — this file is the material for the coordinator/user to apply, not an
instruction to edit those files. All commit anchors witnessed on `main` @ `4b848624`.

## 1. Coverage assessment: does `[Unreleased]` cover v26.10.2?

**No — zero of the seven v26.10.2 capabilities appear in `[Unreleased]`.** The current
`[Unreleased]` (user's uncommitted edit adding the whole section) documents the
v26.9.30-wave features (sequenced drain, OCPM, bridge `admit/3` semantic evidence,
`Xaas.Fabric`, stale-plan gate, `run_suspended`), none of them v26.10.2.

| v26.10.2 capability | anchor | in `[Unreleased]`? |
|---|---|---|
| Live bridge on hex 26.10.1 | `2517f626`, `7dc90027` | no |
| fleet-R v2 projection | `a3613404` | no |
| plan-next + `admit/2` seam | `ff40f495`, `4b848624` | no |
| crown `:snapshot` binding | `2928abd4` | no |
| semantic-crown CI job | `bd7c0ad9` | no |
| env-honest drive tests | `eb5928eb` | no |
| ggen_igniter hex floor | `7dc90027` | no |

## 2. DRAFT CHANGELOG section

Insert after the existing `[Unreleased]` section (renaming per convention — the
existing released sections use `## [v26.9.28]` / `## [v26.9.25]` style):

```markdown
## [v26.10.2]

- Live SemanticJiraBridge on hex ggen_igniter 26.10.1 (`2517f626`, `7dc90027`): the
  post-G1 seam is real — mix.exs drops the post-G1 git pin for
  `{:ggen_igniter, "~> 26.10.1"}` (hex ships public `event_digest/1` +
  `legacy_event_digest/1`, the snapshot-bound descriptor contract carrying
  `admitted_work_order`/`digest_form`, 3-key requires, receipts-v2 law); the compile
  guard now requires BOTH public digest functions (`derives?/1` calls
  `legacy_event_digest/1` unconditionally, so an event_digest-only release would
  compile and crash at first log read); the echoed bridge map full-aligns to ggen's
  ten-key list (`snapshot_digest` → `source_snapshot_digest` in the bridge map only —
  the receipt-contract key is unchanged); `verified_events/1` converts TransitionLog
  refusals into `{:log_untrusted, _}` instead of raising; 101-test bridge suite green.
- fleet-R v2 execution keys in RProjection (`a3613404`): receipts now carry
  `work_order_id` (same resolution as identity.subject), `origin_authority` (mirror of
  authority), `provider`, and `provider_execution_id` (native run_id, fail-closed to
  the ext native run_id); `native/court` moved under `provider_ext.xaas`, no legacy
  fallback; laws V2-1..V2-4 each with a typed refusal and a mutant test; the three
  committed episode `.r.json` fixtures hand-extended (epochs gone from both fabric
  DBs — regeneration would falsify the reference; seal chains intact), fleet
  validator ADMITTED x3 (was REFUSED x3).
- plan-next (`ff40f495`, `4b848624`): a promote event drives one real
  `AshA2A.Replan.Loop` over the ash_pplan FOND port. `Xaas.Ultracode.SemanticDrive.PlanNext`
  is pure across `domain/1`, `plan/2`, and `to_work_order/2`; the `admit/2` seam is
  the opt-in bounded-consumption step (`SemanticJira.admit_work_order/1` + optional
  SHACL) — the drive does not call it; the drive's `:plan_next` step stays
  journal-only (`plan_next.json` + `PolicyCandidateEmitted` OCEL event, emitted never
  auto-admitted), underdetermined candidates refuse, non-progressable to-standings
  refuse. `mix xaas.episode --plan-next` is default OFF — committed episodes reproduce
  bit-identically.
- crown binds `:snapshot` (`2928abd4`): `@descriptor_binding :graph` → `:snapshot` —
  the pinned emitter (ggen_igniter e9c7afa) carries `admitted_work_order` +
  `digest_form` on every descriptor, so XaaS now refuses a descriptor rewritten
  between emission and materialize (the hole `:graph` left open); ticket-dir nil now
  raises the named `{:ticket_dir_missing, ...}` error (nil is deliberate under
  MIX_ENV=test — no config default).
- semantic-crown CI job (`bd7c0ad9`): weekly `.github/workflows/semantic-crown.yml` —
  the full crown loop (observe → SHACL admit → frontier → descriptor → Run/Epoch →
  worker → real fabric court → sealed receipt → ledger transition → dependent
  eligibility → fresh-OS-process replay) runs to standing ALIVE on real
  infrastructure, plus the negative control: a claimed-ALIVE vacuous candidate is
  sealed build_broken, refused by the reconciler, and leaves the work order on the
  frontier.
- env-honest drive tests (`eb5928eb`): `@foreign` now mirrors `build_erts/2`'s actual
  resolution (pin-first, then first ascending install holding `releases/<otp>` +
  executable `bin/erl` — never newest); cargo-absent skip arms with named reasons
  added to the two gated module conds — an under-provisioned runner yields a named
  skip, never a fake red (46 tests: 1 failure → 0).
- chore(release): ggen_igniter hex floor `~> 26.10.1`; VERSION 26.10.2 (`7dc90027`).
```

## 3. Diataxis sweep — present vs missing

Present reference pages (`docs/claude/diataxis/reference/`): `actuation-and-semantics.md`,
`ash-configuration.md`, `ex4pm-ontology-pin.md`, `http-api-surface.md`,
`sa2a-computation-boundary.md`, `ultracode-runtime-contract.md`.

Grep over all of `docs/claude/diataxis/` for `semantic.?crown`, `semantic_jira_bridge`,
`semanticjirabridge`, `plan.?next`, `semantic_drive`, `xaas.episode`, `semantic_receipt`,
`semantic_crown`: **zero matches.** The v26.10.2 capabilities have no diataxis
documentation at any layer (tutorials/how-to/explanation/reference).

Gaps (not authored here — DRAFT ONLY):

- `reference/semantic-crown.md` — the crown loop, `@descriptor_binding :snapshot`
  contract, `mix xaas.semantic.crown` exit semantics, the CI job's negative control.
- `reference/semantic-jira-bridge.md` — the compile guard's 3-conjunct seam contract
  (Shacl loaded, TransitionLog loaded, `event_digest/1` exported) plus the
  runtime-probed legacy arm (`derives?/1` probes `legacy_event_digest/1` at run time
  via `function_exported?/3` + `apply/3`, so a dep that has dropped the pre-v26.10.1
  function compiles warning-free and an old-rule log refuses as typed untrusted),
  ten-key bridge map, `source_snapshot_digest` key rename, hex 26.10.1 floor.
- `reference/semantic-drive-plan-next.md` — `PlanNext` purity, `admit/2`
  bounded-consumption seam, `mix xaas.episode --plan-next`, `PolicyCandidateEmitted`.
- `reference/r-projection.md` (or a section in an existing receipt page) — fleet-R v2
  execution keys, laws V2-1..V2-4, `provider_ext.xaas` placement.
- `how-to/run-the-semantic-crown-ci-job.md` — the weekly job's form choice (subprocess
  suite, not the mix task, because the task has no `worker:` injection flag).

## 4. VERSION / mix.exs consistency

- `VERSION` = `26.10.2`; `mix.exs:13` derives `@version` via
  `File.read!("VERSION") |> String.trim()` — consistent.
- Tag drift: last tag is `v26.9.29`; no `v26.10.x` tag exists. VERSION is ahead of the
  newest tag by two calver epochs (26.10.1 was released to hex per `mix.exs` comment
  and `7dc90027` but never tagged here), with 85 commits on `main` since `v26.9.29`
  (`git log v26.9.29..HEAD | wc -l` = 85). The drift is expected release-lag, not a
  mismatch — but the v26.10.2 release should cut its tag.

## 5. User-dirty diff summary (do not clobber)

`git status` @ `4b848624`: `CHANGELOG.md`, `README.md`, three diataxis reference files,
`test/xaas/ultracode/semantic_crown_test.exs` (not in scope to revert; +51/-3 — appears
to be the user's in-progress crown-test edit, untouched here).

- `CHANGELOG.md` — the entire `[Unreleased]` section is the uncommitted addition
  (6 bullets: sequenced drain `4daf2f98`, OCPM `c249c00d`, bridge `admit/3` semantic
  evidence `7ea89055`/`3730d761`, `Xaas.Fabric` family `7f0ac93d`/`eab1920a`, stale-plan
  gate `382bb9f7`, `run_suspended` `2a7d80df`/`67f46392`). All v26.9.30-wave content —
  keep, but it does not cover v26.10.2.
- `README.md` — one paragraph edited (the operate-it paragraph): adds `drain` to the
  `xaas.ultracode.*` list, adds `mix xaas.ultracode.drain` and `mix xaas.ocel.ocpm`
  descriptions, and bumps the MCP verb count eight → ten (`resolve_capability`,
  `surface`). All [Unreleased]-wave content; the v26.10.2 `mix xaas.episode --plan-next`
  capability is absent from it.
- `docs/claude/diataxis/reference/ash-configuration.md` — +5 lines: the
  `wave_loop_concurrency = 1` Oban queue note (`config/config.exs:107`, per-cwd lease
  serialization, `exit 65 lease_conflict`) and the opt-in adaptive-setpoint ceiling
  `:ultracode_wave_loop_concurrency_max`.
- `docs/claude/diataxis/reference/http-api-surface.md` — eight → ten MCP verbs;
  `resolve_capability` (capability-resolution court, bound handle or typed failure) and
  `surface` (lease's effective runtime surface) documented in the internal-API list.
- `docs/claude/diataxis/reference/sa2a-computation-boundary.md` — +2 lines: bridge
  `admit/3`'s optional `:semantic_evidence` opt (admitted before transport, typed
  refusal) and `Court.admit/2`'s `:stale_plan_refusal` preimage fence.
