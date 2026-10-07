# W650e — Restage of the 12 foreign files swept into aborted 4450a277

**Standing: ALIVE** — all 12 files landed in `7d1c7cc2` via explicit pathspec,
byte-identity against the aborted commit verified by diff; earlier completed-lane
receipts landed in this lane's second commit.

- Subject: `~/xaas` @ `feat/playwright-surface`, base `2a406340` (W647's receipt commit)
- Incident (from W647's receipt, committed as `2a406340`): W647's first commit attempt
  `4450a277` swept 12 foreign staged files; the soft-reset repair unstaged them, which
  dropped 10 receipts to untracked and 2 (`CRO-LOOP.md`, `CYCLE-LOG.md`) to modified.
- Actuator: git 2.5x, explicit pathspec `git add` only. No force, no push.

## File disposition

### Group 1 — the 12 foreign files (commit `7d1c7cc2`)

Identified as exactly the non-W647 files in `git show 4450a277 --stat` (13 files total,
12 foreign + W647's own receipt, now separately committed as `2a406340`).

| file | state after incident | verified | owner-lane standing | disposition |
|---|---|---|---|---|
| docs/cro/CRO-LOOP.md | M | diff vs 4450a277 = ∅ | CRO entry (W620) | landed in 7d1c7cc2 |
| docs/cro/CYCLE-LOG.md | M | diff vs 4450a277 = ∅ | CRO entry (W620) | landed in 7d1c7cc2 |
| plans/w607-beam4pm-map-update.md | ?? | spot-check (head) | ALIVE (WP-4/OS-20 sweep) | landed in 7d1c7cc2 |
| plans/w609-pplan-map-update.md | ?? | — | completed lane | landed in 7d1c7cc2 |
| plans/w611-ashsurface-reverify.md | ?? | — | completed lane | landed in 7d1c7cc2 |
| plans/w616b-ledger-commit.md | ?? | — | completed lane | landed in 7d1c7cc2 |
| plans/w624-spec08-commit.md | ?? | — | completed lane | landed in 7d1c7cc2 |
| plans/w625-pep-skeleton.md | ?? | spot-check (head) | completed; +15-line SUPERSEDED addendum by W638b on disk (legitimate post-abort lane edit, disclosed) | landed in 7d1c7cc2 |
| plans/w627-pplan-sync.md | ?? | — | completed lane | landed in 7d1c7cc2 |
| plans/w630-push7.md | ?? | — | completed lane | landed in 7d1c7cc2 |
| plans/w631-gitignore-sweep.md | ?? | spot-check (head) | completed lane | landed in 7d1c7cc2 |
| plans/w631b-pulls.md | ?? | — | completed lane | landed in 7d1c7cc2 |

Byte-identity: `git diff 4450a277 7d1c7cc2 -- <12 paths>` → only delta is w625's
disclosed SUPERSEDED addendum (+15 lines, authored by lane W638b after the abort).

### Group 2 — earlier completed-lane receipts still untracked (this lane's second commit)

| file | standing (re-read from file) | disposition |
|---|---|---|
| plans/w641-dev-migrate.md | ALIVE | landed |
| plans/w641a-affidavit-migration.md | BLOCKED(pack-contract-divergence) — terminal typed refusal | landed |
| plans/w641b-ferroplan-migration.md | BLOCKED(pack-capability-missing) — terminal | landed |
| plans/w641c-graphlaw-adoption.md | BLOCKED(integration-design-needed) — since unblocked by W647 | landed |
| plans/w642-pack-completion.md | PARTIAL_ALIVE | landed |
| plans/w642b-migration-unblock.md | ALIVE | landed |
| plans/w643-unification-receipt.md | ALIVE(build-surface) + PARTIAL_ALIVE(legs) | landed |
| plans/w644-wasm-roundtrip.md | ALIVE(load-leg) | landed |
| plans/w648-version-audit.md | completed audit | landed |
| plans/w649-fleet-tag6.md | ALIVE (xaas row re-read) | landed |
| plans/w650-closure-receipt.md | DRAFT-closure (by design) | landed |
| plans/w650c-closure-v2.md | closure v2 | landed |
| plans/w650d-relay.md | W644 load-leg ALIVE re-verified | landed |
| v26.10.7/_CLOSURE_RECEIPT.md | closure receipt | landed |
| plans/_GRAPHLAW_WASM_UNIFICATION_RECEIPT.md | unification receipt | landed |

Note: `w650b` does not exist on disk (no such receipt was ever written); `w647`'s xaas
receipt is already committed (`2a406340`) — confirmed, not re-committed.

## Verification

- `git diff 4450a277 7d1c7cc2 -- <12 paths>` → ∅ except disclosed w625 addendum
- 3 head spot-checks (w607, w625, w631b) → content intact, headers match receipt subjects
- Explicit pathspec staging only; no `git add -A`/`-u`, no stash, no force, no push

## Open edges

- Still-untracked receipts NOT in scope (owner lanes' jurisdiction; not named by the
  coordinator): w601*, w602*, w603*, w604*, w605*, w606*, w608, w610, w612, w613 (M),
  w614, w615, w615b, w616, w617–w623, w626, w628, w628b, w629, w632, w633, w635, w636,
  w636b, w637, w637b, w638, w638b, w639, and all v26.10.6 `w984*` plan files, `tests/`,
  `lib/`/`test/` artifacts. These remain with their owning lanes.
- Falsifier: "a restaged file differs from its aborted-commit content without a
  disclosed lane edit" — not triggered (only w625, disclosed).
