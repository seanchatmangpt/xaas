# W984df — Jcs direct-court coverage probe

Lane: W984df, xaas v26.10.6 campaign. Subject: `lib/xaas/semantics/jcs.ex`
(`Xaas.Semantics.Jcs`, RFC 8785 facade relied on by W603/W616 export courts).

## Probe result: direct coverage PRESENT

`grep -rn "Jcs" test/` shows three dedicated direct-court files (not just
indirect exercise through export courts):

- `test/xaas/semantics/jcs_test.exs` — 16 tests
- `test/xaas/semantics/jcs_property_test.exs` — 4 property tests (J1–J4)
- `test/xaas/semantics/jcs_doctest_test.exs` — 4 doctests

### Mapping of required properties to existing direct tests

| Required probe | Existing direct coverage |
|---|---|
| Key sorting / lexicographic (UTF-16 code-unit) ordering | `jcs_test.exs:7` "literal RFC example: UTF-16 code-unit key order, no whitespace"; `:47` atom keys sorted; property J1–J3 sorted-key assertion |
| Number formatting per JCS ES6 number-to-string | `jcs_test.exs:62–108`: integer form, `1.0 → 1`, negative zero → `0`, `1E30`, small float plain decimal, RFC 8785 Appendix B number vectors, big integers; property J4 (integer + float/exponent corpora, RFC 8785 minimality) |
| String escaping incl. control chars / unicode | `jcs_test.exs:39` control chars/quote/backslash lowercase-hex escapes; `:43` non-ASCII passthrough above U+001F |
| Input determinism ×2 | `jcs_test.exs:111` 25-run determinism; `:149` byte-level digest determinism; property J1/J2/J3 (1000 seeded random nested structures) and J4 byte-identical rebuilds |
| Round-trip stability | `jcs_test.exs:127` `parse(encode(x)) == x`; property J1–J3 round-trip assertions |

RFC 8785 Appendix B official number vectors are already embedded
(`jcs_test.exs:85`) and the literal RFC example appears at `jcs_test.exs:7` —
the "embed official vectors" branch of the task is already satisfied by the
existing court.

## Typed disposition

**COVERAGE_PRESENT — no new court written.** Writing a second depth court over
properties already directly asserted would be duplicate capital, not depth.

## Verification (executed, not inspected)

- Lane build: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984df mix compile` → "Generated xaas app" (warnings only).
- Gate: `mix test test/xaas/semantics/jcs_test.exs test/xaas/semantics/jcs_property_test.exs test/xaas/semantics/jcs_doctest_test.exs`
  → **20 passed (4 doctests, 16 tests), 5 excluded**, 0 failures.

## Transport failure (disclosed, resolved)

First cold compile under the fresh lane build root aborted at
`lib/xaas/semantics/graphlaw_wasm.ex:490` ("cannot invoke defp/2 outside
module") — an untracked in-flight file owned by another lane (compile-freeze
violation by that lane, not this one). Per the 10-minute SLA this lane waited
and retried without touching the foreign file; a subsequent compile succeeded,
so no minimal unblock fix was needed and no cross-lane edit was made.

## Standing

- `Xaas.Semantics.Jcs` direct-court coverage: **ALIVE** — 3 direct test files,
  20 passing checks, all 5 RFC 8787/8785 probe properties directly asserted
  with official vectors embedded.
- This lane's diff: **zero test/lib changes** (disposition lane); receipt only.
- Lane build root `_build-laneW984df`: deletion was permission-denied in this
  session; **left for coordinator** (per lane contract fallback).

## Files touched

- `docs/sjira/v26.10.6/plans/w984df-jcs.md` (this receipt) — only file written.
