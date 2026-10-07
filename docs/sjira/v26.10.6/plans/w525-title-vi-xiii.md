# W525 — Titles VI–XIII generator (Arts 57–113) — receipt

- Repo: /Users/sac/xaas @ feat/playwright-surface, lane W525, build root `_build-laneW525`
- Contract files (only writes): `test/eu_ai_act/title_vi_xiii_test.exs`, this receipt.
- Subject substrate: `docs/eu_ai_act/corpus.json` (W520), titles VI–XIII,
  **475 corpus lines**, generated at compile time (no hand-written per-line tests).
- Pattern mirrors W523 (Title III): three-state verdict per line, test ids
  `"EUAI-ACT <line_id>"`, OPEN_GAP tagged `:eu_ai_act_open_gap`.

## Mapping rules (honest, in cond order)

1. `@evidence` map hit → **EVIDENCED** (assert real paths on disk).
2. Consolidated-rendering placeholder text → NOT_APPLICABLE.
3. `addressee == "authority"` → NOT_APPLICABLE ("EU/national authority procedure — not a system obligation").
4. Art 86 (86.2/86.3) → OPEN_GAP (end-user-facing explanation surface, OS-16).
5. Art 73 (provider/both) → OPEN_GAP (no incident-reporting surface).
6. 74.12 / 74.13.a / 74.13.b → OPEN_GAP (provider-side market-surveillance cooperation).
7. 99.4.e → OPEN_GAP (Art 26 deployer duties, consistent with W523's Art 26 classification).
8. Arts 57–63 → NOT_APPLICABLE (voluntary sandboxes / support frameworks).
9. Arts 64–71 → NOT_APPLICABLE (AI Board / EU database machinery).
10. Arts 74, 75–94 → NOT_APPLICABLE (market surveillance / confidentiality / delegation, incl. Reg (EU) 2019/1020 cross-references).
11. Arts 95–96 → NOT_APPLICABLE (codes of conduct are explicitly voluntary).
12. Arts 97–98 → NOT_APPLICABLE (delegation / committee procedure).
13. Arts 99–101 → NOT_APPLICABLE (fine-setting discretion / penalties on Union institutions).
14. Arts 102–113 → NOT_APPLICABLE (entry into force / final provisions).
15. Default → OPEN_GAP (honest fallback; unreachable on the current corpus).

## Evidenced seams (all verified on disk 2026-10-06, HEAD d1db2b03)

| Lines | Verdict | Seam | Lane receipt |
|---|---|---|---|
| 72.1, 72.2, 72.3, 72.4, 72.4.s2 | EVIDENCED | OCEL telemetry surfaces (`lib/xaas/telemetry/ocel_{ndjson,envelope,ash_emitter}.ex`) + Art 72 token-replay conformance (`/Users/sac/beam4pm/lib/beam4pm_art72_conformance.ex`) | w511-art72-conformance.md |
| 86.1 | EVIDENCED | counterfactual explanation (`lib/xaas/semantics/counterfactual.ex` + test) | w506-art86-counterfactual.md |
| 99.3 | EVIDENCED | expected-zero-liability: fail-closed Art 5 refusal corpus (`lib/xaas/semantics/eu_ai_act_admission.ex` + test) | w236-refusal-capstone.md |
| 99.4 | EVIDENCED | typed gates / zero-liability posture (admission + authority decoupling) | w236-refusal-capstone.md, w471-pw-remint.md |
| structural pin (module-level test) | EVIDENCED | GPAI authority decoupling (∂Authority/∂Compute = 0) — the repo is not a GPAI provider/system, which discharges every GPAI-provider line by construction | w512-gpai-decoupling.md |

## Counts (expected, derived from corpus at generation time)

Total 475 lines → **EVIDENCED 8 · NOT_APPLICABLE 452 · OPEN_GAP 15** (+1 structural
pin test). OPEN_GAP breakdown: Art 73 ×9 (serious-incident reporting, no surface),
Art 74 ×3 (74.12/74.13.a/74.13.b cooperation/access), Art 86 ×2 (86.2/86.3,
OS-16 end-user surface), 99.4.e ×1 (Art 26 deployer duties).

## Command receipt

    PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW525 \
      mix test test/eu_ai_act/title_vi_xiii_test.exs --include eu_ai_act --exclude eu_ai_act_open_gap

Output (green run, 2026-10-06, exit 0):

    Excluding tags: [:eu_ai_act_open_gap, :stress, :kind, :requires_cnv_deploy,
      :requires_cnv_deploy, :external, :external_llm, :subprocess, :property, :castle_kernel]
    Result: 461 passed, 15 excluded

Honest run (`--include eu_ai_act` with gaps, exit 2):

    Result: 461/476 passed
    Failed: 15 tests - exactly the 15 OPEN_GAP line tests
    (73.1, 73.2, 73.2.s2, 73.3, 73.4, 73.5, 73.6, 73.6.s2, 73.9 [Art 73 x9];
     74.12, 74.13.a, 74.13.b [Art 74 x3]; 86.2, 86.3 [OS-16 end-user surface];
     99.4.e [Art 26 deployer duties])

## Tag-mechanics note (load-bearing for this suite family)

ExUnit resolves includes OVER excludes (exclude filters first, an include
resurrects). A test carrying both `:eu_ai_act` and `:eu_ai_act_open_gap`
flunks through `--include eu_ai_act --exclude eu_ai_act_open_gap`. W525
therefore splits two modules in one file: evidenced/not-applicable tests
carry `@moduletag :eu_ai_act`; the gap module carries ONLY
`@moduletag :eu_ai_act_open_gap` (no eu_ai_act moduletag). Also confirmed
empirically: `@tag` written inside a module-body comprehension DOES apply
(contrary to first hypothesis), which is how W523's per-test tags exist —
W523's failures are the include-resurrection mechanism, not tag loss.

Pre-existing (outside this lane's contract): W523's `title_iii_test.exs`
shows 91 gap-test failures under the green flag combo
(`300/391 passed, Failed: 91`, observed 2026-10-06) because its gap tests
carry both tags.

## Standing

ALIVE (461 green under the W526 flag combo; honest 15-gap inventory flunks
by design in the gaps-included run).
