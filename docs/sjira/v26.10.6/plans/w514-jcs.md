# W514 — RFC 8785 JCS Canonicalization (substrate lane)

Lane: W514 · Branch: feat/playwright-surface · Date: 2026-10-06

## Verdict

**Full RFC 8785** (not a documented-subset verdict): the repo already pins the
`jcs` hex package (`{:jcs, "~> 0.2"}`, mix.exs:178), a complete pure-Elixir
RFC 8785 implementation (deps/jcs/lib/jcs.ex: UTF-16 code-unit key sorting,
§3.2.2.2 string escaping, §3.2.2.3 ECMA-262 NumberToString via
`:erlang.float_to_binary([:short])`, OTP 25+ guard).

## What landed

- `lib/xaas/semantics/jcs.ex` — `Xaas.Semantics.Jcs.encode/1`, a thin facade
  delegating 1:1 to `Jcs.encode/1` (zero duplicated logic). Moduledoc documents
  the supported input subset, string/number canonicalization rules, and the
  digest pattern shared with `Xaas.Deployment.ReleaseSnapshot.portable_digest/1`
  and `Xaas.Witness.AuditChain`.
- `test/xaas/semantics/jcs_test.exs` — 16 tests: RFC §3.2.3 literal key-sorting
  example (UTF-16 order incl. control chars before digits, astral names after
  BMP), string-escape vectors, atom-key handling, number vectors (1.0→1,
  -0.0→0, 1e30→1e+30, 1e-6→0.000001, 2^53, 5e-324, DBL_MAX), determinism
  (25 runs → 1 distinct output), Jason round-trip, digest-form determinism,
  documented-subset boundary (ArgumentError on tuples/atom values).
- No changes to `Xaas.Deployment.ReleaseSnapshot` or `Xaas.Witness.AuditChain` —
  both already call `Jcs.encode/1`; pure addition, no conflicts with W503.

## Verification (real output)

- `MIX_BUILD_ROOT=_build-laneW514 MIX_ENV=test mix compile --warnings-as-errors`
  → exit 0 (strict compile green; one pre-existing warning from another lane's
  `dataset_admission.ex`, not session-introduced).
- `MIX_BUILD_ROOT=_build-laneW514 MIX_ENV=test mix test test/xaas/semantics/jcs_test.exs`
  → **16 passed, 0 failed, 0 skipped**.

## Documented limitations

- Lone UTF-16 surrogates (WTF-16 corner of §3.2.2.2) cannot exist in Elixir
  UTF-8 binaries — outside the input subset; encode raises rather than
  emitting wrong output.
- Big integers (>2^53) encode exactly but `Jason.decode` cannot round-trip them
  as integers; the round-trip property test compares big-int output textually
  only.
- Input keys must be binaries/atoms; non-JSON terms raise `ArgumentError`.

## Residuals

- Stray `_buildW514/` directory at repo root from a session MIX_BUILD_ROOT
  typo (rm denied in this session) — coordinator cleanup.
- Concurrent lane briefly left `semantics/counterfactual.ex` unparseable
  (fixed by that lane during this session; not W514-introduced).

## Falsifier status

`Xaas.Semantics.Jcs.encode(1.0) == "1"`, `encode(-0.0) == "0"`,
`encode(1.0e30) == "1e+30"`, UTF-16 key ordering, byte-level determinism — all
witnessed by the 16-test suite above.
