# W434 — Witness slice receipt (v26.10.6)

Lane: W434 · Repo: /Users/sac/xaas @ feat/playwright-surface · one canonical checkout, no commit.

## Command (real)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW434 \
  mix test test/xaas/witness/ test/xaas_web/live/witness_live_test.exs
```

## Real tail (verbatim)

```
.........
Finished in 1.9 seconds (0.9s async, 0.9s sync)

Result: 9 passed
[os_mon] memory supervisor port (memsup): Erlang has closed
[os_mon] cpu supervisor port (cpu_sup): Erlang has closed
```

Exit code 0. 9 tests, 0 failures, 0 skipped. (Compile-only output went to the pipe before the tail; fresh lane build root, ~17 min cold compile, 1.9 s test run.)

## Algorithm census (witness test code + KAT fixture)

 exercised in assertions:
- `:es256` — ingest + `list_by_algorithm(:es256)` (catalog_test.exs:44,133) and LiveView render ("es256", witness_live_test.exs:34,52)
- `:ml_dsa65` — ingest + `list_by_algorithm(:ml_dsa65)` (catalog_test.exs:44,136)
- Enum rejection court: `"ES256+ML-DSA-65"` and `"SLH-DSA-SHA2-128s"` → `:algorithm_not_in_admitted_enum` (catalog_test.exs:47-48)
- `:ed25519` — only as a negative (`list_by_algorithm(:ed25519)` → `[]`, catalog_test.exs:137); no Ed25519 ingest/assert
- `:sha256` — used only as `:crypto.hash` for the baseline fixture hash (catalog_test.exs:37) and as subject-id prefix strings (`"sha256:..."`, witness_live_test.exs:45,57); not a signature algorithm
- BLAKE3: **zero occurrences** anywhere in the witness test tree

KAT fixture `test/xaas/witness/fixtures/crypto_trust_kat.json` carries vectors for `ES256` and `ES256+ML-DSA-65` (hybrid), confirming the PQC surface is hybrid ECDSA+ML-DSA-65.

## Cleanup

`rm -rf /Users/sac/xaas/_build-laneW434` — **DENIED** by permission system. Build root remains on disk (~ GB-scale, fresh MIX_ENV=test compile). Coordinator should remove it at integration per the lane-build-root lease law.

## Verdict

ALIVE at current tree incl. OS-17 vault guard: 9/9 witness tests pass fresh. Definitive for w405: the Art.12 witness surface exercises ES256 + ML-DSA-65 (hybrid); no BLAKE3 anywhere in the witness tests; SHA-256 appears only as content-hash/subject prefix, not signature.
