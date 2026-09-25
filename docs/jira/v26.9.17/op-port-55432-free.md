# OP Free Port 55432 — close ash_a2a's last 8 invalid tests (operator act + verification)

## Summary

ash_a2a's court is otherwise fully green (1912 tests, 0 failures, 58 doctests,
19 properties at `801374a` on `main`). Exit 2 comes solely from 8 *invalid*
suites — `ObanDeliveryQualification` + `ScheduledSweepQualification` — whose
`setup_all` raises-by-design when Postgres on host port `:55432` is
unreachable. The port is squatted by a stale Docker Desktop backend (pid
62485); colima is also degraded (containerd blob I/O errors). Freeing shared
Docker infrastructure is an operator machine act.

## Status

BLOCKED — awaiting operator act (free host port :55432).

## Scope

1. Operator: quit/restart Docker Desktop (backend pid 62485) or otherwise free
   `:55432`; stand up whatever Postgres the repo's test config expects on it
   (see the suites' `setup_all` for the exact connection contract).
2. Agent verification slice:
   ```bash
   cd /Users/sac/ash_a2a
   mix test --only qualification   # or the two suites by name
   mix test                        # expect 1912 tests, 0 failures, 0 invalid
   ```
3. Record exit codes; boundary standing for cap-orchestration upgrades
   PARTIAL_ALIVE → ALIVE in `RELEASE-STATE-v26.9.17.md`.

## Key Invariant(s)

- The 8 suites must stay raise-by-design on unreachable DB (fail-closed
  invalids, not silent skips) — do not "fix" the guards.
- Do not reroute the repo's test config to another port to dodge the squatter
  (documented adversarial probe already refused that).

## Relationship to Existing Work

- `boundary-ash-a2a.md` (court result + squatter diagnosis);
  `RELEASE-STATE-v26.9.17.md` ADDENDUM item 1.
- Last open slice of `qualified ash-a2a/cap-orchestration`.

## Falsifiers / What Would Defeat This

- Any of the 1912 green tests regress when the DB suites run.
- The suites pass by connecting to the WRONG database (verify the connection
  contract, not just green).

## History

| ts | standing | branch+SHA | gates+exits | remaining |
|---|---|---|---|---|
| 2026-09-17T12:30-07:00 | BLOCKED | ash_a2a main @ 801374a | mix test: 1912/0 failures, 8 invalid, exit 2 | free :55432 → rerun → standing ALIVE |
