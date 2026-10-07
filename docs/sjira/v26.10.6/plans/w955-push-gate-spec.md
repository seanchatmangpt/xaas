# W955 — Push Gate Specification (coordinator deliverable)

- **Lane**: W955, v26.10.6 campaign. **Date**: 2026-10-07.
- **Subject**: `docs/sjira/v26.10.6/plans/w955-push-gate-spec.md` (this file — the only file
  written by this lane). Repo: `/Users/sac/xaas` @ `feat/playwright-surface` @ `fab56ae1`.
- **Method**: assembly from receipts only (w946d, w937, w883, w878, w821); no commands
  executed against any tree, no commit, no push, no build root.
- **Standing**: **PARTIAL_ALIVE** — every pushable subject (per-repo commit SHAs, branch
  names, upstream state, xaas ahead-count) is observed fact from w937/w946d receipts on
  disk; the push gate itself is NOT YET EXECUTED, so §1 conditions are stated as conditions,
  not observed facts. Conditions citing in-flight lanes (w939, w926) are UNKNOWN until
  those receipts land.
- **Falsifier**: any per-repo commit SHA or branch in §2 failing
  `git -C /Users/sac/<repo> log -1 <sha>` replay; any §1 condition whose cited receipt is
  absent or contradicting at gate time; the xaas ahead-count failing
  `git rev-list --count origin/feat/playwright-surface..HEAD` at gate time.

## 1. Pre-push conditions (receipt-gated)

Sources: w946d (integration sequence + residue re-verification), w663b (gate definitions),
w821/w926 (census certification), w937/w883 (fleet state), w939 (in-flight pin suites).

| # | Condition | Required state | Receipts | Status at assembly |
|---|---|---|---|---|
| 1a | xaas postcommit gate LANDED on the integration commit | w946's four gates green on the final integration commit: full suite ≥3247 green (w663b contract threshold), mock gate `[]`, ggen sync drift check clean, `mix compile --warnings-as-errors` exit 0 | w946d; w663b defines the gates | NOT YET — the integration commit does not exist yet |
| 1b | Fleet postcommit pin suites green ×11 | all 11 fleet repos' AIRo pin suites pass on the w937 commit SHAs | w958 (5/5 GREEN: ggen-marketplace, ggen, ash_surface, gymact, zcode-cli) + w963 (6/6 GREEN: beam4pm, autofde-lab, wasm4pm, ex4pm, ash_pplan, ferroplan) | **LANDED** — fleet pin matrix 11/11 GREEN at exact W937 SHAs |
| 1c | Census certified | EU-AI-Act terminal census deterministic; green gate = census − open-gap count | w821 (ALIVE @ a0723bf6: 1347/1348, delta = exactly 1 open-gap test, DETERMINISTIC); w926 (in flight) | half-held: w821 ALIVE, w926 UNKNOWN |
| 1d | W940 in-flight residuals adjudicated | the three UNKNOWN-owner residuals (`lib/xaas/semantics/computation.ex`, `docs/claude/diataxis/reference/http-api-surface.md`, `e2e/internal-api.spec.cjs`) either folded into the integration commit or typed-deferred with an owning receipt | w946d (residue re-verification vs live `git status --porcelain` at fab56ae1) | OPEN — coordinator adjudication, not resolved |

## 2. Push commands per repo (from w937, ordering authority w883)

Per-repo branch and upstream state is w937 §"No-push verification" observed output:
`@{push}` resolves for beam4pm, ash_surface, wasm4pm, zcode-cli, ex4pm, ferroplan (new
commits ahead of a live push ref); no upstream for ggen-marketplace, ggen, gymact,
autofde-lab, ash_pplan (first push of the branch, needs `-u`).

| # | repo | branch (w937) | push target per convention | commit | command |
|---|---|---|---|---|---|
| 1 | ggen-marketplace | feat/aaif-gcp-roadmap-v26.10.5 | own feat branch — NOT main (w883 operator gate: `feat/*` branch, merge is an explicit-request transition) | b58d78541 | `git -C /Users/sac/ggen-marketplace push -u origin feat/aaif-gcp-roadmap-v26.10.5` |
| 2 | ggen | feat/v26.10.5-release-cut | own feat branch (no upstream; release-cut branch convention) | ba837d743 | `git -C /Users/sac/ggen push -u origin feat/v26.10.5-release-cut` |
| 3a | beam4pm vendor submodule | main | main | 6e4de9765 | `git -C /Users/sac/beam4pm/vendor/ggen-marketplace push origin main` |
| 3b | beam4pm | main | main | 56020248 | `git -C /Users/sac/beam4pm push origin main` |
| 4 | ash_surface | main | main | b70da9e1c | `git -C /Users/sac/ash_surface push origin main` |
| 5 | gymact | v26926/gymact-land-aloop-execution-kernel | own campaign branch (no upstream) | 2fa947c | `git -C /Users/sac/gymact push -u origin v26926/gymact-land-aloop-execution-kernel` |
| 6 | autofde-lab | feat/doctrine-lab | own feat branch (no upstream) | 31e3decf | `git -C /Users/sac/autofde-lab push -u origin feat/doctrine-lab` |
| 7 | wasm4pm | fix/v26.9.30-ci-fmt-tsc | tracked upstream branch (fix branch, already has push ref) | d980a2a29 | `git -C /Users/sac/wasm4pm push` |
| 8 | zcode-cli | fix/v26926-preview-publish-typed-skip | tracked upstream branch (fix branch, already has push ref) | 1e40596 | `git -C /Users/sac/zcode-cli push` |
| 9 | ex4pm | main | main | abac0d2 | `git -C /Users/sac/ex4pm push origin main` |
| 10 | ash_pplan | fix/ggen-verify-header | tracked upstream branch (fix branch, already has push ref) | 343e52a | `git -C /Users/sac/ash_pplan push` |
| 11 | ferroplan | main | main | e2c48d3 | `git -C /Users/sac/ferroplan push origin main` |
| 12 | xaas (LAST) | feat/playwright-surface | feature branch (NOT main; PR is the lawful merge path) | 30+1 commits ahead of origin (w940's 29 + w940b's fab56ae1 + the pending integration commit) | `git -C /Users/sac/xaas push origin feat/playwright-surface` |

Note on rows 7/8/10: w937 recorded `@{push}` resolving to the pre-commit HEAD for these
repos, so a bare `git push` suffices. Rows 1/2/5/6 have no upstream at all — `-u` is
required on first push. Branch conventions follow each repo's w937 landing branch verbatim;
no repo in this wave pushes a feat/fix branch to main.

## 3. Order — fleet before xaas

**Fleet first, xaas last.** Reasoning from w883 §"Execution order" and w937:

1. **Hard ordering edge (only one)**: ggen-marketplace first — xaas's `ggen sync` consumes
   its pack commit; the marketplace pack surface is upstream authority for generated
   projections. Pushing ggen-marketplace first makes the consumed authority visible before
   the consumer's projections are pushed in xaas.
2. **Submodule edge**: beam4pm submodule (3a) BEFORE superproject (3b) — same rule as the
   w937 commit gate: if the superproject gitlink lands remotely before the submodule commit
   it points to, the remote beam4pm main has a dangling gitlink and any fresh clone fails.
3. **ggen second** — its check_airo.sh + pin script are consumed by ledger verification
   flows (w883 step 2).
4. **Independent pin repos (4–11) any order / concurrent** — w883 finding 4: only
   ggen-marketplace→xaas sync is a hard edge; all others independent.
5. **xaas last** — its push carries the integration commit that references the fleet pins;
   pushing xaas before the fleet SHAs are visible upstream would reference unreached
   commits. w883 step 6 and w946d's sequence both place xaas last.

Concretely: 1 → 2 → 3a → 3b → {4,5,6,7,8,9,10,11} concurrent → 12 (xaas), after §1 holds.

## 4. Post-push verification (per repo)

For each of the 12 subjects above, in the same order:

1. **Ref advance**: `git -C <repo> rev-parse @{push}` equals the pushed commit SHA
   (rows 1/2/5/6: only after the `-u` push creates the upstream). For the submodule:
   `git -C /Users/sac/beam4pm/vendor/ggen-marketplace rev-parse origin/main` = 6e4de9765,
   then `git -C /Users/sac/beam4pm ls-remote origin main` shows a non-dangling gitlink.
2. **CI triggered per each repo's workflow**: confirm a run starts on the pushed head
   (`gh run list -R <owner>/<repo> -b <branch> -L 1` or the repo's CI surface). Repos with
   known CI surfaces: ggen, ggen-marketplace, wasm4pm (fix/v26.9.30-ci-fmt-tsc — CI-fix
   branch), zcode-cli (preview-publish workflow), ferroplan, xaas (exact-head CI per the
   GitHub task normalize doctrine). Repos without a CI surface per their manifests verify
   by ref advance alone.
3. **No dangling gitlink remotely**: fresh `git clone --depth 1` (or `ls-remote`) of
   beam4pm resolves `vendor/ggen-marketplace` to 6e4de9765.
4. **xaas exact-head CI**: the pushed feat/playwright-surface head runs the campaign's CI
   as fallback/supplement — CI conclusion is not truth; the §1 receipts remain the
   authority.

## 5. Hold conditions — what must NOT push yet

1. **1a unmet**: no xaas push until the integration commit exists and the four postcommit
   gates are green LANDED on it (w946d: "Push … NOT YET — gated on step 4"). The current
   `git status` dirty tree is NOT the push subject.
2. ~~**1b unmet**: if any of the 11 fleet pin suites fails (w939), hold that repo's push;
   the AIRo pin evidence is the content of those commits — a red pin means the commit is
   not yet admissible.~~ CLEARED (w968): w958 5/5 + w963 6/6 = 11/11 GREEN at exact W937
   SHAs — 1b no longer an active hold.
3. **W940 in-flight residuals (unpushed by definition)**: the uncommitted residuals listed
   in w946d (graphlaw/SPEC-09 w912, incident validations w902, billing w917, mix.exs w908,
   counterfactual w880, enrollment w893+w925, obs-witness w920, vendor pin w894, witness
   w888+w934, plus the three UNKNOWN-owner files) are working-tree state only — they are
   not in any commit and cannot be pushed. They must be either committed (then re-gated
   via 1a) or typed-deferred BEFORE the integration commit, or the push would carry an
   unadjudicated surface. Until then, 1d holds the push.
4. **Operator-migrate dependency**: w946d lists dev migrate among the operator steps NOT
   YET done (alongside lease cleanup, pin advance, sync). Any push of a tree whose schema
   the dev database has not migrated to is held until the operator migrate step completes
   — this is an operator-gated condition, not executable by a lane.
5. **ggen.toml pin advance**: the pin is still at `518572b6...` on disk (w946d verified);
   the pin advance + `ggen sync` (predicted one-line delta, w918) must precede the
   integration commit, so it precedes the push transitively. Push before the pin advance
   would push projections that do not match the pinned marketplace pack — held.
6. **Merge transitions**: no repo in this wave merges (ggen-marketplace `feat/*` gate,
   w883 gate 3; xaas feat/playwright-surface merges only via PR on explicit request).
   Push ≠ merge; every push target above is the repo's own landing branch.

## 6. Receipt

- Exact subject: this file, written on `feat/playwright-surface` @ fab56ae1 working tree.
- O: w946d, w937, w883, w878 (lease cleanup context — 80 entries / ~31.71 GB rm list is a
  coordinator pre-push integration step per the fanout cleanup law, not a push gate
  condition), w821, w663b, w918. No execution, no commands run, no build root minted.
- μ/diff: handwritten, 1 file (this spec). Generated-vs-handwritten: 100% handwritten.
- Standing: PARTIAL_ALIVE as declared in the header; becomes ALIVE only when a coordinator
  execution receipt replays §1 green and §4 post-push on the exact subjects.
- Replay: `git log -1` per SHA in §2's table; `git rev-list --count
  origin/feat/playwright-surface..HEAD` at xaas gate time; receipt corpus under
  `/Users/sac/xaas/docs/sjira/v26.10.6/plans/`.
