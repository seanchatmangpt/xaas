# W779 — `:eu_ai_act_open_gap` tag binds nothing (diagnosis + remedy receipt)

- **Lane**: W779, xaas v26.10.6, branch `feat/playwright-surface`, HEAD `a0723bf6`,
  canonical checkout `/Users/sac/xaas` (shared, live campaign — concurrent lanes were
  editing the same directory during this lane).
- **Task**: W760 gate receipt's typed anomaly: `mix test test/eu_ai_act --only
  eu_ai_act_open_gap` selects 0 / excludes 1200; the four flagged `@moduletag` /
  `@tag :eu_ai_act_open_gap` declarations bind nothing at runtime.
- **Env**: pinned toolchain (`elixir 1.20.2-otp-28` / erlang 28.5.0.2 via asdf),
  `MIX_ENV=test`, `MIX_BUILD_ROOT=_build-laneW779`.
- **Standing**: ALIVE (remedy verified on the real suite; one pre-existing
  unrelated failure F2 remains, owned by another lane — see below).

## Root cause (single structural bug, not four)

The four flagged tag sites are not four independent dead tags. Three of them
(Title I, Title III, Title VI-XIII open-gap modules) are correctly tagged and
correctly generate **zero** tests because their gap inventories are genuinely
empty (Title I `@gap_details == %{}` since W648b; Title III `Lines.open_gaps/0`
returns `[]`; Title VI-XIII likewise — all gaps reclassified/closed by earlier
waves). An empty inventory with a live tag is fine, not a bug.

The fourth site (title_iv_v_test.exs:446, `@tag :eu_ai_act_open_gap` in the
`:open_gap` case clause of the Title IV+V generator) binds nothing because the
generator's corpus-scope filter is structurally broken:

```elixir
for title <- titles,
    title["num"] in ["IV", "V"],   # <- BUG: drops Art. 49 entirely
    ...
    n in 28..56 do
```

The corpus (`docs/eu_ai_act/corpus.json`) places Art. 49 under title num
**"III"** (with Arts 28-48 machinery), not under "IV". So the filter
`title["num"] in ["IV", "V"]` silently excluded every Art. 49 line from the
IV+V generator, including **"49.3"** — the only entry of its `@open_gaps`
map, which comment says is the "honest, typed, by line_id" open-gap
inventory. The `@open_gaps["49.3"]` declaration was therefore a **dead
declaration**: a real typed open gap (Art. 49(3) deployer EU-database
registration duty — no registration seam exists in this repo) that never
generated its flunk row.

## Honest current state (measured, not inferred)

- `--only eu_ai_act_open_gap` before remedy: **0 selected / 1200 excluded**
  (reproduced twice on the live tree).
- Real typed open-gap rows in the corpus: **exactly 1** — `49.3`
  (`Xaas.EUAIAct.TitleIVVTest` "EUAI-ACT 49.3 — OPEN_GAP: Before putting into
  service or using a high-risk AI system listed in Ann[ex III]…").
- So W760's reading ("0 open gaps is real but the mechanism is unexercised /
  vacuous") was **incorrect in the honest direction**: the census was not
  merely vacuous, it was **hiding one real declared open gap**. The green-gate
  totals (1200) were also undercounted by 9: the Art. 49.1–49.5 lines the
  filter dropped are corpus lines the suite should have carried as
  NOT_APPLICABLE rows.

## Remedy (minimal, one hunk)

`test/eu_ai_act/title_iv_v_test.exs` — scope the IV+V generator by article
range only, deleting the title-num filter (the `n in 28..56` filter is the
generator's intended domain per its own moduledoc: "Corpus's Arts 28-39 …
Arts 50-55"; Art. 49 was always in-intent). Diff: remove
`title["num"] in ["IV", "V"],` from the comprehension, plus a W779 scope note
comment pointing at this receipt. No tags, verdicts, maps, or invented gaps.

- Effect: all 10 Art. 49 corpus lines now bind. 9 become NOT_APPLICABLE rows
  (falls through to the 40-49 machinery branch, honest typed reason asserted
  non-empty) and **49.3 binds as the sole real OPEN_GAP row**, flunking by
  design, tagged `:eu_ai_act_open_gap`.
- No fake sentinels were added; with the real 49.3 row bound, the tag
  mechanism is exercised by a real row, making sentinel stubs unnecessary.
  Title I/III/VI-XIII gap modules legitimately hold zero rows and stay as-is.

## Verification (real runs, lane build root, pinned toolchain)

| Run | Command | Before | After |
|---|---|---|---|
| census probe | `mix test test/eu_ai_act --only eu_ai_act_open_gap` | 0 selected / 1200 excl. | **1 selected / 1347 excl., flunks honestly** (0/1) |
| green gate | `mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap` | 1200-test set | **1346/1347 passed, 1 excluded** |
| census | `mix test test/eu_ai_act --include eu_ai_act --include eu_ai_act_open_gap` | 1200-test set | **1346/1348 passed** |

- Census total (1348) minus green gate total (1347) = **1 = the real open-gap
  count**. The two runs now differ by exactly the tag-selected set, which is
  the invariant the census convention requires.
- Totals moved 1200 → 1347/1348 for two additive reasons: my +10 Art. 49 rows
  **and** concurrent lanes' landed work in the shared tree during this lane
  (+137 tests from other lanes' waves, present identically in my before/after
  `--only` runs — the before-run `0 selected / 1200 excluded` and after-run
  `1 selected / 1347 excluded` share the same tree evolution; only my +10 and
  the +1 selection are attributable to this lane).
- The one green-gate failure, `EUAI-ACT 15.5.s3` (title_iii_test.exs:1035,
  history-order assertion in the staged W540 deepening hunk), is
  **pre-existing and unrelated** to this lane: it is present identically in
  W760's gate (F2 in its receipt), in my pre-remedy census run, and in my
  post-remedy runs — unchanged failure shape, owned by the W540/W623 lifecycle
  lane, not repaired here (not my file ownership).

## Replay

```bash
cd /Users/sac/xaas
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW779 \
  mix test test/eu_ai_act --only eu_ai_act_open_gap 2>&1 | tail -4
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW779 \
  mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap 2>&1 | grep "Result:"
```

## Standing

ALIVE for the remedy: the census mechanism is live, the real open-gap count is
1, green gate is green except the one pre-existing W540 court regression
already typed in W760's receipt (F2). No invented gaps, no fake sentinels. The
remaining 9 new NOT_APPLICABLE rows for Art. 49 lines are corpus-authoritative
and pass. Total test count change (+10 from this lane) is disclosed and
attributable; coordinator owns commits.
