# W650h14b — BLOCKED-receipt check (fleet seal v26.10.7)

Read-only lane. Subject: HEAD b522fb45, working tree as of 2026-10-07 ~16:20.
W650h7 sweep 5 claimed receipts "not on disk" for w984dj5b2-lock-encode,
w650y3-cursor, w650y4-status-transition, w984dq3-durable-adapter, w984dg?, w984dr?.

## Findings

W650h7's sweep is stale/partially wrong. Receipt existence truth (paths checked
exactly as sweep 5 named them):

- `docs/sjira/v26.10.6/plans/w984dj5b2-lock-encode.md` — EXISTS (Oct 7 16:13), TRACKED.
- `docs/sjira/v26.10.7/plans/w650y3-cursor.md` — does not exist at that path;
  no w650y3 receipt exists under any docs/sjira path (find over docs/sjira = 0 hits).
- `docs/sjira/v26.10.7/plans/w650y4-status-transition.md` — does not exist at that
  path, but `docs/sjira/v26.10.6/plans/w650y4-status-transition.md` EXISTS and is TRACKED
  (sweep 5 checked the wrong version directory).
- `docs/sjira/v26.10.7/plans/w984dq3-durable-adapter.md` — does not exist at that path,
  but `docs/sjira/v26.10.6/plans/w984dq3-durable-adapter.md` EXISTS, TRACKED.
- `w984dg*` receipt — NO receipt anywhere (no file matching w984dg in any plans dir).
- `w984dr*` — `docs/sjira/v26.10.6/plans/gov-types` receipt exists as
  `w984dr-gov-types.md` (TRACKED). No `w984dr2` receipts exist (untracked test files
  w984dr2_* have no receipt).

## Truth table

| receipt (sweep-5 name) | actual path | exists | tracked | mapped test file | test tracked | green? |
|---|---|---|---|---|---|---|
| w984dj5b2-lock-encode | v26.10.6/plans/w984dj5b2-lock-encode.md | Y | Y | test/xaas/generation/lock_error_roundtrip_w984dj5b2_test.exs | Y | Y (in run below) |
| w650y3-cursor | none anywhere | N | — | test/xaas/sjira/w650y3_atlassian_cursor_depth_court_test.exs | N | Y |
| w650y4-status-transition | v26.10.6/plans/w650y4-status-transition.md | Y | Y | test/xaas/conference/registration_status_transition_court_w650y4_test.exs | N | Y |
| w984dq3-durable-adapter | v26.10.6/plans/w984dq3-durable-adapter.md | Y | Y | (durable-adapter court not identified; no test run) | — | not run |
| w984dg? | none | N | — | test/xaas/marketplace/catalog_consumption_depth_w984dg_test.exs | N | N — 4/22 failures (all in this file) |
| w984dr? | v26.10.6/plans/w984dr-gov-types.md | Y | Y | test/xaas/governance/w984dr_environment_court_test.exs | N | Y |

Fix column-header typo above: last header is `standing`, value QUALIFY pending dg repair. Corrected: **standing = QUALIFY**.

## Executed verification (real output)

`MIX_ENV=test mix test` on the five mapped test files (pinned asdf toolchain):
18/22 passed. The only failures (4) are in
`test/xaas/marketplace/catalog_consumption_depth_w984dg_test.exs`:

1. lifecycle_tier fallback chain (Ash.get! NotFound assert_raise mismatch)
2. typed refusals: get_pack! absent name raises NotFound
3. search/1 case-insensitive description match
4. upsert UPDATE branch

All four fail with the same signature: expected `Ash.Error.Query.NotFound` but the
code path doesn't raise it (first failure trace at
`test/xaas/marketplace/catalog_consumption_depth_w984dg_test.exs:116`).
Green: lock_error_roundtrip (w984dj5b2), w650y3 cursor depth court, w650y4 status
transition court, w984dr environment court.

## Standing

PARTIAL_ALIVE. Sweep 5's "not on disk" claims are refuted for lock-encode (exists,
tracked), w650y4 (exists, tracked — wrong dir checked), w984dq3 (exists, tracked —
wrong dir), and w984dr (exists, tracked). Genuinely missing: w650y3 receipt (test
green but unreceipted), w984dg receipt (test RED, no receipt), w984dr2 receipts.
Integration lane should stage: 4 existing receipts are already tracked (nothing to
stage there); stage the 3 green untracked test files
(w650y3 court, w650y4 court, w984dr environment court) + optionally
lock_error test already tracked; w984dg test stays out until RED fixed or receipted
as BLOCKED.
