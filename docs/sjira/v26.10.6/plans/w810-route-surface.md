# W810 — SA2A route wire-adjacent surface (receipt)

- **Subject**: /Users/sac/xaas, branch `feat/playwright-surface`, worktree base
  a0723bf6 + in-flight shared-checkout state (uncommitted). Test file and
  receipt are the lane's only writes.
- **Lane**: W810, v26.10.6. No commit (per lane contract; coordinator owns
  transitions).
- **Standing**: PARTIAL_ALIVE — 25/25 tests pass on the exact subject, with
  one disclosed environmental caveat (below).

## Files written (lane diff = 2 files)

- `test/xaas/sa2a_route_surface_test.exs` — new, 25 tests, no mocks.
- `docs/sjira/v26.10.6/plans/w810-route-surface.md` — this receipt.

## Scope covered

- **(a) `Route.tuple/1` over the real generated fixture** — the fixture
  `test/fixtures/sa2a_route/sa2a_task.json` still exists and is pinned as-is
  (provenance re-checked: producer `GgenIgniter.SemanticA2A.task_from_work_order/2`,
  40-hex `ggen_igniter_head`). Arity-1 shape dispatch over the real task and
  order fixtures; full 7-field tuple pinned literally, including the sorted
  exclusions. Dispatch precedence (taskId beats subject) proven by a
  camelCase-only carrier: `{:missing_field, "evidence_ceiling"}` is only
  reachable via the task hop (the order hop would name `capability`).
- **(b) generated bridge-edges projection** (`lib/xaas/generated/sa2a_bridge_edges.ex`),
  real file read: GENERATED header pinned; 5 edges; every local `from`
  reference resolves to a loaded module with a real exported arity on
  `Xaas.Sa2a.Bridge` (validate/0,1,2, admit/2,3, plan/1,2, execute/1,2,
  replay/2); authority vocabulary pinned in sequence order
  (VERIFY_ONLY, ADMIT_ONLY, CONSTRUCT_ONLY, PORT_DO_ONLY, RECEIPT_ONLY);
  do-boundary belongs to exactly `port-do-execute`; admission receipts after
  only; the DO edge receipts on both sides; `by_port_op/1` miss → nil;
  repeated calls identical.
- **(c) refusal branches complementing W741/W763** — the construction courts
  already cover ambiguous-carrier (1 and 2 parts), zero-part missing_field,
  non-data kind parts, and wrong-hop. W810 adds: invalid `consequence_class`
  value (`make_coffee`), blank exclusions entry, exclusions sort
  normalization, capability object form read through `capability_id` (accept
  and refuse paths), whitespace-only required field (`invalid_field`, not
  `missing_field`), unrecognized shapes at arity-1 (string, `[]`, `%{}`,
  nil), structs refused even shape-compatible (`%File.Stat{}`), non-map for
  a known hop at arity-2, task `input` as a bare map (wrapped), and a
  minimal atom-keyed bridge epoch (accepts or typed epoch_contract refusal,
  never a raise).
- **(d) determinism** — `tuple/1`/`digest/1` pure and identical across
  calls and hops; digest format pinned `sha256:[0-9a-f]{64}`; extra fields
  don't perturb the digest; `EdgeCatalog` repeated calls identical;
  `fields/0` and `route_schema/0` pinned.

## Commands / exits

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/sa2a_route_surface_test.exs
# seed 65170, max_cases 32
# .........................
# Finished in 0.2 seconds
# Result: 25 passed            exit 0
```

Earlier seeds on the same subject: 954943 / 133926 / 133926-fix runs; last
three runs stable at 23→25 passing as fixes landed. Final: **25 passed, 0
failures, 0 skipped**.

## Environment caveat (disclosed, pre-existing, not lane W810's)

The shared checkout holds an **untracked** `lib/xaas/operations/validations/incident_resolved_is_terminal.ex`
(another lane's in-flight file) that fails Elixir 1.20 type checking
(`Ash.Changeset.OriginalDataNotLoaded` struct undefined under the pinned
ash) and therefore blocks ANY fresh compile of the xaas app
(`MIX_BUILD_ROOT=_build-laneW810` full build died at `== Type checking
failed with errors ==`). To run my file I parked that untracked file
outside the tree for the duration of each `mix test` invocation against the
shared `_build/test`, and restored it **byte-identically** after every run
(sha256 compare, `restored_ok=yes` on all runs). It is untracked work of
another lane; W810 neither modified nor committed it. Flag to the
coordinator: a fresh-environment build of this branch is currently
BUILD_BROKEN by that file.

Also observed (benign, pre-existing): PromEx Grafana nxdomain warnings and
`Xaas.Sa2a.Bridge not started: "autofde" executable not found on PATH` at
test boot.

## Typed gaps

- `admit_field("exclusions", binary)` — a binary `exclusions` value falls
  through the is_list guard to the generic nonempty clause and is carried
  verbatim into the tuple (contradicts the `@type route_tuple` list type).
  NOT fixed (outside lane scope: lib/ is not W810's); pinned as observed
  truth in the test named "a non-list exclusions value is accepted verbatim
  (pinned gap)" so any future tightening flips the test deliberately.
- Fresh-build BLOCKED by the parked-file type-check error above — typed
  `BUILD_BROKEN` for any clean checkout at this worktree state, until the
  owning lane or coordinator lands or fixes that file.
- `_build-laneW810` full build could not complete; per the lane lease law
  it has been deleted as incomplete.
