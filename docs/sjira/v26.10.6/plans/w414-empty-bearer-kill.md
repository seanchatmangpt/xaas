# W414 — Empty-bearer guard mutation kill

Campaign: v26.10.6 convergence, lane W414 @ /Users/sac/xaas feat/playwright-surface.
Closes w382 gap: the `byte_size(token) > 0` guard at
`lib/xaas_web/plugs/require_internal_api_token.ex:131` was vacuous as tested.

## Gap analysis

Pre-existing coverage: empty `"Bearer "` + INTERNAL_API_TOKEN set → 401
(test line ~111). But under the mutant `>= 0`, that cell still 401s (empty
token fails `InternalApiTokenAuth.verify/1`, then `secure_compare("", set)`
fails → 401). Observable-identical. No test paired empty bearer with an
UNSET env var, where the guard's weakening redirects empty-token into the
`authenticate_via_env/1` path that must 503 (misconfigured), not 401.

## Killing test added

`test/xaas_web/plugs/require_internal_api_token_test.exs`:
"empty bearer token with INTERNAL_API_TOKEN unset fails closed with 503, not 401"
— mirrors the existing unset-env 503 test's `without_env_token/1` conn
construction, plus the `"Bearer "` header. Asserts 503 + halted + exact
fail-closed body + nil current_org.

## Verification plan

1. Original plug: full file green.
2. Mutant `> 0` → `>= 0` at line 131: new test must FAIL.
3. Inverse edit; `git diff` on the plug clean; full file green.

## Result

KILLED — but not by the cell w382 predicted. Measured correction:

- Contract claimed the killer cell was empty-bearer + UNSET env. Falsified by
  run: with the mutant `>= 0` compiled (beam mtime verified) and env unset,
  the empty token flows `verify("")`→`:error`→env-nil→`:misconfigured`→503 —
  identical to the original's guard-reject→env-nil→503. The w414 503 test
  was added anyway as a contract pin and passes under BOTH versions (8 passed
  under mutant before the killer existed).
- Actual distinguishing cell: INTERNAL_API_TOKEN set to an EMPTY STRING.
  Under the mutant, `secure_compare("", "")` returns true and the request
  AUTHENTICATES (200); the real operator refuses 401. Test
  "empty bearer token with INTERNAL_API_TOKEN set to empty string is refused
  401, never authenticated" FAILS under the mutant (8/9 passed, 1 failed),
  passes on the original.

## Runs (MIX_BUILD_ROOT=_build-laneW414, MIX_ENV=test)

- Original plug, full file (7 old + 2 new): `Result: 8 passed` then after
  killer added `Result: 9 passed`.
- Mutant `> 0`→`>= 0` at line 131 (recompile verified): `Result: 8/9 passed,
  Failed: 1 test` — only the empty-string-env killer.
- Inverse edit; `git diff --stat` on the plug empty (clean).
- Final original, full file: `Result: 9 passed`.
- Build root removed post-run.

Standing: ALIVE (mutation killed on exact subject).
