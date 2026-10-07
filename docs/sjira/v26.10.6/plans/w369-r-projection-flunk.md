# W369 — r_projection silent skip → presence flunk (closure row 27, P1-5)

Subject: /Users/sac/xaas @ feat/playwright-surface (no commit made, per contract)

## Diff summary

File: `test/xaas/receipt/r_projection_test.exs`

- Removed the `@needs_validator` compile-time conditional (former :21-25) and its
  comment; replaced with a comment stating presence is asserted, never skipped.
- Deleted all 6 `@tag skip: @needs_validator` lines (former :65, :115, :128,
  :146, :167, :206).
- Added one unconditional presence test: "the fleet R-schema validator is
  present, non-empty, and readable" — asserts `File.regular?/1` with a flunk
  message naming the path and the one-command fix, plus non-empty
  (`File.stat!.size > 0`) and readable (`File.read/1`).

No w155 typed-skip convention used: the validator exists here and presence is
the default per the plan text.

## Verification (real output)

Command:
`PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW369 mix test test/xaas/receipt/r_projection_test.exs`

Tail (verbatim):

```
Finished in 9.0 seconds (0.00s async, 9.0s sync)

Result: 10 passed
[os_mon] memory supervisor port (memsup): Erlang has closed
[os_mon] cpu supervisor port (cpu_sup): Erlang has closed

[exited with code 0]
```

10 tests total in the file (9 pre-existing + 1 new presence test), 0 failures,
0 skipped. All 6 previously-skipped tests now execute and pass — no
newly-exposed failure. Note: the "27/27" figure in the task brief does not
match this file (it has 10 tests); 27 may have been a directory-level count
from the w329 lane. This file's pre-conversion state was 3 pass / 6 skip.

Validator confirmed on disk: `/Users/sac/.claude/dfcm/validate_receipt.py`
(5376 bytes).

## Cleanup

`rm -rf /Users/sac/xaas/_build-laneW369` was DENIED by the permission system
(twice). The lane build root remains on disk and must be deleted by the
coordinator at integration.

## Row-27 verdict

ALIVE — silent skip converted to presence flunk; all tests run and pass on the
real validator.
