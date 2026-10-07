# W769 — Governance security resources deepening (InternalApiToken + PentestFinding)

- **Lane**: W769, v26.10.6 campaign
- **Subject**: `/Users/sac/xaas` @ `a0723bf6` (`a0723bf61a1c6058bdcd2d0202c9519840182a5e`), branch `feat/playwright-surface`
- **Standing**: PARTIAL_ALIVE — 14/14 real tests green on the exact subject; no production code touched
- **Diff**: 1 new file, `test/xaas/governance/security_resources_deepening_test.exs` (hand-written; no generator profile exists for this class → handwritten=irreducible residue)
- **Receipt file**: this file

## O / O*

- Backlog: the two governance security resources were undocketed (no dedicated resource-level
  court). Real-reads in full: `lib/xaas/governance/internal_api_token.ex`,
  `lib/xaas/governance/internal_api_token_auth.ex`,
  `lib/xaas/governance/changes/generate_internal_api_token.ex`,
  `lib/xaas/governance/validations/internal_api_token_not_already_revoked.ex`,
  `lib/xaas/governance/checks/pentest_finding_actor_org_matches.ex` / `..._org_filter.ex`,
  `lib/xaas_web/plugs/require_internal_api_token.ex`,
  `lib/xaas/governance/types/pentest_finding_{severity,status}.ex`, plus existing
  `test/xaas/governance/pentest_finding_test.exs`,
  `test/xaas_web/require_internal_api_token_deepening_test.exs`,
  `test/xaas/governance/export_token_deepening_test.exs` (style/W715 pattern).
- Prior coverage existed but was split (plug-level W723 court; PentestFinding court). This
  lane adds the resource-level InternalApiToken mint→verify→revoke→expiry lifecycle court
  plus a real-plug env-var-floor separation pin, and a policy-floor court for PentestFinding.

## Findings per real code (asserted, not surveyed)

- (a) **Mint/validate lifecycle**: `InternalApiTokenAuth.issue/3` → raw token
  `iat_live_<43 url-safe chars>`; persisted `token_hash` == lowercase-hex SHA-256 of the raw
  value (64 chars); `token_prefix` == first 12 raw chars; raw token survives only as
  `put_metadata(:raw_token)` on the create result — a fresh `Ash.get!` of the row has **no**
  raw-token field (plaintext storage would be caught by the exact assertion
  `reloaded.token_hash == expected_hash(raw)`; if a column ever stored the raw value it
  would not change `token_hash`, but the metadata-only carrier is pinned so any new
  persisted raw attribute showing up in a fresh read would need a new public field).
  `verify/1` round-trips the exact raw value and fails closed on `raw<>"x"`, wrong token,
  `""`, `nil`, non-binary.
- (b) **Expiry/revocation semantics**: past `expires_at` → `verify/1` `:error` and
  `active?` calculation `false` (calculation and `verify/1`'s private `active?/1` agree);
  future expiry live; `nil` expiry = live until explicit revocation; `revoke/1` sets
  `revoked_at`, kills the exact raw value, keeps the auditable hash, and a second revoke is
  a typed `Ash.Error.Invalid` naming `:revoked_at` + "already revoked" (the
  `InternalApiTokenNotAlreadyRevoked` guard, really executed).
  **Typed gap (disclosed, W715 pattern): no sweep/job expires rows** — expiry is evaluated
  lazily only at `verify/1`/`active?`; expired rows persist forever unless an operator
  revokes or deletes them. Honest absence, pinned by asserting current behavior, not fixed.
- (b2) **Typed finding**: `InternalApiToken`'s policies are real deny-by-default with **no
  bypass** — `issue`/`revoke`/`by_hash` are reachable only `authorize?: false`
  (operator/mix-task + plug `verify/1`). Pinned by the fact that every test in the file
  that touches the resource uses `authorize?: false`; no actor-authorized path exists.
- (c) **PentestFinding lifecycle**: `:create` files always `:open` (status not acceptable
  input); `:remediate` is the **only** update action (asserted via
  `Ash.Resource.Info.actions/1`), open→`remediation_in_progress`, second remediate is a
  typed validation "finding must be open to move to remediation_in_progress".
  **Honest gap pin**: the terminal `:resolved`/`:accepted_risk` transitions exist in
  `PentestFindingStatus` values but **no action on the resource writes them** — they are
  reachable only via `ApprovalPentestFindingResolve` maker-checker (relationship
  `resolve_approvals` pinned: destination `ApprovalPentestFindingResolve`, dest attr
  `:finding_id`).
- (c2) **Policy floor, real execution**: with `authorize?: true`, an actor whose `org_id`
  differs from the record's is Forbidden on both `:create` (forged victim-org finding) and
  `:remediate` (cross-org status flip on a real existing row) — the two closed
  ERRC findings, now pinned at the resource boundary; matching-org actor passes `:remediate`;
  read is open (real `bypass action_type(:read)`).
- (d) **Env-var floor separation (real plug invocation, real env var)**: a live DB token
  authenticates the plug with `INTERNAL_API_TOKEN` **deleted** (`current_org == nil`, not
  halted) — the DB resource is additive, not a replacement; a **revoked** DB token 401s and
  the env value still passes (flat env-var floor untouched by resource state); no env var +
  no matching row → 503 fail-closed. The resource surface and the env-var floor are two
  independent credential tiers; neither implies the other.
- (e) **Determinism**: distinct mints with the same `created_by` produce distinct
  raw/hash/id (no dedupe on label); hash derivation is a pure function of the raw value
  (`expected_hash(raw) == token.token_hash` re-derives identically); identical finding
  inputs produce identical status outcomes and identical typed refusals.

## Commands / exits

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW769 \
  mix test test/xaas/governance/security_resources_deepening_test.exs
→ Finished in 0.6 seconds (0.6s async) / Result: 14 passed

MIX_ENV=test MIX_BUILD_ROOT=_build-laneW769 mix run -e \
  'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage([...]))'
→ []  (mock gate clean)
```

Session-introduced failures: 2 (chained `==` comparisons split; `Plug.Test.put_req_header`
→ `Plug.Conn.put_req_header`) — both fixed in-lane, final run fully green.

## Verification ladder

narrow (this file, 14 tests, real sandbox Postgres + real plug call + real env var)
→ mock gate. Unit/integration boundary: real row state asserted after every action; no
mocks, no stubs (mock gate `[]`).

## Falsifiers (how this receipt dies)

- Run the file; any test red on `a0723bf6` → standing dies.
- `grep -c "raw_token" lib/xaas/governance/internal_api_token.ex` showing a persisted
  `attribute :raw_token` (vs metadata) → the never-persisted pin dies.
- A new update action on PentestFinding that writes `:resolved`/`:accepted_risk` without
  the maker-checker approval → the gap pin inverts into a live finding.

## Standing / handoff

- RESOURCE_ALIVE for both resources on `a0723bf6`; typed gaps disclosed, not fixed:
  expired-token rows are never swept (lazy expiry only), and `org` resolution in
  `issue/3`'s `{:org_not_found, org}` path is untested here (needs a real `Org` fixture —
  left to the coordinator; existing org-scoped behavior is covered by the W723 plug court
  and the execution-fabric tests).
- Lane build root `_build-laneW769` deleted post-run per lane-lease law.