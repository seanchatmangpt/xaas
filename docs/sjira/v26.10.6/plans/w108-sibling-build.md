# W108 — sibling build + gated-suite rerun receipt

Date: 2026-10-06. Lane: W108, v26.10.6 convergence.
Subject: /Users/sac/ggen_igniter on the W6/W38-modified tree (pack promoted, credo clean, 1555 green). No git mutations in either repo.

## W82 gate cause and fix

`origin_authority_test` (5 skips) and `semantic_drive_anchor_test` (setup crash) gated on
`/Users/sac/ggen_igniter/_build/test` existing; that dir had been removed. Fix applied:
one real rebuild of the sibling checkout.

## Build (real output)

```
cd /Users/sac/ggen_igniter
PATH=$HOME/.asdf/shims:$PATH mix deps.get   # asdf pinned 1.19.5-otp-27
  -> "All dependencies have been fetched" (zoi 0.18.11; security-advisory notice only)
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix compile
  -> Compiling 178 files (.ex)
  -> Compiling crate ggen_graph_nif in release mode (native/ggen_graph_nif)
  -> Copying .../libggen_graph_nif.dylib -> priv/native/ggen_graph_nif.so
  -> Generated ggen_igniter app
```

Exit 0. `/Users/sac/ggen_igniter/_build/test` exists again.

## Suite reruns (GGEN_IGNITER_DIR=/Users/sac/ggen_igniter, MIX_ENV=test)

- `test/xaas/ultracode/origin_authority_test.exs`: **10 passed, 0 failures, 0 skips**
  (the 5 skips from W82 are gone).
- `test/xaas/ultracode/semantic_drive_anchor_test.exs`: 8 passed / 2 failed (was setup-crash
  in W82 — setup now runs, so the gate is cleared).
- Combined run: 16/18 passed, 2 failed, Finished in 31.3s.

## mu_on_O failures — classified verbatim, NOT fixed (W107 scope)

Both anchor failures are the same `mu_on_O` refusal, at lines 199 and 176 of
`test/xaas/ultracode/semantic_drive_anchor_test.exs`:

```
match (=) failed
code:  assert {:ok, anchor} =
         SemanticDrive.anchor(
           ggen_igniter_dir: @ggen_dir,
           work_graph: work,
           order: "EP-A",
           ggen_build_path: build
         )
left:  {:ok, anchor}
right: {:refused,
         %{
           "broken_term" => "mu_on_O",
           "detail" => %{
             "exit" => 1,
             "reason" => ["descriptor_refused", ["not_eligible", "EP-A", "unknown_identity"]]
           },
           "hop" => "sjira",
           "reason" => "descriptor_refused",
           "standing" => "REFUSED(descriptor_refused)"
         }}
```

Classification: `mu_on_O` — the descriptor hop refuses order `EP-A` with
`not_eligible / unknown_identity`; the court returns REFUSED instead of the expected
`{:ok, anchor}`. Adjacent-court work, W107's lane; untouched here.
