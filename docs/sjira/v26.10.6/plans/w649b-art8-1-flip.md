# W649b — Art. 8.1 umbrella flip: OPEN_GAP → EVIDENCED

Lane W649b, EU-AI-Act wave. Subject: `/Users/sac/xaas` @ `feat/playwright-surface`
(canonical checkout, lane build root `_build-laneW649b`).

## Classification (only entry touched)

`8.1` — the Section-2 umbrella requirement. Its text imposes compliance with the
Section's requirements "as required" by the risk-management system of Art. 9; its
substance is entirely discharged by the Art. 9-15 implementations. Every child
seam is EVIDENCED in the same file (`test/eu_ai_act/title_iii_test.exs`):

| child | line_id(s) | seam |
|---|---|---|
| Art. 9 (risk) | `9.1`-`9.2.d`, `9.5.a/b`, `9.6`, `9.8` | ferroplan inverse-reachability safe-set (`/Users/sac/ferroplan/crates/ferroplan/src/reachability.rs`) + mutant court |
| Art. 10 (data) | `10.2.f/g/h`, `10.2`, `10.2.e`, `10.3` | dataset admission gate (`lib/xaas/semantics/dataset_admission.ex`) |
| Art. 11/12 (docs/logs) | `11.1`, `12.1`, `12.2`, `12.2.a/b/c` | hash-chained audit chain (`lib/xaas/witness/audit_chain.ex`) + OCEL (`lib/xaas/telemetry/ocel_ndjson.ex`) |
| Art. 13 (transparency) | `13.1`-`13.3.f` | counterfactual (`lib/xaas/semantics/counterfactual.ex`) + Shapley attribution (`lib/xaas/semantics/admission_attribution.ex`) |
| Art. 14 (oversight) | `14.1`-`14.4.e` | quiescent stop (`lib/xaas/actuation/quiescent_stop.ex`) + automation-bias countermeasure (`lib/xaas/semantics/automation_bias_countermeasure.ex`) |
| Art. 15 (robustness) | `15.1`, `15.3`, `15.4`, `15.5`, `15.4.s2`, `15.5.s2/s3` | robust margin (`lib/xaas/semantics/robust_margin.ex`), WASI SHACL gate (`/Users/sac/wasm4pm/crates/eu_gate`), declared metrics, vuln lifecycle |

Umbrella rule: **8.1 is evidenced iff its children are evidenced.** The flip
asserts exactly that: the EVIDENCED test reads this receipt and requires the
child line_id list below; the file's own generator resolves each child line_id
to EVIDENCED via `evidence_map`/`reclass_map`.

## Mechanism

`reclass_map` entry in `test/eu_ai_act/title_iii_test.exs`:

```elixir
"8.1" => {:evidenced, "W649b",
          "Section-2 umbrella: compliance discharged by the evidenced Art 9-15 children",
          ["lib/xaas/semantics/dataset_admission.ex",
           "lib/xaas/witness/audit_chain.ex",
           "lib/xaas/semantics/counterfactual.ex",
           "lib/xaas/semantics/admission_attribution.ex",
           "lib/xaas/actuation/quiescent_stop.ex",
           "lib/xaas/semantics/automation_bias_countermeasure.ex",
           "lib/xaas/semantics/robust_margin.ex",
           "/Users/sac/ferroplan/crates/ferroplan/src/reachability.rs",
           "/Users/sac/wasm4pm/crates/eu_gate"],
          "docs/sjira/v26.10.6/plans/w649b-art8-1-flip.md",
          "children evidenced: 9.1 9.2 9.2.a 9.2.b 9.2.c 9.2.d 9.5.a 9.5.b 9.6 9.8 10.2.f 10.2.g 10.2.h 10.2 10.2.e 10.3 11.1 12.1 12.2 12.2.a 12.2.b 12.2.c 13.1 13.3.b.vii 13.3.f 14.1 14.2 14.3 14.4.b 14.4.d 14.4.e 15.1 15.3 15.4 15.5"}
```

Ordering note: `compute/0` checks `reclass_map` first, so this entry wins over
the residual `open_gap` fallback for 8.1; no other entry is modified.

## Verification

```bash
PATH=$HOME/.asdf/shims:$PATH MIX_BUILD_ROOT=_build-laneW649b MIX_ENV=test \
  mix test test/eu_ai_act/title_iii_test.exs                      # green gate
PATH=$HOME/.asdf/shims:$PATH MIX_BUILD_ROOT=_build-laneW649b MIX_ENV=test \
  mix test test/eu_ai_act/title_iii_test.exs --include eu_ai_act_open_gap  # honest tail: 0 gaps
```

## Receipt

- Verdict: **8.1 EVIDENCED** (umbrella discharged by evidenced children).
- Child line_ids required evidenced:
  `9.1 9.2 9.2.a 9.2.b 9.2.c 9.2.d 9.5.a 9.5.b 9.6 9.8 10.2.f 10.2.g 10.2.h 10.2 10.2.e 10.3 11.1 12.1 12.2 12.2.a 12.2.b 12.2.c 13.1 13.3.b.vii 13.3.f 14.1 14.2 14.3 14.4.b 14.4.d 14.4.e 15.1 15.3 15.4 15.5`
- Title III open-gap count after flip: **0** (honest tail expected 0 failures).

### Tails

Baseline (pre-flip) tail: **BLOCKED** — the shared file was broken on disk by a
concurrent lane's mid-write (missing comma after the W648b `27.1.f` entry:
`SyntaxError ... title_iii_test.exs:233:7`), so no pre-flip run was possible;
the flip was applied on top of the mechanical comma repair. The pre-flip gap
inventory had 8.1 in the residual-rule OPEN_GAP set (default fallback, Art. 8
not in evidence/reclass/NA maps).

Post-flip green-gate tail (2026-10-07, lane build root `_build-laneW649b`):

```
$ MIX_BUILD_ROOT=_build-laneW649b MIX_ENV=test mix test test/eu_ai_act/title_iii_test.exs --include eu_ai_act --exclude eu_ai_act_open_gap
...
Result: 391 passed
```

Post-flip honest tail (open-gap tests explicitly included):

```
$ MIX_BUILD_ROOT=_build-laneW649b MIX_ENV=test mix test test/eu_ai_act/title_iii_test.exs --include eu_ai_act --include eu_ai_act_open_gap
...
Finished in 3.5 seconds (3.5s async, 0.00s sync)
Result: 391 passed
```

Zero open-gap flunks in the honest tail: **Title III open-gap count after the
flip = 0.**
