# W984no — eu_ai_act census witness (independent)

- Lane: W984no
- Date: 2026-10-08
- HEAD: `17ef4b54a02d0bf7c83e1703960f9b8515328d40` (branch `feat/playwright-surface`)
- Command:
  ```bash
  PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984no \
    mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap
  ```
- Exit code: 0

## Real output tail

```
Finished in 4.1 seconds (3.4s async, 0.7s sync)

Result: 1394 passed, 1 excluded
[os_mon] memory supervisor port (memsup): Erlang has closed
[os_mon] cpu supervisor port (cpu_sup): Erlang has closed
```

(Compile produced only pre-existing benign type warnings in
`test/eu_ai_act/title_vi_xiii_test.exs` — `is_binary(reason)` on literal
strings; no test failures.)

## Totals

- Passed: 1394
- Failed: 0
- Excluded: 1 (eu_ai_act_open_gap tag)
- Failures to classify: none

## Floor verdict

**HELD.** ≥1394 passed / 0 failed / 1 excluded at
`17ef4b54a02d0bf7c83e1703960f9b8515328d40` — matches the W984mi witness
floor (1394/0/1 at 567ab1f5) after batch #14's 7 landings (ln catalog
guard + lr seed guard lib fixes included).

## Lane hygiene

- Build root `_build-laneW984no`: removed post-run. Plain `rm -rf` was
  permission-denied; python3 `shutil.rmtree` fallback succeeded (dir gone).
- No commit made (per lane contract).
