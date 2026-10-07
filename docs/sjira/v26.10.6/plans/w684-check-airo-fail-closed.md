# W684 — check_airo.sh fail-closed (ggen + ferroplan)

Date: 2026-10-07. Lane W684, v26.10.6 campaign. Follows W668 verification
(`docs/cro/artifacts/airo-wiring-ledger-verification-w668.md`): `scripts/check_airo.sh`
printed `check_airo: FAIL` on missing vocab cache but could exit 0 (exit status was
not bound to the failure flag on every path).

## Subjects (canonical checkouts, not committed)

| repo | branch | HEAD |
|---|---|---|
| /Users/sac/ggen | feat/v26.10.5-release-cut | bc4d23909dbcfd51b368f182f94655860041b04f |
| /Users/sac/ferroplan | main | c03787687da4c0cd7d11d2f8b1bf1a9851ef8758 |

Only `scripts/check_airo.sh` touched in each. No commits, no branch switches.

## Change (minimal, same shape in both repos)

1. rdflib parse block: `/tmp/airo-venv/bin/python - "$TTL" <<'EOF'` wrapped as
   `if ! ... <<'EOF' ... EOF; then echo "FAIL: rdflib parse failed (TTL or vocabulary)"; fail=1; fi`
   — covers missing TTL, missing `/tmp/airo.ttl`, rdflib parse errors.
2. Structural fallback block: same wrap with `FAIL: structural check failed`.
3. Final line replaced:
   `[ "$fail" -eq 0 ] && echo PASS || { echo FAIL; exit 1; }`
   → `if [ "$fail" -eq 0 ]; then echo "check_airo: PASS"; exit 0; else echo "check_airo: FAIL"; exit 1; fi`
   — explicit exit 0 only on genuine PASS; exit text and code now provably coupled.

Output text of every pre-existing line preserved. Diff: +7/-3 lines per repo
(identical except ferroplan's `[.]$`/`:N` path-strip sed, pre-existing).

Note: pre-edit runs under `bash script` happened to exit 1 via `set -e` aborting on
the failing python/grep, but without the FAIL summary line and relying on set -e
accident (set -e is not honored in all invocation contexts); exit status is now
explicitly bound to `fail` on every branch.

## Falsifier matrix — real runs (bash scripts/check_airo.sh)

| repo | path | exit | last line |
|---|---|---|---|
| ggen | happy path (cache present) | 0 | `check_airo: PASS` |
| ggen | `/tmp/airo.ttl` moved away | 1 | `check_airo: FAIL` |
| ferroplan | happy path | 0 | `check_airo: PASS` |
| ferroplan | `/tmp/airo.ttl` moved away | 1 | `check_airo: FAIL` |

Additional: ggen with corrupted `docs/airo-risk-description.ttl` (unbalanced quote) →
exit 1, `FAIL: no cited paths...` + `FAIL: structural check failed` + `check_airo: FAIL`.
TTL restored byte-identical afterward.

Cache protocol: `/tmp/airo.ttl` copied to backup, `mv` hidden, both failure runs
executed, `mv` restored, `cmp` confirmed byte-identical. Pinned cache never deleted.
(Env note: `/tmp/airo-venv` is absent on this host, so both parse runs exercised the
structural-fallback branch; the rdflib branch uses the identical if-! wrapper.)

## Standing

ALIVE (observed): both scripts fail-closed on missing cache (exit 1 + FAIL text) and
exit 0 only on PASS, at the exact HEADs above. The W668 finding is closed at script
level; wiring-ledger terminal status can be updated to reflect fail-closed checks.

Uncommitted by lane contract — coordinator owns commits.
