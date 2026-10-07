# W135 — Witness Playwright e2e Receipt

- Lane: W135 (v26.10.6 convergence integration)
- Repo: /Users/sac/xaas (branch feat/playwright-surface)
- Date: 2026-10-06
- Command: `cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH INTERNAL_API_TOKEN=dev-e2e-token npx playwright test e2e/witness.spec.cjs 2>&1 | tail -12`
- Port 4000 pre-check: `lsof -ti :4000` → exit 1 (no stale server to kill)
- Result: **SERVER BOOT FAILED** — Playwright webServer could not start. No tests executed.

## Verbatim output

```
[WebServer]     │
[WebServer]     └─ lib/ash_r2rml/resource.ex:45: AshR2RML.Dsl.Subject (module)
[WebServer]
[WebServer]
[WebServer] == Compilation error in file lib/ash_a2a/resource.ex ==
[WebServer] ** (ArgumentError) @enforce_keys required keys ([:name, :type]) that are not defined in defstruct: [__identifier__: nil, __spark_metadata__: nil]
[WebServer]     (elixir 1.20.2) lib/kernel/utils.ex:229: Kernel.Utils.defstruct/4
[WebServer]     lib/ash_a2a/resource.ex:46: (module)
[WebServer]     (stdlib 7.3) lists.erl:2471: :lists.foldl_1/3
[WebServer] could not compile dependency :ash_surface, "mix compile" failed. Errors may have been logged above. You can recompile this dependency with "mix deps.compile ash_surface --force", update it with "mix deps.update ash_surface" or clean it with "mix deps.clean ash_surface"
Error: Process from config.webServer was not able to start. Exit code: 1
```

## Standing

BLOCKED — dependency `:ash_surface` fails to compile (`ash_a2a/resource.ex:46`
`@enforce_keys`/`defstruct` mismatch under elixir 1.20.2/otp-28). This is a build/dep
state failure, not a witness-spec failure; e2e/witness.spec.cjs was never reached.

## W137 retry

- Port 4000: clear (no listener, `lsof -i :4000 -sTCP:LISTEN` exit=1).
- Command: `PATH=$HOME/.asdf/shims:$PATH INTERNAL_API_TOKEN=dev-e2e-token npx playwright test e2e/witness.spec.cjs`
- Output (tail):
  ```
    ✓  1 renders the read-only certified receipts table (8.5s)
    ✓  2 renders real receipt rows when seeded, else the typed empty state (7.3s)
    -  3 at least the two deterministic seed rows are rendered

    1 skipped
    2 passed (21.1s)
  ```
- Notes: global-setup warned `witness seed did not report W55_SEED_OK (continuing)`; test 3 (seed-row assertion) skipped as designed under that condition. Also an unrelated `AshA2A.HddlOperator redefining module` compile warning appeared.
- Standing: 2/2 runnable passed, 1 skipped (no seed). ALIVE for the read-only certified-receipt surface.

## W162

Rerun of full witness spec after W145's global-setup seed fix (W55_SEED_OK witnessed).

- Port 4000 cleared first (stale beam killed, authorized by lane contract).
- First Playwright attempt with its own webServer boot timed out at 240s
  (config.webServer timeout); server booted manually with the same BOOT
  command sequence and answered 200 on :4000, then Playwright reused it
  (reuseExistingServer=true).
- Command: `PATH=$HOME/.asdf/shims:$PATH INTERNAL_API_TOKEN=dev-e2e-token npx playwright test e2e/witness.spec.cjs`
- Output (real): `[global-setup] W55_SEED_OK: witness rows seeded`;
  3 passed (41.1s) — 0 failed, 0 skipped:
  1. renders the read-only certified receipts table (1.1s)
  2. renders real receipt rows when seeded, else the typed empty state (955ms)
  3. at least the two deterministic seed rows are rendered (985ms)

Target 3 passed / 0 skipped: MET.

## W231 fresh-boot final

- 2026-10-06, integration lane W231, branch feat/playwright-surface, repo /Users/sac/xaas.
- Stale beam on :4000 killed (authorized) before the run.
- Command: `PATH=$HOME/.asdf/shims:$PATH INTERNAL_API_TOKEN=dev-e2e-token npx playwright test e2e/witness.spec.cjs --workers=1`.
- Contention note: repeated attempts hit `:eaddrinuse` on :4000 from concurrent
  lanes' Playwright webservers (`reuseExistingServer: true` made foreign
  servers silently win the port race; two runs SIGKILLed mid-compile). Clean
  pass obtained by pre-booting the exact committed BOOT sequence
  (global-setup --catalog + `PHX_SERVER=true mix run ... --no-halt`), waiting
  for the real `/internal-api/health` probe (200 after 100s), then running the
  suite (Playwright reused the healthy fresh-boot server).
- Boot log: `[global-setup] marketplace catalog written: ... (13 packs)`;
  seeding via e2e/global-setup.cjs (committed seed file, W145) printed
  `W55_SEED_OK: witness rows seeded` (marker source: e2e/global-setup.cjs:107);
  seeded rows asserted live by test 2.
- Result (real output):

```
  ✓  1 e2e/witness.spec.cjs:109:3 › Witness certified-receipt surface › renders the read-only certified receipts table (14.6s)
  ✓  2 e2e/witness.spec.cjs:117:3 › Witness certified-receipt surface › renders real receipt rows when seeded, else the typed empty state (2.0s)
  ✓  3 e2e/witness.spec.cjs:146:3 › Witness certified-receipt surface › at least the two deterministic seed rows are rendered (1.6s)

  3 passed (4.6m)
```

- 3 passed / 0 skipped / 0 failed. Target MET. Server processes cleaned up
  after the run; port 4000 left clear.

## W295 post-W257

Date: 2026-10-06. Lane W295, v26.10.6 convergence. Post-W257 witness e2e
confirmation after the empty-state isolation fix landed.

Environment: port 4000 cleared (stale beams SIGKILLed, authorized). First two
runs failed on cross-lane contention — (1) `eaddrinuse` on :4000 (another
lane's server grabbed the port mid-boot) and (2/3) SIGKILL while queued on the
shared `_build/dev` lock held by other lanes' beams. Resolution: booted a
lane-private server (`MIX_BUILD_ROOT=_build-lane295 PHX_SERVER=true mix run
--no-halt`, token dev-e2e-token) — healthy after 44s, Playwright reused it
(`reuseExistingServer: true`).

Command:

```
cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH INTERNAL_API_TOKEN=dev-e2e-token npx playwright test e2e/witness.spec.cjs
```

Result (real output):

```
  ✓  1 e2e/witness.spec.cjs:109:3 › Witness certified-receipt surface › renders the read-only certified receipts table (1.5s)
  ✓  2 e2e/witness.spec.cjs:117:3 › Witness certified-receipt surface › renders real receipt rows when seeded, else the typed empty state (2.9s)
  ✓  3 e2e/witness.spec.cjs:146:3 › Witness certified-receipt surface › at least the two deterministic seed rows are rendered (1.2s)

  3 passed (1.2m)
```

- 3 passed / 0 skipped / 0 failed. Target MET (post-W257 empty-state isolation
  fix holds on the live surface). Lane server left running on :4000 (pid tree
  22819/27672/28907) — kill before any further lane clears the port.
