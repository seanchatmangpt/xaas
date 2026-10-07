# W984cz2 — Mermaid path-resolution fix-forward — RECEIPT

Lane: W984cz2, xaas v26.10.6 campaign. Subject: branch `feat/playwright-surface`,
uncommitted lane files only (no commit made, per directive). Repairs the typed
defect from W984cx (`docs/sjira/v26.10.6/plans/w984cx-mermaid-depth.md`).

## Fix (lib/xaas/hddl/mermaid.ex, minimal)

Replaced the priv_dir double-dirname climb (which landed in the build `lib/`
dir, e.g. `_build-laneW984cz2/test/lib/docs/hddl/...`) with a single
`project_path/1` helper used by BOTH `for_file/1` and the private
`read_static_mmd/1` fallback:

```elixir
defp project_path(path) do
  case Path.type(path) do
    :absolute -> path
    _relative -> Path.join(File.cwd!(), path)
  end
end
```

Relative paths resolve from the project root (mix-run-safe: `File.cwd!` is the
repo root under `mix test`/`mix run`); absolute paths pass through unchanged.

## Before / after (real probe, `mix run`, lane root)

Before (W984cx, observed): `for_file("docs/hddl/actuation_reactor.mmd")` →
`{:error, {:file_read_error, :enoent, ..._build.../lib/docs/hddl/actuation_reactor.mmd}}`.

After (this lane, actual output):
```
:ok                                        <- for_file("docs/hddl/actuation_reactor.mmd")
:ok                                        <- for_file("/Users/sac/xaas/docs/hddl/actuation_reactor.mmd")
{:error, {:file_read_error, :enoent, "/Users/sac/xaas/docs/hddl/nope.mmd"}}
```
Typed-error shape for missing files preserved (W984cx court test 3 unchanged
and passing).

## Court update (test/xaas/hddl_mermaid_depth_test.exs)

- Removed W984cx's disclosed `File.read` bypass in test 4; the static fixture
  is now read through the public `for_file/1` path.
- Added test: `for_file` resolves the real repo-relative fixture AND an
  absolute path to identical content (`{:ok, ^content}` pin).
- Court is now 7 tests, 0 mocks.

## Verification (real output)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984cz2 \
  mix test test/xaas/hddl_mermaid_depth_test.exs --seed 411
Result: 7 passed
$ ... mix test test/xaas/hddl_mermaid_depth_test.exs --seed 987654
Result: 7 passed
```
Both exit 0. Grafana/PromEx nxdomain / os_mon lines are pre-existing ambient
noise.

## Standing (W984cx pins flipped)

- `for_file/1` happy path on real fixture: **ALIVE** (was
  UNSUPPORTED(path-resolution defect)).
- `read_static_mmd/1` static fallback: resolution path repaired and shared
  with the now-proven `for_file/1` helper. Honest boundary: the fallback's
  own happy branch (runtime `to_mermaid` failure → `.mmd` read) is still not
  directly witnessed — triggering it needs a reactor whose runtime generation
  fails, which no court constructs. Downgraded defect (path bug) fixed;
  branch coverage remains partial.
- All other W984cx ALIVE pins unchanged; full court green ×2 seeds.

## Build root

`_build-laneW984cz2` deletion attempted post-verification; `rm -rf` denied by
the permission system this session (same as W984cx). Root left on disk
(~426 MB) for coordinator removal at integration (fanout cleanup law).
