# W894 — Vendor Pin Coverage Receipt

Standing: **ALIVE** (court executed, 3/3 passed on the real vendored bytes).

## Coverage grep (the finding)

```
$ grep -rln "priv/vendor" /Users/sac/xaas/test
test/xaas/ontology/ex4pm_staleness_test.exs
test/xaas/ontology/staleness_task_court_test.exs
```

Both are mechanism-level and `:external`-tagged (excluded from default
`mix test`); neither pins the real `priv/vendor/ex4pm/ocel.ex` bytes.
`test/xaas/semantics/airo_vendored_pin_test.exs` covers airo.ttl only.
**Gap proven → court added.**

## New court

`/Users/sac/xaas/test/xaas/vendor_pin_court_test.exs` (default-included,
Chicago-style: real file, real `:crypto.hash(:sha256, ...)`, no mocks;
typed `VENDOR_PIN_DRIFT` failure naming the re-vendor command).

Pins recorded (W702 `docs/sjira/v26.10.6/plans/w702-telemetry-docs-verify.md`
row 19, freshly re-derived this wave):

```
$ git -C ~/ex4pm show ade25ed12e93f89e7a2e1490698f99ae4947d702:lib/ex4pm/ocel.ex | shasum -a 256
ec075eb1c75d5235647498fd880eb23322721618c1328624689a86ddee0a9287  -
$ shasum -a 256 /Users/sac/xaas/priv/vendor/ex4pm/ocel.ex
ec075eb1c75d5235647498fd880eb23322721618c1328624689a86ddee0a9287  /Users/sac/xaas/priv/vendor/ex4pm/ocel.ex
```

Byte-identical: pin intact. (`config/config.exs:79` `pinned_sha ade25ed1...`;
note ex4pm working-tree HEAD is `46bfcc8f...`, newer than the pin — pin
semantics unaffected.)

## Run

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/vendor_pin_court_test.exs --include external
...
Finished in 0.04 seconds (0.00s async, 0.04s sync)
Result: 3 passed
```

(2 default + 1 `:external` upstream-re-derivation against the real `~/ex4pm`.)

## Transport failure disclosed (pre-existing, not session-introduced)

The mandated lane build root `_build-laneW894` (400 MB, deleted post-run)
failed to cold-compile `lib/xaas/library/checkout.ex:91` —
`misplaced operator ^user_id` in a generated Ash change — while the shared
`_build/test` compiles the same tree clean (`mix compile` exit 0). Same
source, same pinned toolchain (asdf shims); the failure appears only under a
fresh build root, so it is an environment/dep-resolution divergence, not a
regression from this lane. The court was gated against the shared test build.

## Files (uncommitted, per lane law)

- `test/xaas/vendor_pin_court_test.exs` (new)
- `docs/sjira/v26.10.6/plans/w894-vendor-pin-coverage.md` (this receipt)
