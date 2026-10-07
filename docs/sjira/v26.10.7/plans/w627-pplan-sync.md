# W627 — ash_pplan v26.10.7 pre-release sync

Lane: W627, v26.10.7 release campaign. Repo: `~/ash_pplan` (canonical checkout, branch `fix/ggen-verify-header`).
Authority: release-directive (commit+push permitted, no force/rebase).

## Steps and real exits

| step | command | result |
|---|---|---|
| fetch/re-read | `git fetch origin`; `git merge-base --is-ancestor origin/main HEAD` | exit 0 → ANCESTOR (not diverged). origin/main = HEAD = `6dbd3b0` pre-work (W601p seal in place; main had NOT been advanced beyond seal) |
| version diff | `git diff mix.exs` | `@version "26.10.3"` → `"26.10.7"` (W618's uncommitted bump) |
| (1) commit bump | message → `/tmp/w627-msg.txt`; `git commit -F /tmp/w627-msg.txt` | exit 0, commit `862f0c0` on `fix/ggen-verify-header` |
| (2a) push branch | `git push origin fix/ggen-verify-header` | exit 0, `6dbd3b0..862f0c0` |
| (2b) ff main | `git push origin fix/ggen-verify-header:main` | exit 0, `6dbd3b0..862f0c0` (pure fast-forward, no merge commit) |
| (3) OS-20 ancestry | `git merge-base --is-ancestor 7eeaaa1 origin/main` | exit 0 → YES, `7eeaaa1` (v26.10.6 OS-20 dual-safe Map.update) is ancestor of main at `862f0c0` |
| (4a) compile | `PATH=$HOME/.asdf/shims:$PATH mix compile --warnings-as-errors` | exit 0 — `Compiling 152 files (.ex)`, `Generated ash_pplan app`, zero warnings |
| (4b) runtime version | `mix run -e 'IO.puts(...[:version])'` | `26.10.7` |
| (4c) artifact version | `grep -o '"26.10.7"' _build/dev/lib/ash_pplan/ebin/ash_pplan.app` | `"26.10.7"` present in compiled app manifest, exit 0 |

## Final state

- origin/main = `862f0c0` = origin/fix/ggen-verify-header (fast-forwarded).
- `7eeaaa1` (sealed OS-20) ⊂ main. W601p seal `6dbd3b0` ⊂ main.
- Standing: **ALIVE** (all four task steps executed with real exits; compile clean under pinned asdf toolchain elixir 1.20.2-otp-28).

## Falsifier (already run, passed)

Compile-with-zero-warnings was W291's goal; fresh read here gives exit 0 on 152 files.
