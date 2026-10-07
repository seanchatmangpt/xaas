# W377 — Pin Integrity Audit (replay-identity precondition)

Date: 2026-10-06. Read-only audit; no fixes applied.
Method: pins enumerated from `/Users/sac/xaas/mix.lock` (git rows), `/Users/sac/xaas/mix.exs`
(git deps, lines 104/108/245/253 — same SHAs as lock, full 40-hex in both),
and `/Users/sac/xaas/ggen.toml` line 21 (`version = "518572b6…"` marketplace pin).
Object check: `git -C <repo> cat-file -e <sha>^{commit}`. Reachability:
`git -C <repo> merge-base --is-ancestor <sha> HEAD` + `git branch -a --contains <sha> | head -3`.

## Pin table

| Repo | Full SHA | Source | cat-file | Ancestor of HEAD | Containing refs | Verdict |
|---|---|---|---|---|---|---|
| ash_a2a | `86214551de93fc8ab395f5ed0b84d32922a5d99b` | mix.lock:7 / mix.exs:104 | EXISTS | ancestor | feat/ci-hygiene, feat/tck-vuln-hardening, main | RESOLVABLE+REFED |
| ash_pplan | `5f10c9798b783c2023a6bfaa892c000630476f05` | mix.lock:26 / mix.exs:253 | EXISTS | ancestor | fix/ggen-verify-header (current), main, origin/HEAD | RESOLVABLE+REFED |
| ash_r2rml | `0d5320f6c5e9a43bb3e8dcb0f30d301b1ebb64d7` | mix.lock:27 / mix.exs:108 | EXISTS | ancestor | fix/v26.9.29-from-source-head (current), origin/main | RESOLVABLE+REFED |
| ex4pm | `9f7aecda87e5110f668f824bbae760f6c97f88e1` | mix.lock:69 / mix.exs:245 | EXISTS | ancestor | main, origin/HEAD | RESOLVABLE+REFED |
| ggen-marketplace | `518572b6b53103922ae8a27636a00e982a0907c4` | ggen.toml:21 | EXISTS | ancestor | archive/wip/ggen-marketplace-main-20260924T0600Z, chore/ci-pareto, claude/amazing-cray-ofa6al (+more) | RESOLVABLE+REFED |

## Verdict summary

- 5/5 pins RESOLVABLE+REFED (all objects exist in their source repo and are
  ancestors of each repo's current HEAD, hence protected from GC by branch refs).
- 0 MISSING. 0 RESOLVABLE+UNREFFED. No replay risk, no blockers.

## Notes

- No other git-SHA rows exist in mix.lock beyond the four above (verified by
  exclusion grep); mix.exs git refs match lock SHAs exactly (full 40-hex, no
  abbreviation resolution needed).
- ash_pplan pin sits on current branch `fix/ggen-verify-header` and main;
  ash_r2rml pin on `fix/v26.9.29-from-source-head` and origin/main — both refed.
