# W912 — S-estimate spec implementation receipt (W905 backlog, 2 S specs)

- **Lane**: W912, xaas v26.10.6, repo `/Users/sac/xaas`, branch `feat/playwright-surface`,
  base HEAD `a0723bf6` (unchanged — no commit, per lane instruction).
- **Spec source**: `docs/sjira/v26.10.5` … precisely
  `docs/sjira/v26.10.6/plans/w905-design-gap-specs.md` (PARTIAL_ALIVE doc-only backlog).
- **Scope check / lane ownership**: `w910-spec-registration.md` and `_INDEX.md` carry no
  W905/W912 rows and no other lane claims `lib/xaas/graphlaw/capability.ex` or
  `lib/xaas/governance/audit_export_token.ex`; no in-flight conflict found.
- **Estimate summary line cited**: S = SPEC-09, SPEC-17.

## SPEC-09 (W731-GAP-1) — `:capability_class` enum on Graphlaw Capability — ALIVE

### Surface (exact diff)
- `lib/xaas/graphlaw/capability.ex`: new public attribute
  `:capability_class, :atom`, `constraints: [one_of: [:observe, :select, :construct, :do]]`,
  `default: :observe`, public?; `:create` accept list grows
  `[:name, :algorithm, :profile, :supported_in]` → `[..., :capability_class]`.
- Migration `priv/repo/migrations/20261007210000_add_capability_class_to_graphlaw_capabilities.exs`:
  nullable `capability_class :text` column + backfill `UPDATE ... SET capability_class = 'observe'`
  (SQL layer stays nullable to match Ash-side default semantics; spec named
  "nullable column + backfill default").
- `lib/xaas/graphlaw/catalog.ex` untouched: registry ingest rows default to `:observe`
  (least-authority); determinism test (d) stays green.

### Court (one regression court, W731-mirror)
`test/xaas/graphlaw_deepening_test.exs` — the landed W731 suite's own create/accept-list
idiom, extended:
- Pre-SPEC-09 honest-gap pin test (asserted `Map.has_key?(..., :capability_class) == false`)
  **flipped** — now asserts the attribute exists and defaults to `:observe`. The flipped pin
  is the visible repair diff per the spec's court line.
- NEW `SPEC-09 court: create accept list grows to exactly the five real attributes`
  (reads `Ash.Changeset.for_create(:create, %{}).action.accept` against the real resource).
- NEW `SPEC-09 court: out-of-enum value → typed Ash.Error.Invalid naming :capability_class`.
- NEW `SPEC-09 court: each in-enum value persists and round-trips through the real column`
  (all four values on real sandboxed Postgres rows).

### Mutation kill (real, executed)
- Mutation: revert the accept list to the pre-SPEC-09 four-attribute body (drop
  `:capability_class`).
- Result: `Result: 15/18 passed / Failed: 3 tests` — the accept-list court, the flipped
  pin's default assertion, and the round-trip court all fail under the mutation. Court is
  non-vacuous.
- Process note (typed, disclosed): the mutation was reverted with
  `git checkout -- lib/xaas/graphlaw/capability.ex`, which restored HEAD and **also wiped
  the lane's uncommitted SPEC-09 implementation**; it was re-applied by exact edit and
  re-verified green (18/18). Subject for the green run is the restored file.

### Verification (real tails)
- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW912 mix test
  test/xaas/graphlaw_deepening_test.graphlaw_deepening_test.exs` — actual tail:
  `Running ExUnit with seed: 834176, max_cases: 32` … `Finished in 0.8 seconds` →
  **`Result: 18 passed`** (exit 0). Pre-lane suite was 15 tests (13 W731 + 2 W897
  registry-path); the lane rewrote 1 pin test in place and added 3 new courts →
  15 + 3 = 18.
- Migration confirmed applied to the real test DB:
  `psql -h localhost -U postgres -d xaas_test -c "\d graphlaw_capabilities"` shows
  `capability_class | text` present; `mix ecto.migrate` exit 0, no pending rows.
- Grafana/PromEx upload warnings in the tail are pre-existing (no Grafana at this host);
  not lane-introduced.

## SPEC-17 (W765-GAP-C) — ExpiredTokenRefused on `:use` — BLOCKED

- **Standing: BLOCKED(dependency-unlanded)**, not failed, not skipped silently.
- The spec's own sequencing line: "blocked on SPEC-16 (no `:use` action exists to guard)."
  Verified at HEAD `a0723bf6`: `lib/xaas/governance/audit_export_token.ex` has no `:use`
  action, no `used_at`/`use_count` attributes (grep: only a test comment mentioning "no
  last_used_at, no use counter"). SPEC-16 is **M**-estimated (new action + attributes +
  one migration + court mirroring W740 guard idiom) and is not landed.
- Implementing SPEC-17 lawfully requires first landing SPEC-16 — that grows this lane
  beyond its S estimate. Per lane instruction ("stop that spec and disclose rather than
  expand"), the lane stops here and discloses.
- **Resume key**: implement SPEC-16 first (M lane), then SPEC-17 is a genuine S: add
  `ExpiredTokenRefused` validation to the new `:use` action, court extends
  `test/xaas/governance/export_token_deepening_test.exs` with expired-then-use refusal
  (typed `Ash.Error.Invalid`, field `:expires_at`), W740-mirror change-validation idiom.

## Standing summary

| spec | standing | falsifier |
|---|---|---|
| SPEC-09 | PARTIAL_ALIVE → observed ALIVE on this subject (uncommitted; coordinator commits) | accept-list mutation reverted 3 tests RED → court non-vacuous; migration present on real xaas_test |
| SPEC-17 | BLOCKED(dependency-unlanded) | — (no `:use` action exists to guard; SPEC-16 not landed) |

## Environment / replay

- Toolchain: asdf pinned (`PATH=$HOME/.asdf/shims:...`), `MIX_ENV=test`,
  `MIX_BUILD_ROOT=_build-laneW912`.
- Lane build root: `_build-laneW912` — in-lane deletion was **refused by the permission
  system** (`rm -rf` denied), so it is **left for the coordinator** per the lane's
  fallback clause. Coordinator: re-run the single test file under any build root; suite
  is self-contained.
