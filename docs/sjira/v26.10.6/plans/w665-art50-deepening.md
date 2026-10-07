# W665 — Art. 50 Evidenced-Line Deepening (EU AI Act suite)

Lane W665, 2026-10-07. Repo `/Users/sac/xaas` @ `feat/playwright-surface` (HEAD a0723bf6 at lane start).
Branch not committed (lane discipline: coordinator owns integration).

## Subject

- New file: `test/eu_ai_act/art50_deepening_test.exs` (7 tests, `@moduletag :eu_ai_act`)
- Receipt: `docs/sjira/v26.10.6/plans/w665-art50-deepening.md` (this file)

## Before

Art. 50 evidence in the suite was: title_iv_v_test.exs 50.1/50.5 W619 deepening blocks
(direct plug calls + kernel atoms), 50.2 W533 flip pass (real HTTP via
`test/xaas_web/synthetic_marking_test.exs`), plus path-existence assertions over
`lib/xaas_web/plugs/synthetic_marking_plug.ex` and
`docs/cro/artifacts/end-user-disclosure-v26.10.6.md`. No lane-owned court exercised
the marking plug and the typed kernel on the same surface in one file, and the
disclosure artifact's central claim ("a policy refusal is never wire-distinguishable
from tool absence") had no dedicated adversarial line.

## After (all real collaborators, no mocks)

- 50.1a/50.1b — real endpoint-pipeline HTTP (`ConnCase`) against `/a2a/v1` and `/mcp`:
  `x-ai-generated: true` header + top-level `"ai_generated": true` field; GET `/mcp`
  and POST `/internal-api/x` untouched (no header). Asserts final conn state only.
- 50.2a — refusal envelope marked on the real wire: POST `/a2a/v1` with
  `techniques: ["subliminal"]` returns HTTP 200, marked, and the body is NOT the
  `-32602 Tool not found` shape (the end-user-disclosure artifact's central claim,
  now court-enforced).
- 50.2b — typed kernel calls `Xaas.Semantics.EuAiActAdmission.admit/1`:
  `:subliminal` -> `{:error, :REFUSED_EUAIA_MANIPULATIVE}`; affective-domain +
  workplace/education setting -> `{:error, :REFUSED_EUAIA_EMOTION_RECOGNITION}`
  (impl: `affective_in_context?/1`, lib/xaas/semantics/eu_ai_act_admission.ex).
- 50.5a/50.5b/50.5c — direct plug calls (real `SyntheticMarkingPlug`): iodata JSON
  body is decoded + re-encoded with `ai_generated`; non-JSON SSE body gets the
  header only and is byte-unchanged; marking is idempotent on an already-marked
  body; JSON array body gets header only, body unchanged (`[1,2,3]`).

## Coordinator-directed repair (W662 census finding)

Census flagged 50.2b expecting `{:error, :REFUSED_EUAIA_EMOTION_RECOGNITION}` from a
bare `%{techniques: [:emotion_recognition]}` input, but the real kernel ADMITS that
input. Wired to actual behavior, cited impl: the refusal requires `:affective` in
`data_domains` joined with `setting in [:workplace, :education]`
(`affective_in_context?/1`, lib/xaas/semantics/eu_ai_act_admission.ex:167-170). Both
workplace and education now asserted, plus the bare-technique admission is asserted
explicitly so the gap is documented, not hidden. No impl change (out of lane scope).

Also disclosed: an early in-lane run compiled a mid-rewrite (corrupted) version of
the test file, which caused a transient compile abort observed by W662; the file on
disk was rewritten clean before any green result below.

## Verification (real output)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW665 \
  mix test test/eu_ai_act/art50_deepening_test.exs --include eu_ai_act

Running ExUnit with seed: 987421, max_cases: 32
Including tags: [:eu_ai_act]
.......
Finished in 0.1 seconds (0.00s async, 0.1s sync)

Result: 7 passed
```

Note: `:eu_ai_act` is in the suite's default exclude list, so `--include eu_ai_act`
is required (same convention as the rest of test/eu_ai_act).

Pre-existing environment noise (not lane-introduced, seen on every run in this
tree): PromEx/Grafana nxdomain upload warnings, AshA2A legacy_compat receipt-store
warnings.

## Standing

- Art. 50(1)/(2) marking on the real AI surfaces: ALIVE (7/7 witnessed on
  feat/playwright-surface @ lane build; uncommitted, coordinator integration pending).
- Emotion-recognition refusal: PARTIAL_ALIVE — kernel gate is conjunctive
  (domain+setting); a bare technique atom admits. If the campaign wants
  technique-atom refusal too, that is an impl change outside this lane's file set.

## Falsifier

`mix test test/eu_ai_act/art50_deepening_test.exs --include eu_ai_act` — any failure
flips the standing above.
