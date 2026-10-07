# W812 — Org-resolution coverage adjudication (W769 disclosed gap)

- **Lane**: W812, v26.10.6 campaign
- **Subject**: `/Users/sac/xaas` @ `a0723bf6` (`a0723bf61a1c6058bdcd2d0202c9519840182a5e`), branch `feat/playwright-surface`
- **Standing**: RESOURCE_ALIVE — 20/20 tests green on the exact subject (14 W769 + 6 new W812); no production code touched
- **Diff**: extend only `test/xaas/governance/security_resources_deepening_test.exs` (new
  `describe "(f) org binding on issue/3 (W812)"`, 6 tests, all hand-written; no generator
  profile exists for this class → handwritten=irreducible residue)
- **Receipt file**: this file

## Adjudication: W769's `{:org_not_found, _}` gap vs W743's courts

**Verdict: genuinely distinct, not COVERED_ELSEWHERE — new courts written.**

Real-read evidence:

- W743 (`test/xaas_web/resolve_org_actor_deepening_test.exs`) covers
  `XaasWeb.Plugs.ResolveOrgActor` — the **X-Org-Id header** path on `/api/*`: unknown slug →
  real 404 `org_not_found` (lines 148–163), blank/multi-valued header → 400. That plug keys
  on a **client-asserted header**; no `InternalApiTokenAuth` involvement anywhere in that
  file (grep across the whole test tree for `InternalApiTokenAuth.issue(..., org)` in an
  org-resolution-negative form: only happy-path uses in the execution-fabric tests).
- W769's gap names `InternalApiTokenAuth.issue/3` → `resolve_org_id/1`
  (`lib/xaas/governance/internal_api_token_auth.ex:56-89`): the **token-mint org-binding**
  path — struct / slug / uuid-fallback branches plus the typed `{:error, {:org_not_found,
  identifier}}` return. Zero prior coverage: no test in the tree asserted `{:org_not_found,
  _}` from `issue/3`, the uuid fallback, or the struct path. Existing org-scoped tests
  (`test/xaas_web/execution_fabric_controller_test.exs:51,33`) exercise only the happy path.
- A third, related-but-uncovered surface: `RequireInternalApiToken.resolve_org/1`'s
  `{:error, _} -> nil` downgrade branch (`lib/xaas_web/plugs/require_internal_api_token.ex:120-127`).

## New courts (all real Chicago-style: real Org rows, real sandboxed Postgres, real plug calls, no mocks)

1. `issue/3` with a real `%Org{}` struct binds the token's persisted `org_id` (re-read from
   a fresh `Ash.get!`).
2. `issue/3` with a real slug resolves the real row; `verify/1` ok; real plug call with no
   env var attaches the **loaded `%Org{}` struct** (never the bare id) as `current_org`.
3. `issue/3` with the org's own id (uuid fallback clause, `internal_api_token_auth.ex:84-87`)
   resolves to the same `org_id`.
4. Unknown slug AND unknown uuid binary both return the real typed `{:error, {:org_not_found,
   identifier}}`, identifier echoed exactly.
5. **Typed finding (new, real)**: the `%Org{}` struct clause trusts the struct's id with no
   lookup, so a dangling struct escapes `resolve_org_id/1` — the **DB FK
   `internal_api_tokens_org_id_fkey`** is the actual backstop, refusing the write with a
   typed `Ash.Error.Invalid` (`field: :org_id, message: "does not exist"`).
6. **Typed finding (new, real)**: the plug's `resolve_org/1` `{:error, _} -> nil`
   downgrade-to-admin-tier branch is **structurally unreachable** under the current schema:
   a real `Repo.delete_all` on a referenced org raises
   `Postgrex.Error` naming `internal_api_tokens_org_id_fkey` (real observed, pinned), and a
   token minted against the org then still verifies and the plug still loads the real
   `%Org{}` — the FK restrict is the org-binding invariant.

## Commands / exits

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW812 \
  mix test test/xaas/governance/security_resources_deepening_test.exs
→ Finished in 1.2 seconds (1.2s async, 0.00s sync) / Result: 20 passed

MIX_ENV=test MIX_BUILD_ROOT=_build-laneW812 mix run -e \
  'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test","lib"]))'
→ []  (mock gate clean)
```

## Verification ladder

narrow (6 new tests in the existing W769 file, real sandbox Postgres, real plug invocations,
real FK behavior) → full-file re-run 20/20 → mock gate `[]`. No production code touched; no
session-introduced production failures. Session-introduced test failures during iteration:
4 (Postgrex uuid byte-width, FK delete ordering, a match-context `org.id`, one structural
rewrite) — all fixed in-lane, final run fully green.

## Falsifiers (how this receipt dies)

- Run the file on `a0723bf6`; any test red → standing dies.
- Add `destroy` semantics / `on_delete: :nilify` to the FK and test 6's unreachability pin
  inverts into a live downgrade finding.
- Make `resolve_org_id/1`'s `%Org{}` clause re-lookup the row and test 5's FK-backstop pin
  inverts into a redundant-lookup pin.

## Standing / handoff

- Org-binding surface of `InternalApiTokenAuth` is RESOURCE_ALIVE on `a0723bf6`.
- Disclosed, not fixed: `resolve_org_id/1`'s struct clause performs no liveness lookup —
  correctness rests entirely on the DB FK. A code-level backstop (re-resolve the struct's
  id) would be a one-line hardening; left to the coordinator.
- Lane build root `_build-laneW812` left on disk for the coordinator (lane deletion was
  permission-denied in this session); lease honored, coordinator to delete at integration.
