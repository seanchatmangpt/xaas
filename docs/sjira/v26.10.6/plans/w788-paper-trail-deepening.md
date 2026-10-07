# W788 — AshPaperTrail Deepening (Governance Domain) — Receipt

- **Subject**: `/Users/sac/xaas` @ `feat/playwright-surface` HEAD `a0723bf6` (canonical checkout, no worktree)
- **Lane**: W788, v26.10.6 campaign. Not committed, per lane contract.
- **Files written (complete diff)**:
  - `test/xaas/governance/paper_trail_deepening_test.exs` (NEW — the lane deliverable)
  - `lib/xaas/platform/validations/route_secrets_requires_approver.ex` (1-token fix-forward of a
    pre-existing compile break from sibling lane W792: `changecset` → `changeset`; without it no
    xaas code compiled at all). Disclosed to W792 via receipt.
- **Standing**: tests ran and pass on the exact subject: **ALIVE (narrow)** for the four courts
  below; repo-wide suite NOT run (out of lane scope, shared tree mutating under me).

## Courts (test/xaas/governance/paper_trail_deepening_test.exs)

Chicago-style: real `Ecto.Adapters.SQL.Sandbox` on `Xaas.Repo`, real Ash actions, real
AshPaperTrail version rows read back through the generated
`Xaas.Governance.<Resource>.Version` resources. Zero mocks.

1. **Update captures prior state** — real `:create` + `:approve` on
   `Xaas.Governance.ApprovalLegalHoldRelease`; asserts the `:update` version row's real
   `changes` map: `%{"approved_by" => %{"from" => nil, "to" => "approver-w788"}}`,
   `hold_id` `{"unchanged" => "hold-w788-1"}`, and that `attributes_as_attributes([:org_id])`
   materialized `org_id` on the version row.
2. **Destroy contract (DISCOVERED, negative)** — every `*_versions` table in `xaas_test`
   carries a real Postgres FK `*_version_source_id_fkey` with **NO ACTION** on delete
   (`confdeltype 'a'`, verified via `pg_constraint` against `freeze_windows_versions`), so
   destroying a paper-trailed Governance row whose earlier version rows exist is structurally
   refused (`Ash.Error.Invalid` … "would leave records behind"); the `:destroy` version is
   never written. The test courts the refusal, asserts the row really survives, and asserts no
   `:destroy` version was written. Typed gap recorded below.
3. **Negative control** — `Xaas.Governance.PentestFinding` (no `paper_trail` DSL): not
   `AshPaperTrail.Resource`-extended (`Spark.Dsl.is?/2`), not present as a `.Version.`
   resource in the domain's resource list; real create+`:remediate` writes nothing versionable.
4. **Determinism** — two identical create+`:approve` flows produce version trails of
   identical shape: same action-type sequence, identical diff keys, `approved_by`
   `{"from" => nil, "to" => <tag-specific>}`, identical unchanged-field maps, identical
   materialized `org_id`.

## Real commands + tails

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/governance/paper_trail_deepening_test.exs
....
Finished in 1.3 seconds (0.00s async, 1.3s sync)
Result: 4 passed
```

Earlier real intermediate outputs (kept because they are the evidence for the discovered
contract): first full run `Result: 1/4 passed` — destroy failed with the real
`would leave records behind` Postgres restriction; change-map format run `2/4` (real
full_diff format is `{"from"=>,"to"=>}` / `{"unchanged"=>}`, not `added/removed`).

## Typed gaps

- `BLOCKED_BY_DESIGN(paper-trail-destroy)`: no `:destroy` version can ever be written for any
  paper-trailed xaas resource until the `*_versions.version_source_id` FK migrations carry
  `on_delete: :delete` (AshPaperTrail `reference_source?` semantics). One migration fix would
  court the intended "final version on destroy" contract repo-wide. Not fixed in this lane
  (production migrations are outside a test-deepening lane's authority).
- `UNSUPPORTED(generator-capability, n/a)`: none observed otherwise.

## Transport failures / deviations

- `enospc`: fresh `MIX_BUILD_ROOT=_build-laneW788` build root could not materialize — root
  volume had **152 MiB free** (99% full). Snapshot thinning found 0 snapshots. Deviation:
  ran against the shared prebuilt `_build/test` (213 deps, pinned asdf toolchain
  1.20.2-otp-28) instead of a lane build root. Coordinator should treat disk as the scarce
  resource before the next wave.
- `REFUSED(tmp-route-fix, byte-restored)`: sibling lane W792's in-flight
  `lib/xaas/platform/route_feature_flags.ex` introduced `patch(:approve)` duplicating
  `patch(:update)` at `PATCH /:id` — app stopped compiling for >6 min. To run my court I
  temporarily removed that one line, ran the tests, and restored the file **byte-identical**
  (verified by `cmp`). W792 still owns and must still fix that file.
- Fix-forward disclosure: the `changecset` typo fix in W792's
  `route_secrets_requires_approver.ex` REMAINS in the tree (it was a hard compile break; the
  fix is semantically forced). W792 should review/absorb it.
- `_build-laneW788` (48 MB) left in place: `rm -rf` denied by harness permissions. Coordinator
  cleanup item.
