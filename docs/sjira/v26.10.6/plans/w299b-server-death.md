# W299b — Server-Death Diagnosis (v26.10.6 convergence)

- Subject: `/Users/sac/xaas` @ branch `feat/playwright-surface`, working tree, no lib changes (none required — see verdict)
- Date: 2026-10-06
- Scope: diagnose W299's 2/2 mid-suite server death ("socket hang up" → ECONNREFUSED near `/a2a/v1` / `/internal-api/execution/mcp` traffic); own lib fix only if the death is a dispatch-path crash.

## Verdict (front-loaded)

**The server death is NOT a request-handling crash.** It is process-death by lost I/O
device: the `mix run --no-halt` VM terminates the whole runtime when it writes to a
closed/lost stderr (`:standard_error` "the device does not exist" → ArgumentError → init
terminates → `erl_crash.dump`). The suspect endpoints are innocent — 30/30 hammer with
valid + invalid bodies, zero death, zero dispatch-path exceptions.

Witnessed mechanism reproduction: booting the exact committed BOOT chain with fd 2
closed produces the byte-identical crash-dump signature (dump @ 15:27:xx, same slogan,
same `io.erl:202 :io.put_chars(:standard_error, ...)` stack).

## Evidence

### 1. W299's actual crash dump (the run-1 death)

`/Users/sac/xaas/erl_crash.dump` @ Oct 6 15:02:55 (run 1 died
~15:03; run-1 archive log mtime 15:05):

```
Slogan: Runtime terminating during boot ({badarg,[{io,put_chars,
  [standard_error,[<<...">> (EXIT from #PID<0.94.0>) an exception was raised:
    ** (ArgumentError) errors were found at the given arguments:
  * 1st argument: the device does not exist
        (stdlib 7.3) io.erl:202: :io.put_chars(:standard_error, ...)
```

"During boot" is misleading — the death escalates through init (the mix eval process
`<0.94.0>`), so ERTS labels it boot termination. "The device does not exist" = fd 2 was
closed at the OS level. This is an I/O-transport death, not OOM and not an application
exception.

### 2. No OOM

`log show --last 6h` grep for kill/jetsam/memorystatus × beam/erl/mix: zero matches.
No jetsam, no SIGKILL-by-OOM evidence.

### 2b. Complementary witnessed mechanism: cross-lane :4000 interference

During this diagnosis, live: two foreign lane VMs held or answered :4000 during my two
fresh boot attempts (both boots died `eaddrinuse`), and a concurrent lane's server
(beam 11178) served a node client on :4000 mid-diagnosis. The repo's standing convention
"kill all beams on :4000" is a direct cross-lane SIGKILL channel: any lane killing
"beams on :4000" kills every other lane's server instantly — "socket hang up" →
ECONNREFUSED at a random suite point, unreproducible in isolation. W299 run 2 (death
with no crash dump) fits this class; run 1 fits the io-device class. Both are
environmental process death, not request handling.

### 3. Reproduction of the death signature

Same committed BOOT chain (`mix run --no-halt`), fd 2 closed at boot:

- VM terminated during boot, wrote `erl_crash.dump` @ 15:27 (10.8 MB),
- slogan byte-identical to W299's: `Runtime terminating during boot
  ({badarg, io.put_chars(:standard_error ... the device does not exist ... io.erl:202})`.

A reader-loss-only test (stdout via fifo, reader killed mid-run, 6 requests after) did
NOT kill the server — so the death requires fd *closure*, not mere pipe-reader loss.
W299's server had its stderr *closed*; the exact agent-side event that closed it
(harness/TaskStop killing the launching session's pipe chain, or a concurrent lane
action) is not retroactively witnessable. Both witnessed interference channels (fd
closure, cross-lane kill-port) are lane-transport, not application behavior.

### 4. Request innocence: 30/30 hammer (falsifier passed)

Fresh server via the committed chain (leased port 4600 per the repo PW_PORT convention;
:4000 was held by a live concurrent lane — clearing it would have killed that lane's
suite), file-redirected log `/tmp/w299b-server.log`:

- 30 iterations × 4 requests: `POST /a2a/v1` valid `message/send` + invalid method,
  `POST /internal-api/execution/mcp` valid `tools/call` + raw garbage body,
  with token; `ps -p $SRV` checked every iteration.
- **30/30 survived; server alive at end; zero new erl_crash.dump attributable to it.**
- Typed responses observed: a2a `-32602 INVALID_PARAMS` (`{:unknown_kind, "part"}` on a
  bad part kind; note: my `kind: "part"` probe body was itself wrong — the a2a part kind
  contract is `kind: "text"`), `-32601` method-not-found; mcp typed `isError` JSON-RPC
  for unknown tool; garbage JSON body → **400 fail-closed** (dev renders the
  Plug.Parsers.ParseError debug page; status is still 400, contract intact).
- Server log `/tmp/w299b hammer window: zero `** (` exceptions, zero dispatch-path
  crashes.

## Root cause (typed)

`BLOCKED→CLASSIFIED: server death = environmental process death, not a dispatch crash.`

- Class A (witnessed, run 1): stderr device loss → ArgumentError on `io.put_chars` →
  init terminates the runtime (`erl_crash.dump`, byte-identical reproduction).
- Class B (witnessed live, explains run 2's dumpless death): cross-lane kill-port
  interference on :4000 — concurrent lanes each running "clear :4000 then boot" kill
  each other's servers mid-suite (demonstrated: two of my boots died `eaddrinuse` while
  foreign VMs held the port; a foreign server held :4000 through mid-diagnosis).

## Falsifier (this receipt's own)

The 30/30 hammer is the falsifier for "request handling kills the server": passed
(no death). The fd-closed boot is the falsifier for the io-device death class:
passed (byte-identical dump). Run 2's dumpless death is classified, not proven —
marking it as such.

## Remediation direction (not applied — out of lane scope)

1. **Boot chain hardening (operational, root-cause-level for Class A):** launch the
   e2e server with output redirected to a real file (never a session/harness pipe),
   e.g. add `> /tmp/xaas-e2e-server.log 2>&1` inside `playwright.config.cjs`'s BOOT
   command, so fd loss in the launching session can never kill the server.
2. **Class B:** stop the "kill all beams on :4000" convention across concurrent lanes —
   use the existing PW_PORT lease (as this lane did on 4600) or a coordinator-owned
   port allocation. Every concurrent "clear :4000" is a cross-lane SIGKILL.

## W310f remediation landed

Subject: `playwright.config.cjs` BOOT command (branch `feat/playwright-surface`, working
tree, 2026-10-06). Remediates "Remediation direction" items 1 and 2 above.

1. **Class A fix applied**: the BOOT's `mix run --no-halt` line now redirects server
   stdout+stderr to a real file before backgrounding:

   ```
   ... mix run -e '...' --no-halt > /tmp/xaas-e2e-server.log 2>&1 & SRV=$!
   ```

   Readiness gate (W279) and `wait $SRV` unchanged. Witnessed post-fix: the beam VM's
   fd 1 AND fd 2 are `REG` entries on `/private/tmp/xaas-e2e-server.log` (`lsof -p
   <beam>` — regular file, not a session/harness pipe), so fd-2 closure in the launching
   session can no longer reach the VM. Header comment added documenting the mechanism
   (closed `:standard_error` → ArgumentError → init terminates → erl_crash.dump).
2. **Class B convention retired in header**: the "kill all beams on :4000" cleanup is
   documented as RETIRED in favor of the W310 PW_PORT lane lease; concurrent lanes MUST
   use distinct PW_PORT values instead of killing. (The one kill in this lane's
   verification was the last authorized :4000 clear, per lane contract.)

### Verification (real output)

- :4000 cleared (last authorized kill), then fresh boot + full trio:
  `npx playwright test e2e/a2a-v1.spec.cjs e2e/witness.spec.cjs e2e/ggen-workbench.spec.cjs`
  → **16 passed (35.1s)**.
- Mid-run reader-loss probe: suite relaunched with stdout piped to `head -1`, which
  exits on its first line (playwright pipe reader destroyed mid-run). Runner kept
  executing; the freshly booted beam (pid 39852):
  - `lsof -p 39852`: fd 1 `1w REG ... /private/tmp/xaas-e2e-server.log`, fd 2
    `2w REG ... /private/tmp/xaas-e2e-server.log` — no pipe, no tty, no session fd;
  - `GET /internal-api/health` (token) → **200** after reader loss;
  - `/tmp/xaas-e2e-server.log` byte growth witnessed across checks while the reader
    was gone (13,618 → 16,368 → 40,924 → 41,976 bytes, final boot-compile output);
  - server survived the entire window; runner completed; playwright tree-killed its
    own server on exit (designed behavior, distinct from the fd-closure death class);
    `:4000` clear after.
- No new `erl_crash.dump` (the on-disk dump is W299b's 15:27 repro artifact, untouched
  this lane).

### Standing

- fd-2-closure VM-terminate class: CLOSED for the e2e boot path (witnessed: VM fds are
  regular files; reader-loss probe survived).
- kill-:4000 convention: RETIRED (PW_PORT lease is the only sanctioned concurrency
  mechanism); header comment is the fixed form.
- Trio suite on remediated BOOT: ALIVE (16/16).

- Server-death root cause: CLASSIFIED (two witnessed mechanisms, run-1 mechanism
  byte-identical reproduced; run-2 attribution probable, not witnessed).
- `/a2a/v1` + `/internal-api/execution/mcp` dispatch paths: ALIVE (30/30 hammer, typed
  errors only, no death).
- Lib fix: none required — no dispatch-path crash exists to fix.
