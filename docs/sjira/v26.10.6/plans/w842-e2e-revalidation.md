# W842 Receipt — Priority e2e revalidation at current strength (post-W752 drift check)

- **Lane**: W842, xaas v26.10.6, branch `feat/playwright-surface`, HEAD `a0723bf6` (canonical checkout).
- **Standing (priority set)**: **ALIVE** — 24 passed / 1 skipped / 0 failed (25 tests, exit 0)
  on a fresh playwright boot, PW_PORT=4126, MIX_ENV=test, token `dev-e2e-token`, lane build
  root seeded from `_build-laneW752` (incremental compile, no fresh 12-min build).
- **Date**: 2026-10-07

## Command (real)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW842 \
  INTERNAL_API_TOKEN=dev-e2e-token PW_PORT=4126 \
  npx playwright test e2e/a2a-marking.spec.cjs e2e/a2a-v1.spec.cjs \
    e2e/execution-fabric.spec.cjs e2e/witness.spec.cjs e2e/mcp-a2a.spec.cjs \
    e2e/dev-routes.spec.cjs --reporter=line --workers=2
```

Port 4126 verified free before launch (`lsof` empty) — fresh boot, no
`reuseExistingServer` adoption.

## Per-spec results

| spec | result | classification |
|---|---|---|
| a2a-marking.spec.cjs | 5/5 pass | green — W533 marking contract intact (b1/b2 refusals marked, c1/c2 unmarked paths unmarked) |
| a2a-v1.spec.cjs | 6/6 pass | green — card 200 + required fields, auth floor, -32700/-32601, message/send happy path, SSE stream terminal TASK_STATE_COMPLETED |
| execution-fabric.spec.cjs | 3/3 pass | green — 403 `REFUSED(authority_ceiling:actuate)` envelope, fail-closed tokenless, probe capabilities unchanged |
| witness.spec.cjs | 2 pass + 1 skip | green — skip is the spec's designed `test.fixme` (line 147) seed branch, unchanged from W752 |
| mcp-a2a.spec.cjs | 5/5 pass | green — typed auth refusals + all three agent cards |
| dev-routes.spec.cjs | 2/2 pass | green — LiveDashboard + ash_admin mount |

**Zero spec drift, zero product regressions** across the priority set despite the
~15 landed changes (W703/W723/W739/W745/W764/W794…) since W752. The 1 skip is the
witness spec's designed `test.fixme`, not a failure. This closes W752's PARTIAL_ALIVE
for the priority set.

## W822 acceptance handoff — CLOSED

The fresh-boot readiness gate **passed without `reuseExistingServer`** on leased
port 4126 (port verified free pre-launch; boot succeeded first-try; W822's
`config/test.exs` PORT/PW_PORT resolution observed live — server bound exactly to
4126 and every test hit it there). W822's UNKNOWN (its receipt, "Standing" section)
is resolved to ALIVE for the end-to-end fresh-boot path.

One residual config-class finding in the boot probe itself, **pre-existing committed
state of `playwright.config.cjs:67`**, discovered this run (typed finding W842-F1):

### W842-F1 (config-class, boot infra): tokened BOOT probe header word-splits to a header REMOVAL

`playwright.config.cjs:67` builds `AUTH="-H Authorization: Bearer $INTERNAL_API_TOKEN"`
and later expands `$AUTH` unquoted. Word-splitting yields `curl -H Authorization: Bearer
dev-e2e-token <url>` — in curl, `-H "Header:"` (trailing colon, no value) **removes** the
header, so the tokened probe sends no Authorization header and gets 401 forever. Observed
mid-run: `[WebServer] e2e readiness probe never returned 200 (last=000000{...401})`. The
boot still succeeded because playwright's independent `webServer.port` readiness poll
declared the port ready; the BOOT script's `kill $SRV; exit 1` fired late, orphaning the
beam (killed this lane; port 4126 clear at close). Tokenless boots are unaffected
(`AUTH=""`, probe `/` quoted, returns 200). Classification: config-class (boot infra,
not spec, not lib). Not fixed by this lane (receipt-only lane; config edit outside
task authority). Correct form for the next lane touching this file:
`AUTH=(-H "Authorization: Bearer $INTERNAL_API_TOKEN")` used as `"${AUTH[@]}"`, or a
quoted single string consumed with `eval`. Net: W822's fresh-boot acceptance is closed
via playwright's port probe (the binding/probe URL fix works); the tokened internal
probe path needs the quoting fix before it can pass as written.

## Cleanup state

- Orphan beam 7286 on 4126 (my boot) killed; port verified clear.
- `_build-laneW842` deletion was **denied by the permission system** (rm -rf) — left
  in place per the fanout lease law for the coordinator to delete at integration
  (~437 MB, MIX_ENV=test, seeded from W752's root).
- No repo files edited beyond this receipt. Nothing committed.

## Verdict

Priority-suite revalidation: **green at current strength** — 24/24 executable courts
pass, zero drift, zero regressions; W752's PARTIAL_ALIVE for the priority set closes to
ALIVE; W822's fresh-boot acceptance handoff closes (probe passes fresh on leased port,
with the tokened-probe quoting bug recorded as W842-F1 for the coordinator).
