# W874 — ultracode-runtime-contract.md post-W749 verification + addendum (receipt)

- **Lane**: W874, v26.10.6 campaign, repo /Users/sac/xaas, branch
  `feat/playwright-surface`, HEAD `a0723bf6` (canonical checkout).
- **Sole written surfaces**:
  `docs/claude/diataxis/reference/ultracode-runtime-contract.md` (addendum
  block only — no W749-era body text changed) + this receipt. No commit, no
  build root.
- **Sources read**: page (W749 refresh), receipts w749, w840, w811, w817,
  w836 (and w752's superseded reading via w836).

## Per-claim verification table

| # | W749-era claim | Verdict | Evidence (spot-checked this lane) |
|---|---|---|---|
| 1 | Ten MCP tools, nine lease-gated, `claim_next` only non-lease verb | HOLDS | 10 `name:` rows, `execution_fabric_controller.ex:72-212` |
| 2 | Malformed directed `claim_next` `epoch_id` = typed `invalid_epoch_id`, never silent fallback | HOLDS | `execution_fabric_controller.ex:417,682` |
| 3 | Closed 10-code failure vocabulary | HOLDS | `runtime_surface/failure.ex:11-28` (`@codes` + `codes/0`) |
| 4 | `live_leases/1`/`renew/1` clock behavior (W840 seam) | HOLDS — page updated via addendum | `lease.ex:372-377` (`live_leases/1` = `DurationBudget.now()` with W840 comment), `lease.ex:513-521` (`renew/1` same seam, `expires_at = now + 30m`) |
| 5 | Health `ultracode_tick` warming_up semantics (W836) | HOLDS — page had no health section; added via addendum, W752 503 reading superseded | `health_controller.ex:56,202-243` (`skipped(:warming_up)`, grace, error branches) |
| 6 | W811 court file + coverage | HOLDS | `test/xaas/ultracode/lease_kernel_deepening_test.exs` on disk |
| 7 | W817 court file + 401-never-406 floor-first on both scopes | HOLDS | `test/xaas_web/jsonapi_content_negotiation_test.exs` on disk; floor-first confirms the page's 406 residual applies only to authenticated incompatible-Accept cells |
| 8 | Witness files listed on the page | HOLDS | all listed test files exist on disk |

## Corrections / supersessions

- No W749-era claim was found stale; nothing in the W749 body was edited.
- W752's "ultracode_tick 503 under Oban testing::manual" reading is
  superseded by W836 (real contract under empty sandbox: `skipped(:warming_up)`,
  aggregate 200; 503 only past boot+7min grace). Recorded in the addendum;
  the page itself never contained the 503 claim.
- The page's token-floor residual ("406 outranks auth on `/internal-api`
  json-api scope") is confirmed, not corrected, by W817's floor-first cells.

## Standing

PARTIAL_ALIVE — all verification is direct code/file reads at exact HEAD
`a0723bf6` (receipts' own test runs cited from their receipts: w840 23+84
green, w836 11/11 x2, w817 16/16 x2; no `mix test` re-run in this lane, per
lane constraint: verification pass + receipt only, no build root). Addendum
falsifier: any cited file:line drifting from the quoted behavior invalidates
the corresponding row. Not committed (coordinator owns integration commits).
