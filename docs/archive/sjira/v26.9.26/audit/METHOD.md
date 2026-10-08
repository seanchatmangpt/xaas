# Audit METHOD — lane L10 (adversary audit / skeptic court), wave v26.9.26

Court against the other nine lanes and the coordinator's convergence claims.
Lane ownership: `docs/sjira/v26.9.26/audit/` ONLY. No git state transitions (coordinator
owns git; read-only git used here). Canonical checkout: `/Users/sac/xaas`.

## The bar

A claim survives ONLY with observed evidence, all three:
1. the file exists,
2. content matches the claim,
3. command output cited below (verbatim excerpts, with UTC timestamp of observation).

Standing vocabulary: `ALIVE | PARTIAL_ALIVE | BLOCKED | UNKNOWN | UNSUPPORTED | REFUSED_<REASON>`.
`inspection ≠ execution`; absence observed at time T is recorded as UNKNOWN (not a violation)
because lanes L1–L9 write concurrently — a later pass may find the surface.

## Session identity

- Repo: `/Users/sac/xaas`, branch `feat/alooop-lane2-autonomic-loop`, HEAD `dd32425a53af0614e03cd0a2e872656257ff9f90`.
- Observations made 2026-09-26 (UTC timestamps per section).

## Coordinator convergence claims — checked 2026-09-26T20:33:34Z

| claim | command | observation | verdict |
|---|---|---|---|
| origin/main f1d42eb contained in HEAD | `git rev-parse HEAD; git branch --show-current; git merge-base --is-ancestor f1d42eb HEAD` | HEAD = `dd32425a53af0614e03cd0a2e872656257ff9f90` on `feat/alooop-lane2-autonomic-loop`; exit 0, `f1d42eb CONTAINED in HEAD`; `origin/main` = `f1d42eb39a71d57787a05ab2e0f2a24f3806cff5` | SURVIVES |
| merge commit dd32425 exists with 4 files changed | `git show --no-patch --format='...' dd32425; git show --stat --format='' dd32425` | hash=`dd32425a53af0614e03cd0a2e872656257ff9f90`, parents=`d436f948… 9b565b51…` (a true 2-parent merge), date `Sat Sep 26 13:30:05 2026 -0700`, subject `merge(origin/weekend/zcode-yolo-dispatch-v26.9.26): yolo dispatch posture courts into wave base`; stat tail: `lib/xaas/ultracode/dispatch.ex | 22 ++++-`, `scripts/xaas-glm-failover-dispatcher.sh | 9 ++-`, `test/xaas/ultracode/dispatch_test.exs | 5 +-`, `test/xaas/ultracode/dispatcher_permission_test.exs | 94 +++…`, `4 files changed, 120 insertions(+), 10 deletions(-)` | SURVIVES |
| verify/v26.9.26-substitution-receipt-binding has 0 commits beyond origin/main | `git rev-list --count origin/main..origin/verify/v26.9.26-substitution-receipt-binding` | `count … = 0` (empty set) | SURVIVES |
| wave base VERSION still 26.9.22 (cut not yet done — coordinator-owned, expected) | `cat VERSION` | `VERSION = 26.9.22` | SURVIVES (as expected state, not an achievement) |

## Lane surfaces audited and when

Each pass records what exists on disk at the moment of observation.

- **L1** `docs/sjira/v26.9.26/goal.ttl` — bar: mirrors `docs/sjira/v26.9.23/goal.ttl` graph shape
  (same predicate style); UNKNOWN placeholders only; any declared ALIVE inside a scaffold = violation.
- **L2** CHANGELOG entries trace to real commits — spot-check 3 via `git log` (entry SHAs must exist;
  entry text must not contradict the commit).
- **L3** no secrets in `CLAUDE.md` / `README.md` — grep for token-shaped strings
  (`sk-`, `ghp_`, `AKIA`, `Bearer`, long base64/hex runs).
- **L4** canonical contract sha `390c9a3b8677fb9b0a408e6072d32868fd45901b9fdaa4ab62ec7603b6040f6a`
  documented somewhere in the tree, AND `gall-work.contract.json` itself unmodified
  (`git diff --stat` + `git status --porcelain` for the file must be empty; `shasum -a 256` must equal
  the canonical sha).
- **L8** no token values written under `.ggen/` — grep for `dev-local-`.

## Verdict scale

- `ALIVE` = clean: claims checked, zero violations.
- `PARTIAL_ALIVE` = minor issues (documentation/consistency nits, nothing blocking).
- `BLOCKED` = blocking violation (secret leaked, contract file mutated, fabricated claim).
- `UNKNOWN` = surface not present at final observation time (lane did not land; not a
  fabrication finding, but unverified).

Per-lane verdict files: `L<N>-<slug>.verdict.json` beside this file.
