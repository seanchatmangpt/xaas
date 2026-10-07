# W462 — ash_pplan pin advance staging (P0-3 close-out)

Lane W462, 2026-10-06. Staging only — no edits to mix.exs/mix.lock, no commits.
All SHAs re-verified live from disk this session.

## 1. Current state (live)

| item | value |
|---|---|
| xaas `mix.exs` ash_pplan ref (line ~253) | `5f10c9798b783c2023a6bfaa892c000630476f05` |
| xaas `mix.lock` ash_pplan (line 26) | `5f10c9798b783c2023a6bfaa892c000630476f05` (git, `[ref: …]`) |
| sibling `~/ash_pplan` HEAD | `414a393d17afa6637ce1db5c34fab09e032c58c8` (branch `fix/ggen-verify-header`) |
| sibling dirty files | 8 modified + `docs/sjira/v26.10.6/` untracked |
| W291's two patches | **DIRTY — NOT committed** |

## 2. Sibling diff `5f10c979..414a393d --stat`

```
 bin/ggen-verify | 29 ++++++++++++++++++-----------
 1 file changed, 18 insertions(+), 11 deletions(-)
```

Single commit in range: `414a393 docs(ggen-verify): update stale header for re-homed vendor packs`. Only `bin/ggen-verify` changes. W291's patches are NOT in this range.

## 3. GATE FINDING: WAITING-ON-W291-COMMIT

W291's two patches exist only as uncommitted working-tree modifications in `~/ash_pplan`:

`lib/ash_pplan/fond/policy_supervisor/offers.ex` (1 deletion):
```diff
-  defp rank(_), do: 9
```

`test/support/examples/qualified_fulfillment/ledger.ex` (1 line changed):
```diff
-      def undo(%{path: path}, _a, _c, _o), do: (File.rm(path) && :ok) || :ok
+      def undo(%{path: path}, _a, _c, _o), do: (File.rm(path); :ok)
```

Both verified verbatim via `git -C ~/ash_pplan diff` this session.

Additional dirty files beyond the two named patches (all in the same working tree, must also be committed or stashed before any pin advance): `docs/demonstration.md`, and `lib/ash_pplan/runtime_contract/{authority_gate,exact_subject,receipt,refusal,replay}.ex` (1-2 line edits each).

**Verdict**: a pin advance to `414a393d` today picks up only the `bin/ggen-verify` docs change — neither W291 patch would be included. Advance must wait until W291 commits the working tree and a new HEAD beyond `414a393d` exists.

Secondary gate (transport): mix fetches from `https://github.com/seanchatmangpt/ash_pplan.git`. Local sibling commits are NOT fetchable until pushed. Before executing, verify `git -C ~/ash_pplan log origin/<branch>..HEAD` is empty (pushed).

## 4. Staged procedure (execute when gate opens)

Preconditions:
- (a) W291 committed in `~/ash_pplan`; record new HEAD SHA as `N`.
- (b) Branch pushed to origin (`git -C ~/ash_pplan fetch && git -C ~/ash_pplan log origin/HEAD..HEAD` → empty).

Steps:
1. Edit `mix.exs` line ~253: ref `5f10c9798b783c2023a6bfaa892c000630476f05` → `N` (full SHA). Update adjacent comment `Ref advanced 2026-10-06 …` to the new date/SHA.
2. Re-lock (never hand-edit mix.lock):
   ```
   PATH=$HOME/.asdf/shims:$PATH mix deps.update ash_pplan
   ```
   (asdf shims first — homebrew elixir 1.19.5 shadows asdf's pinned toolchain.)
3. Compile gate:
   ```
   PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix compile --warnings-as-errors
   ```
   W392's pplan compile failure was REFUTED (phantom) per campaign record — do not treat a pplan compile error as expected; a real failure here is a real failure. Fresh-root (`rm -rf _build/test`) vs shared build per w175 precedent — record which was used.
4. Test gates (w41-era expected baseline, grep-verified counts this session):
   - `test/xaas/chicago/bridges/pplan_test.exs` — 5 tests
   - `test/xaas/ultracode/recovery_policy_test.exs` — 7 tests
   - `test/xaas/ultracode/sa2a_recovery_policy_test.exs` — 1 test
   - `test/xaas/frontier_evidence_test.exs` — 4 tests
   Total expected: **17 tests, 0 failures**.
   ```
   PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test \
     test/xaas/chicago/bridges/pplan_test.exs \
     test/xaas/ultracode/recovery_policy_test.exs \
     test/xaas/ultracode/sa2a_recovery_policy_test.exs \
     test/xaas/frontier_evidence_test.exs
   ```
5. Record receipt: old/new SHAs, compile exit, test counts.

## 5. Rollback

Revert the mix.exs ref line to `5f10c9798b783c2023a6bfaa892c000630476f05` (restore old SHA + comment), then re-run `PATH=$HOME/.asdf/shims:$PATH mix deps.update ash_pplan` so mix.lock re-locks to `5f10c979`. Rollback never hand-edits mix.lock either.

## 6. Receipt summary

- Current pins re-verified live: mix.exs ref = mix.lock = `5f10c979…f05`; sibling HEAD `414a393d…c8` on `fix/ggen-verify-header`, 8 dirty files, W291 patches uncommitted.
- Diff `5f10c979..414a393d`: only `bin/ggen-verify` (docs-level, no functional xaas impact).
- Gate: **WAITING-ON-W291-COMMIT** — plus push to origin before execution.
- Expected post-advance verification: 17 pplan-bridge tests green under `MIX_ENV=test`.
