# W382 — Anti-Vacuity Mutation Audit, Round 2 (3 mutants)

Lane W382, v26.10.6 convergence campaign. Repo `/Users/sac/xaas` @ `feat/playwright-surface`,
ONE canonical checkout, no worktrees, no commit. Continues W320's protocol on 3 more sites.
Private build root `_build-laneW382` DELETED at close (2026-10-06 17:33 PDT) per the
2026-10-01 cleanup law — no orphaned lease left.

## Method

Per mutant: one-line minimal Edit → `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test
MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW382 mix test <single file>` → record → revert by
inverse Edit (git checkout FORBIDDEN) → `git diff --stat` back to baseline. Reverts verified:
castle.ex 16+1− and endpoint.ex 8+1− (both pre-existing, NOT mine); plug file zero-diff at
close. Post-revert rerun: 28/28 green across all three suites.

Green baseline (cold compile, private root): 28 passed (18 batch6 + 7 plug + 3 endpoint).

## Per-mutant receipt

| # | family | site mutated (original → mutant) | test file | result | revert-verified |
|---|---|---|---|---|---|
| 1 | castle `verify_outer_intent/3` idempotency gate | `lib/xaas/castle.ex:382` `outer.idempotency_key != context.idempotency_key ->` → `false ->` | `test/xaas/castle_refusal_negative_batch6_test.exs` | **KILLED** — 17/18, failed: `REFUSED_XAAS_IDEMPOTENCY_MISMATCH — outer intent idempotency key drifted` (test line 212): assert expected `{:error, :REFUSED_XAAS_IDEMPOTENCY_MISMATCH}` but got `{:ok, %{"admitted" => true, ...}}` | yes (16+1− restored) |
| 2 | plug empty-bearer branch | `lib/xaas_web/plugs/require_internal_api_token.ex:130` `when byte_size(token) > 0` → `when byte_size(token) >= 0` | `test/xaas_web/plugs/require_internal_api_token_test.exs` | **SURVIVED — anti-vacuity gap** — 7/7 green with the guard disabled | yes (zero diff) |
| 3 | endpoint body-limit literal | `lib/xaas_web/endpoint.ex:81` `length: 8_000_000` → `length: 800_000_000` (100x) | `test/xaas_web/endpoint_body_limit_test.exs` | **KILLED** — 1/3, both over-limit tests failed (test lines 30 and 45): expected `Plug.Parsers.RequestTooLargeError`, got `Plug.Parsers.ParseError` (Jason `unexpected byte at position 0: 0x78`) — oversized body parsed through instead of 413ing | yes (8+1− restored) |

## Gap finding (mutant 2) — empty-bearer guard is vacuous as tested

`lib/xaas_web/plugs/require_internal_api_token.ex:130` (`bearer_token/1`, guard
`byte_size(token) > 0`). Mutant (empty bearer accepted as present) leaves
`require_internal_api_token_test.exs` fully green (7/7). The named empty-bearer test
("empty bearer token (\"Bearer \") is refused 401, never treated as present", line 111) still
passes because with the guard dropped, `""` falls through to `authenticate_via_env("")`, and
`secure_compare("", "test-only-internal-api-token")` fails → 401 anyway — same observable
status. Static cross-check: the only test that could kill it is the fail-closed test
(line 75, unset env + no header → 503), but that test sends NO Authorization header at all,
not an empty `Bearer ` header; no test pairs an empty bearer with an unset
INTERNAL_API_TOKEN, so no test asserts the mutant-specific observable. W378/W379 own this
file's tests — reporting verbatim, no fix written.

## Real command tails

- Green baseline: `mix test batch6 + plug + endpoint_body_limit` → `Result: 28 passed`
  (cold compile, private root).
- M1 (castle mutant): `Result: 17/18 passed / Failed: 1 test` — failure excerpt:
  `code: assert {:error, :REFUSED_XAAS_IDEMPOTENCY_MISMATCH} = witness_call(...)` /
  `left: {:error, :REFUSED_XAAS_IDEMPOTENCY_MISMATCH}` / `right: {:ok, %{"admitted" => true, ...}}`.
  (Compiler also flagged the mutant: type warning "this clause in cond will never match" at
  `lib/xaas/castle.ex:382:13 Xaas.Castle.Admission.verify_outer_intent/3` — independent
  confirmation the mutant was live.)
- M2 (plug mutant): `Result: 7 passed` — mutant confirmed compiled and live (beam mtime
  17:29 under `_build-laneW382/test/lib/xaas/ebin/`; working-tree diff confirmed the `>= 0`
  guard in place at run time).
- M3 (endpoint mutant): `Result: 1/3 passed / Failed: 2 tests` — failure excerpt:
  `Expected exception Plug.Parsers.RequestTooLargeError but got Plug.Parsers.ParseError
  (malformed request, a Jason.DecodeError ... "unexpected byte at position 0: 0x78 ("x")")`.
- Post-revert rerun (all three files): `Result: 28 passed`.