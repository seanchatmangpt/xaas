# W343 — ggen_igniter CLI rung freshness receipt (v26.10.6)

Date: 2026-10-06. Lane: W343. Standing: ALIVE (all gates green).

## Subject

- Repo: `/Users/sac/ggen_igniter` (canonical checkout, branch `feat/adr-0010-gate-convention`)
- HEAD: `7dbcdb3a050ea4b2ce4d5f047ed2913052b5b539`
- Dirty files: 63 (`git status --porcelain | wc -l`)
- Lane build root: `MIX_BUILD_ROOT=/Users/sac/ggen_igniter/_build-laneW343` (private, MIX_ENV=test)

## Commands + real tails

### 1. Test suite (freshness gate)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/ggen_igniter/_build-laneW343 mix test
```

Real tail (exit 0):

```
Finished in 552.5 seconds (121.0s async, 431.5s sync)
25 doctests, 42 properties, 1555 tests, 0 failures, 5 skipped (720 excluded)
[os_mon] memory supervisor port (memsup): Erlang has closed
[os_mon] cpu supervisor port (cpu_sup): Erlang has closed
```

**1555 pass / 0 failures** — matches prior green exactly.

### 2. Credo --strict

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/ggen_igniter/_build-laneW343 mix credo --strict
```

Real tail (exit 0):

```
Analysis took 11.4 seconds (6.0s to load, 5.4s running 69 checks on 491 files)
4421 mods/funs, found 22 refactoring opportunities, 37 code readability issues, 139 software design suggestions.
Use `mix credo explain` to explain issues, `mix credo --help` for options.
```

Exit code 0 — **clean under strict** (no failures; the counts above are informational
severity, below any failure gate). No lint regressions vs prior green.

### 3. Promoted pack present (read-only proof)

`ls /Users/sac/ggen_igniter/priv/ggen/ash-manufacture-pack/`:

```
bin
gates
ontology.ttl
README.md
templates
verify
```

### 4. Fixture-dir check — finding

`test/fixtures/ash_manufacture_pack` **does not exist** on this subject. It was removed
by the promotion itself, not by this lane: deletion commits are the v26.9.25
`preserve(...)` series (`117010d`, `635edc8`, `6365f42`), which predate this lane and
also predate the prior green 1555/0 run. The active test suite references
`priv/ggen/ash-manufacture-pack` directly (e.g. `test/ggen_igniter_ash_manufacture_pack_test.exs`);
only historical qualification artifacts under `test/fixtures/.qualification/book_library/`
(stale absolute paths) still mention the old fixture dir. **Nothing was destroyed by
this lane**; the fixture dir's absence is the settled post-promotion state that the
prior green run was also against. Recorded verbatim per contract as a finding, not fixed.

## Cleanup law

`rm -rf /Users/sac/ggen_igniter/_build-laneW343` — **denied by permission system**.
Operator cleanup required: `/Users/sac/ggen_igniter/_build-laneW343`

## Verdict

**ALIVE** — DoD 5 CLI rung freshness confirmed for ggen_igniter @ `7dbcdb3a`:
1555/0 tests (real, exit 0), credo strict exit 0, promoted pack present.
Fixture-dir finding recorded verbatim; no fixes applied; no commits made.
