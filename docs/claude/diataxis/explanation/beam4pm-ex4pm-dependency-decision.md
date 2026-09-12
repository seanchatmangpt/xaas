# beam4pm/ex4pm dependency decision: no mix path/hex dependency

## Decision

xaas does **not** add a mix dependency (path or hex) on `beam4pm` or `ex4pm`
for OCEL v2 process-mining integration. The network boundary (xaas emits/
forwards OCEL data over HTTP to `ex4pm_web`) is the sole integration surface.
`mix.exs` has no `beam4pm` or `ex4pm` entries; this is intentional, not an
oversight.

## Why

- **beam4pm** is not hex-published and has no `package()` metadata in its
  `mix.exs`, so `{:beam4pm, path: "../beam4pm"}` would be an unversioned
  path dependency with no release boundary. Per the beam4pm-rf3-ocel
  finding, its Elixir surface requires externally-built Rust oracle
  binaries referenced by absolute path, and its fixtures are bound to a
  third sibling repo (`~/wasm4pm`) that xaas has no reason to depend on.
  None of that is reusable as a library dependency from xaas.
- **ex4pm** is a multi-app umbrella, also not shown to be hex-published.
  Per ex4pm's own `ex4pm-apps-overview` guidance, if xaas ever needs
  shared OCEL/XES/POWL structs in-process (not just HTTP), the only
  sanctioned surface is `ex4pm_core` — a dependency-free app holding
  canonical structs — never `ex4pm_domain` or `ex4pm_web`, which are
  Ash-app-specific and not meant to be pulled into a consuming host app.
- Neither dependency is required for the current goal (MCP/A2A OCEL
  emission): batch 2's HTTP-based forwarding to `ex4pm_web` achieves that
  goal with zero Elixir-level coupling.

## When to revisit

Only if a future xaas feature needs to **parse or validate OCEL structs
in-process** (not just emit/forward them over HTTP) should a path
dependency be evaluated — and specifically:

```elixir
{:ex4pm_core, path: "../ex4pm/apps/ex4pm_core"}
```

Do not evaluate `ex4pm_domain`, `ex4pm_web`, or any `beam4pm` path
dependency for this purpose; both remain non-reusable/fixture-bound per
the findings above.

## See also

- `docs/claude/diataxis/explanation/wasm4pm-process-intelligence-research.md`
- `docs/claude/diataxis/explanation/ocel-egress-forwarder.md` — batch 2 of
  this integration plan: the real `Xaas.Telemetry.OcelForwarder` HTTP
  forwarding path to `ex4pm_web`, now implemented
