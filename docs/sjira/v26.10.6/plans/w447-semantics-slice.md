# W447 — final-tree semantics slice receipt

Lane: W447, repo /Users/sac/xaas @ feat/playwright-surface (canonical checkout, no commit).

## Command

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW447 mix test test/xaas/semantics/
```

## Real tail

```
Result: 29 passed
[os_mon] cpu supervisor port (cpu_sup): Erlang has closed
[os_mon] memory supervisor port (memsup): Erlang has closed

[exited with code 0]
```

## Verdict

**GREEN at final tree.** 29 passed / 0 failures / 0 errors, exit 0, over
`test/xaas/semantics/` (files: ash_r2rml_test.exs, r2rml_refusal_test.exs,
registry_test.exs, vkg/, vkg_refusal_negative_test.exs — W378's 3 refusal-negative
tests included in the 29). No failures to isolate.

## Cleanup

`rm -rf /Users/sac/xaas/_build-laneW447` — **DENIED** by permission system.
Build root `_build-laneW447` REMAINS ON DISK; coordinator must delete at integration
(per same-checkout-fanout cleanup law).
