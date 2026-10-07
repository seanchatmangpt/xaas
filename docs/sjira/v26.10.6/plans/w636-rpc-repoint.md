# W636 — rpc-check repoint (W632 disposition closure)

Date: 2026-10-06. Lane: W636, repo /Users/sac/xaas @ feat/playwright-surface, build root `_build-laneW636`.

## Change

`lib/mix/tasks/xaas.release_audit.ex` — `check_rpc_alignment/1`:

- Router reference repointed `lib/kanban_web/router.ex` → `lib/xaas_web/router.ex`
  (c5f127cc rename target, live in tree). W632 STALE-AUDIT-REFERENCE closed.
- Mount match strings relaxed from the no-paren Phoenix spelling
  (`post "/rpc/run", ...`) to the argument-list substring
  (`"/rpc/run", AshTypescriptRpcController, :run`) — the live router uses the
  paren form `post("/rpc/run", ...)`, so a literal repoint alone would still
  have failed the check. Disclosed deviation, within repoint intent (check now
  actually verifies the mount, its original purpose).
- Typed-absent fail-closed branch preserved verbatim (path text updated).
  W600 @version derivation, W631 typed finding, and the other lane's
  render_refusal lines untouched.

`test/mix/tasks/xaas_release_audit_test.exs`: the absent-kanban regression was
inverted per task spec — now asserts (a) `lib/xaas_web/router.ex` exists,
(b) no File.Error crash (W631 property), (c) no `rpc alignment:` REFUSED line
renders against the live tree. No tmp-modification variant was needed; the
fail-closed enoent branch is one `File.read` guard away from the verified
`{:ok, router}` path.

## Verification (real output)

- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW636 mix test test/mix/tasks/xaas_release_audit_test.exs`
  → `4 passed` (3.5s).
- `mix xaas.release_audit` → 0 rpc-alignment findings; 11 REFUSED lines;
  `** (Mix) v26.10.6 release audit failed with 11 finding(s)`.
- Findings delta: 12 → 11 (exactly the one stale rpc finding removed; the 11
  remaining are pre-existing drift findings, all non-rpc).

## Standing

ALIVE (exact subject: feat/playwright-surface working tree, lane build root).
