# W620 — OS-20 consolidation receipt (v26.10.6)

Lane: W620, v26.10.6 campaign. Date: 2026-10-06.
Method: on-disk verification (pattern count over `lib/**/*.ex`, dual-safe idiom =
`case Map.fetch` with `:error -> Map.put` within 5 lines), receipt cross-check against
`docs/sjira/v26.10.6/plans/w60{1,2,3,4,9}-*.md`, test-file existence checks.
Repos read-only this lane (beam4pm / ash_a2a / ash_pplan / ex4pm); sole write = this receipt.

## 1. Per-repo consolidated table

| repo | reliant sites patched (on-disk count / census) | regression test (exists) | suite status (from landed receipts) | lane receipt |
|---|---|---|---|---|
| beam4pm | **3 / 3** | `test/beam4pm_w601_map_update_dual_safe_test.exs` | 39/0 narrow; full **1562/1565, 3 failures — all pre-existing/gate-adjacent, classified in receipt §5** | `plans/w601-beam4pm-map-update.md` |
| ash_a2a | **14 / 14** | `test/ash_a2a/dual_safe_map_update_test.exs` | **3720 passed, 0 failures, exit 0** (prior ~3706 + 12 new guard tests) | `plans/w602-ash-a2a-map-update.md` |
| ex4pm | **36 / 36** (35 census + 1 post-census W609) | `test/w604_map_update_dual_safe_test.exs` + `test/w609_oracle_site_test.exs` | **896 passed, 0 failures, exit 0** (888 baseline + 8 new) ; W609 gates: 2 / 9 / 30 passed, no skips | `plans/w604-ex4pm-map-update.md`, `plans/w609-oracle-site.md` |
| ash_pplan | **8 / 8 on disk** (all 8 receipt sites witnessed in `git diff`) | `test/map_update_absent_key_test.exs` (on disk, 3452 bytes) | **PENDING — receipt §6 is still `(filled at run completion)`; no suite verdict recorded yet** | `plans/w603-ash-pplan-map-update.md` |

## 2. On-disk verification detail

Dual-safe `case Map.fetch` / `:error -> Map.put` counts over `lib/` (real grep output,
python multiline pattern, 2026-10-06):

```
beam4pm  sites: 3   files: 2
ash_a2a  sites: 14  files: 9
ex4pm    sites: 36  files: 15
ash_pplan sites: 8  files: 7
```

All four match the w525d census exactly (beam4pm 3, ash_a2a 14, ex4pm 35+1 W609,
ash_pplan 8). ash_pplan's 8 patches are present in the working tree (`git diff` covers
state_machine.ex:394, compiler.ex:200, fond.ex:396, fond/synthesis.ex:182+234,
workflow/model.ex:160, workflow/project/fond.ex:89, reactor/durable/migration.ex:440) and
the W291 protected files were not touched by this leg. Regression test files verified
present in all four repos.

## 3. Suite statuses (cited from landed receipts, not re-run)

- beam4pm (W601): narrow 39 passed / 0 failed; full 1562/1565, 147 skipped — 3 failures,
  all classified pre-existing/gate-adjacent (soak GenServer timeout, etc.).
- ash_a2a (W602): full suite 3720 passed, 1 skipped, 1032 excluded, exit 0.
- ex4pm (W604+W609): full suite 896 passed (2 doctests, 5 properties), 6 skipped,
  60 excluded, exit 0; W609 narrow gates 2/9/30 passed, no skips.
- ash_pplan (W603): compile exit 0 (152 files) recorded in receipt §4; §6 suite result
  line NOT yet filled — W603's suite verdict is the single open item.

## 4. Remaining work

1. **W603 suite verdict** — the ash_pplan patches + regression test are landed on disk,
   but the receipt's §6 result line is `(filled at run completion)`. W603 lane (or the
   coordinator) must fill it with the real `mix test` tail (private build root
   `_build-laneW603`, pinned toolchain). Nothing further is expected to change; the
   compile gate and idiom are identical to the three landed legs.
2. **Coordinator commit** — all four repos' working trees are uncommitted per lane
   contract; the coordinator owns the 4 per-repo commits (beam4pm, ash_a2a, ex4pm
   incl. w604+w609, ash_pplan incl. W603 once its verdict lands).

## 5. OS-20 closure

Site-level closure (verified on disk): **61 / 61** = 100%.
- beam4pm 3/3, ash_a2a 14/14, ex4pm 36/36, ash_pplan 8/8 — 61 dual-safe sites total.

Receipt-level closure: 4/5 lanes have verdict-bearing receipts (w601, w602, w604, w609);
**W603's verdict pending** → OS-20 closure = **80% receipts / 100% sites**.

Overall: **OS-20 is 4/5 legs ALIVE with witnessed suites, 1 leg (ash_pplan) patched and
compiled but awaiting its suite verdict line; remaining work = 1 receipt fill + 4
coordinator commits.**
