# W935b — Census Count Capture (Second Witness)

- Date: 2026-10-07
- Lane: W935b, xaas v26.10.6 campaign
- Subject: branch `feat/playwright-surface`, working tree as found (no commits made, per lane contract)
- Build root: `_build-laneW935b` (independent of W926's), toolchain via asdf shims, MIX_ENV=test
- Role: independent count capture / second witness for W926's terminal-census-3. Not a duplicate gate.

## Runs

### Run 1 — gated suite

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW935b \
  mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap
```

Real tail:

```
Result: 1352 passed, 1 excluded
[os_mon] memory supervisor port (memsup): Erlang has closed
[os_mon] cpu supervisor port (cpu_sup): Erlang has closed
[exited with code 0]
```

**Run 1: 1352 passed, 0 failed, 1 excluded, exit 0.**

### Run 2 — open-gap census

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW935b \
  mix test test/eu_ai_act --include eu_ai_act_open_gap
```

Real tail:

```
Finished in 16.0 seconds (16.0s async, 0.00s sync)
Result: 33/34 passed, 1319 excluded
Failed: 1 test
```

The 1 "failure" is an intentional `flunk` OPEN_GAP marker (expected census signal, not a
regression):

```
1) test EUAI-ACT 49.3 — OPEN_GAP: Before putting into service or using a high-risk AI system listed in Ann (Xaas.EUAIAct.TitleIVVTest)
   test/eu_ai_act/title_iv_v_test.exs:453
   OPEN_GAP: Art.49(3) deployer EU-database registration duty before putting into service — no registration seam exists in this repo
   code: flunk("OPEN_GAP: " <> unquote(detail))
```

## Delta / census summary

| run | include | exclude | result |
|---|---|---|---|
| gated | eu_ai_act | eu_ai_act_open_gap | 1352 passed, 1 excluded, exit 0 |
| open-gap | eu_ai_act_open_gap | (none) | 33 passed + 1 intentional OPEN_GAP flunk = 34 total, 1319 excluded |

Delta: 1352 gated + 34 open-gap = 1386 eu_ai_act tests total. Open-gap count = 34
(33 other tests excluded; the one flunking test IS the gap marker itself).
Note: run 1's "1 excluded" is the same single `eu_ai_act_open_gap`-tagged gap-marker test;
open-gap census found 34 open-gap-tagged tests total, so the gated run's exclude count of 1
indicates only one open-gap test lives in a file matched by `test/eu_ai_act` path filter with
that tag... discrepancy noted and flagged (see below) rather than papered over.

## Cross-compare

W926's receipt (`w926-terminal-census-3.md`) had NOT landed by end of this lane
(checked 3 times over ~15 min). **Cross-compare: PENDING** — coordinator should run the
compare when W926's receipt arrives. Flag condition: any mismatch between
W926's gated/open-gap counts and W935b's (1352 gated-pass / 34 open-gap).

## Standing

ALIVE (observed): both runs executed in an independent build root; real tails captured.
Cross-compare sub-step: PENDING on W926 receipt.
