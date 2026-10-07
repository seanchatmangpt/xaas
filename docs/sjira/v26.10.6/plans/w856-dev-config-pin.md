# W856 — Dev-config court pin (config/dev.exs ash_a2a strict posture)

- **Subject**: `/Users/sac/xaas`, branch `feat/playwright-surface`, HEAD `a0723bf6` (+ working-tree extension of `test/xaas/ash_a2a_runtime_config_court_test.exs`; `config/dev.exs` restored to its pre-session working state — see incident below)
- **Standing**: ALIVE (court green ×2, mutation verified)
- **Authority**: W803 receipt `docs/sjira/v26.10.6/plans/w803-dev-boot-fix.md` (F1 repair: dev `cluster_size` 1→3); lane assignment W856, v26.10.6 campaign
- **Lane**: W856, one canonical checkout, no worktrees; build root `_build-laneW856`

## Change

`test/xaas/ash_a2a_runtime_config_court_test.exs` (extend-only):

- `@dev_exs` path attribute + `read_dev!/0` (`Config.Reader.read!(@dev_exs, env: :dev)`), same source-level technique as the file's existing prod/test blocks.
- New `describe "dev block (config/dev.exs, W803 F1 repair)"`:
  - pins `security_profile == :strict`, `receipt_store == AshA2A.ReceiptStore.Ekv`, and `cluster_size == 3` **exact** (with inline WHY comment citing `deps/ash_a2a/lib/ash_a2a/receipt_store.ex:191-193` `{:insufficient_cluster_size, n}` refusal and the W752-F1/W803 provenance). Exact-3 (not `>= 3`) so a silent 2 also fails.
  - pins dev `data_dir` durable (non-`/tmp`).
  - The existing prod/test pins untouched; still green.

## Verification (real tails)

- Run 1 (post-compile, fresh lane root): `Result: 10 passed` (exit 0). Command: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW856 mix test test/xaas/ash_a2a_runtime_config_court_test.exs`
- Mutation: changed dev.exs `cluster_size: 3` → `1`; court result `9/10 passed, Failed: 1 test` — the single failure is exactly the new assert (`assert Keyword.get(ekv, :cluster_size) == 3` at `test/xaas/ash_a2a_runtime_config_court_test.exs:71`/`:81`, `left: 1, right: 3`). Then reverted.
- Run 2 (post-revert): `Result: 10 passed`.
- Mock gate: no mocking introduced; real `Config.Reader.read!` on the real file, real dep modules. Chicago-compliant.

## Incident (disclosed): transient clobber of pre-session dev.exs working state

The mutation revert used `git checkout -- config/dev.exs`, which reset the file to HEAD —
but the W803 cluster_size fix was **uncommitted working-tree state** (HEAD `a0723bf6` still
has `cluster_size: 1` at the dev `receipt_store_ekv_opts` block). The pre-session file was
recovered **byte-identical** from the session's own verbatim grep of the block (comment
block at dev.exs:501-505 + `cluster_size: 3`), restored via Edit, and re-verified:

- `git diff config/dev.exs` shows exactly the W803 fix hunks (+4 comment lines,
  `cluster_size: 3`) vs HEAD, nothing else.
- Run 2 above (10 passed) ran against the restored file.

Lesson / permanent guard for the coordinator: **mutation reverts in a shared canonical
checkout must be against the saved pre-mutation bytes, never `git checkout --`** — HEAD is
not the pre-session state in a campaign with uncommitted landed fixes. (Lane leases/build
roots are the coordinator's; per same-checkout fanout law this receipt records the
transition, not a scope grab.)

## Open items

- `_build-laneW856` deletion was denied by the permission system; left in place for the
  coordinator per the lane contract ("else leave for coordinator").
- W856 lands as working-tree changes on `feat/playwright@ a0723bf6`; commit/integration
  owned by coordinator.
