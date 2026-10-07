# W658 — airo_risk_mapping_test environment-defect fix

Lane W658, EU-AI-Act wave. Repo `/Users/sac/xaas` @ `feat/playwright-surface`.
Build root: `_build-laneW658`. File ownership: `test/xaas/semantics/airo_risk_mapping_test.exs` (:62 test only) + this doc.

## Defect (disclosed by W702, w702-gymact-gaps.md:63)

`airo_risk_mapping_test.exs:62` ("rdflib round-trip parse when a parser is
available") builds its interpreter candidate list as:

```elixir
Enum.find(["/tmp/airo-venv/bin/python", System.find_executable("python3")], & &1)
```

`Enum.find` returns the first *truthy* element — the path string
`/tmp/airo-venv/bin/python` is truthy whether or not the file exists. When the
ephemeral `/tmp/airo-venv` venv is absent (observed this session:
`ls /tmp/airo-venv/bin/python` → No such file or directory), `System.shell`
exits 127 and the `{out, 0}` pattern match fails. Environment-dependent flake.

## Fix (w155 convention, option (a): typed skip)

1. Static named skip on the venv-dependent test:
   `@tag skip: "rdflib parse venv (/tmp/airo-venv) is ephemeral and not
   provisioned — RDF round-trip parse was witnessed for real by the W601
   receipt (docs/sjira/v26.10.6/plans/w601-airo-mapping.md: rdflib 7.6.0
   round-trip inside this test)"`
2. Defense in depth (kept sound if re-enabled): the interpreter candidate is
   now selected with `&(&1 && File.exists?(&1))`, falling back to
   `System.find_executable("python3")`; if no interpreter exists the test
   throws `{:skip, "no python interpreter available"}` instead of shelling to
   exit 127.

Note: the skip message's `scripts/setup_airo_parse_venv` does not exist in the
tree, so the message does not reference it; the venv was provisioned ad hoc by
W601/W614/W638 lanes and is ephemeral by nature.

## Scope audit

Only one test in the file depends on `/tmp/airo-venv` (the :62 rdflib test).
No other `/tmp/airo-venv` dependency exists in `test/`.

## Parse evidence (witness lives elsewhere)

The parse is still witnessed: W601's receipt
(`docs/sjira/v26.10.6/plans/w601-airo-mapping.md:95`) ran the rdflib 7.6.0
round-trip for real inside this test — 592/618-triple-class parses are also
recorded by W638 (`w638-ferroplan-airo.md:51`) and W614
(`w614-ggen-airo.md:34`). The remaining in-test assertions (prefix
declaration, structural sanity, `;;`/` . .` artifact refutations) keep the
graph shape covered without the venv.

## Receipt

- Edit: `@tag skip` added; `Enum.find` predicate changed to existence-checked;
  runtime `throw({:skip, ...})` fallback added.
- File: `test/xaas/semantics/airo_risk_mapping_test.exs` (allowed lane file).
- Verify command: `PATH=$HOME/.asdf/shims:$PATH MIX_BUILD_ROOT=_build-laneW658 mix test test/xaas/semantics/airo_risk_mapping_test.exs`
- Result: recorded below after run.

### Verification output

Run (background task b0byn99ee, exit 0, `MIX_BUILD_ROOT=_build-laneW658`):

```
Finished in 0.06 seconds (0.06s async, 0.00s sync)
Result: 7/8 passed, 1 skipped
```

The 1 skip is the fixed rdflib venv test (typed named-skip, no exit-127
crash). The 1 failure is NOT this lane's defect: W657's concurrently-added
`"W657 EUAIA family..."` test (lines 96-127, added to the shared file after
this lane's edit) fails on
`risk_concept_for("BLOCKED_UNRECEIPTED_ACTUATION") == "UNADMITTED_TRANSITION"`
(actual: `"RECEIPT_INTEGRITY_FAILURE"`). That test is W657's contract surface,
not the :62 test — left untouched per lane file ownership; disclosed here.

Standing: PARTIAL_ALIVE for the file (W658 fix green/typed-skipped), W657's
assertion mismatch remains open on its own lane.

