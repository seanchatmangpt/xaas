# W408 — kind-class typed skips (w155 convention) (v26.10.6)

Source finding: `w388-kind-witness.md` — the 4 kind-class files failed loudly
on the offline cluster instead of emitting typed skips.

## Idiom used (w155 shape)

`@moduletag/@tag skip: if(<compile-time probe>, do: false, else: "<typed reason>")`,
exactly mirroring `test/xaas/ultracode/dispatcher_preflight_test.exs:20,24,31`
(`if(System.find_executable("node"), do: false, else: "node not on PATH")`).

Constraint learned (first attempt failed to compile): local `defp` calls are
NOT resolvable at module-attribute position ("undefined function
kind_cluster_reachable?/0 (there is no such import)") — the probe must be a
remote-call expression inline in the attribute. Recorded here so the next lane
does not re-buy this.

## Probes (all real, no mocks)

- 3 e2e kind files: `match?({_, 0}, System.cmd("kubectl", ["--context", "kind-xaas", "get", "nodes", "--request-timeout=5s"]))`
  at module-compile time; exit 0 = reachable = `do: false` (no skip). Offline
  (probe exit 1) = typed skip reason string naming the failed probe.
- prometheus_query_controller_test.exs (per-test `@tag skip:` on the one
  `:kind` test only): `match?({:ok, _}, Req.get(PROMETHEUS_URL || "http://localhost:9090", retry: false, ...))`
  compile-time HTTP probe; a reachable Prometheus never skips.
- `kind_deployment_test.exs` `setup_all` also guarded at RUNTIME (same kubectl
  probe) so a skipped module's `setup_all` cannot fail loudly and invalidate
  the module; online path (start_port_forward!/token fetch) unchanged.
- Do NOT weaken the online path: probe exit 0 → `do: false` → tests run as
  before; `setup_all` still starts the port-forward and fetches the real token.

## Per-file diffs

- `test/e2e/kind_deployment_test.exs` — attrs reordered (kind_context/port
  before tag), inline kubectl probe `@moduletag skip:`, runtime-guarded
  `setup_all`.
- `test/e2e/kind_chaos_pod_recovery_test.exs` — inline kubectl probe
  `@moduletag skip:` (no setup_all in this file; module-level skip covers all
  2 tests).
- `test/e2e/kind_chaos_postgres_pod_recovery_test.exs` — same module-level
  inline probe skip (covers its 1 test).
- `test/xaas_web/controllers/prometheus_query_controller_test.exs` — per-test
  `@tag :kind` + `@tag skip:` with inline Req HTTP probe; the 4 untagged
  default tests untouched.

## Verification (real tails, cluster offline, probe exit=1)

(a) 3 kind files, `--include kind`:

```
Result: 0 tests, 8 skipped
```

`--trace` shows per-test `(skipped)` markers:

```
  * test real deployed pod is reachable and returns a real 200 (skipped) [L#116]
  ... (5 tests, all (skipped))
Result: 0 tests, 5 skipped
```

(b) prometheus_query_controller_test.exs default (untagged only):
`Result: 4 passed, 1 excluded` — untagged tests still green.

All 4 files together, `--include kind`: `Result: 4 passed, 9 skipped`
(4 = untagged prometheus tests, 9 = 8 kind tests + prometheus kind test),
0 failures.

## Known boundary (disclosed, accepted by task)

The probe is compile-time per the w155 exemplar idiom, so on a warm `_build`
a skip decision can go stale until the file recompiles. Compile-time probing
was explicitly directed by the task ("pin availability with `@moduletag skip:
...` conditioned at compile on System.cmd probe") and is the existing w155
convention; runtime re-probing would require setup_all-based invalidation
that ExUnit cannot turn into a typed skip.

## Cleanup

`rm -rf _build-laneW408` — **DENIED** by permission system (twice, 2026-10-06);
build root remains on disk. Coordinator should remove at integration (same as
w388's denied build root).
