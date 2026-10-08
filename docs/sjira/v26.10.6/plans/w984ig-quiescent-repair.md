# W984ig — quiescent_stop FRIA assertion repair receipt

- Lane: W984ig, canonical checkout /Users/sac/xaas, branch feat/playwright-surface. No commit.
- Repairs the defect flagged in `w984fq-probe.md`:
  `test/xaas/actuation/quiescent_stop_deepening_test.exs:203` asserted
  `Enum.any?(fria.rights, &(&1.status == :OPEN_GAP))` against a lib that has
  (post-W984eb) all five fria/0 rights `:EVIDENCED` — assertion contradicts lib.

## Verify-on-disk first

- `lib/xaas/semantics/oversight_governance.ex` fria/0: five `status: :EVIDENCED`
  sites (lines 281/305/320/334/354); authority-channel entry
  (`:access_to_effective_remedy_authority_channel`, ~line 337) cites
  `lib/xaas/semantics/incident_report.ex` (+ transmit/1 :PREPARED_NOT_TRANSMITTED).
  Confirmed before any edit. Matches `w984eb-probe.md`.
- Baseline run (pre-edit file, lane build root `_build-laneW984ig`): the file is
  `@moduletag :eu_ai_act`, so under default `mix test` the 7 tests are excluded
  (0 tests, 7 excluded, exit 0 — two runs, consistent). This explains why the
  stale assertion never failed in the default loop; it must be run with
  `--include eu_ai_act`.

## Edit (1 file)

`test/xaas/actuation/quiescent_stop_deepening_test.exs` — FRIA composition test:
- stale `Enum.any?(fria.rights, &(&1.status == :OPEN_GAP))` removed;
- `Enum.all?` tightened from `status in [:EVIDENCED, :OPEN_GAP]` to
  `status == :EVIDENCED`;
- binding court now asserts the authority entry
  (`:access_to_effective_remedy_authority_channel`) is `:EVIDENCED` and cites
  `lib/xaas/semantics/incident_report.ex` (same pattern as
  `test/xaas/deepening/art_27_1f_materialisation_safeguard_binding_test.exs`);
- moduledoc-prose in the test comment updated (post-W984eb, all five
  :EVIDENCED; channel typed-honest via transmit/1).

## Gates (real output, build root `_build-laneW984ig`)

1. Touched file + sibling: `mix test test/xaas/actuation/quiescent_stop_deepening_test.exs test/xaas/actuation/quiescent_stop_test.exs --include eu_ai_act` → **12 passed, exit 0.**
2. Sibling quiescent_stop court green (included above); extended to
   `test/xaas/actuation` + `test/xaas/deepening` → **119 passed, exit 0.**
3. Full eu_ai_act census: `mix test test/eu_ai_act --include eu_ai_act` →
   **1388/1389 passed**; the 1 failure is the intentional Art. 49.3
   flunk-by-design OPEN_GAP marker (known intentional contract, same as
   W984eb's census finding of 1355 passed / 1 OPEN_GAP marker).
4. Mock gate: `scan_mock_usage(["test","lib"])` → **`[]`**.

## Census notes (W672 law)

No foreign compile-aborts hit my runs. Unrelated warning noise
(PromEx/Grafana nxdomain, expected in lane builds) ignored.

## Cleanup

- Build-root lease: `rm -rf _build-laneW984ig` → done, directory removed (not denied).
- No commit (per lane contract).
