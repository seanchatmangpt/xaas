# W317 — PW Final Tokened Browser-Rung Receipt

## Subject

- Repo: `/Users/sac/xaas` @ `feat/playwright-surface`
- HEAD: `d1db2b03179975213c14663b9dbd86b5ac2a14cf`

## Command

```bash
cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH PW_PORT=4017 INTERNAL_API_TOKEN=w317-lane-token npx playwright test
```

Port `PW_PORT=4017` (leased port, no eaddrinuse fallback needed — 4017 used throughout).

## Results (real run, 2026-10-06)

- **passed: 96**
- **failed: 0**
- **skipped: 2**
- **flaky: 0**
- Duration: 32.0s
- webServer booted the real Phoenix app via the W310 BOOT readiness gate
  (polls `/internal-api/health`); no boot failure, server log not needed.

## --list sanity (P3-3)

```
Total: 98 tests in 22 files
```

Not "0 tests in 0 files" — P3-3 satisfied. 96 + 2 skipped = 98, matches --list exactly.

## Standing

ALIVE — full browser rung (DoD 5) final leg executed on exact subject `d1db2b03`,
real Chromium transport against the real Phoenix server, zero failures, zero flaky.

## Falsifier (would have refuted)

- Any non-zero failed/flaky count, or `--list` reporting 0 tests, or webServer
  boot failure on port 4017. None observed.
