# W6 Receipt — ash-manufacture-pack promotion (v26.10.6 convergence)

*Backfilled by coordinator from lane completion report.*

- **Repo**: /Users/sac/xaas
- **Change**: pack promoted `test/fixtures` → `priv/ggen/ash-manufacture-pack` via `git mv` (staged).
- **Call sites**: 8 test files + 2 `Path.join` sites updated to the new pack root.
- **E2 fence preserved**: the blanket "ash" marketplace reject (origin 00b561a; operator
  directive 2026-09-28 "Ash must not ship with hex") is intact with ONE named exception —
  `ash-manufacture-pack` ships. A pinned test asserts it is the sole ash root via real
  `mix hex.build --unpack`.
- **E4**: `@source_pack` attribute fixed to the new pack path.
- **E5 docs synced**: README, AGENTS, docs/lib docstrings, `day_zero.sh`.
- **CHANGELOG**: Unreleased entry added.

## Gate (real output)

- 1555 tests, 0 failures, 5 skipped (elixir 1.19.5-otp-27).
- `mix format --check-formatted` fails only 2 pre-existing files (subsequently formatted by W38).
