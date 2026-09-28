# UltraCode Runtime Contract (v26.9.27)

Reference for the two-port runtime law a leased UltraCode worker runs under. Every statement
below is derived from code on branch `v26.9.27/closure-runtime`; the policy DATA is
`priv/ultracode/runtime_surface.json` (schema `xaas-ultracode-runtime-surface/v1`), compiled by
`lib/xaas/ultracode/runtime_surface.ex` (a malformed policy fails the build).

```text
ExternalSemanticPorts(UltraCode) = {SA2A, sJira}
local construction = {filesystem, local_shell, compiler, test_runner, generator, local_git}
direct_external = deny; consequential DO only via BRCE (Xaas.Actuation.run/4)
```

## Work plane: sJira

`claim_next` (MCP, `lib/xaas_web/controllers/execution_fabric_controller.ex`) returns the lease
fields plus `Lease.claim_envelope/3` (`lib/xaas/ultracode/lease.ex`): `surface` and `work`.

| `work` field | source |
|---|---|
| `id` | `run.work_order_iri`, else `run.id` |
| `subject` | `repo` (`repository_identity` or `execution_repo_alias`), `base_sha`, `branch` (nil) |
| `objective` | `run.goal` |
| `acceptance` | `verifier_suite`, sorted keys of `court_map["acceptance"]` / `["falsifiers"]` |
| `dependencies` | `run.dependency_evidence` |
| `provenance` | `work_order_iri`, `checkpoint_iri`, `graph_digest`, ... |

`surface` (also the `surface` MCP tool, `Lease.surface/1` -> `RuntimeSurface.effective_surface/1`)
carries `semantic_ports`, `local_primitives`, `direct_external: []`, `agent_tools`, `subject`,
`policy_digest` (sha256 of the raw policy bytes), `lease_id` (never the bearer token), and
`authority` (`"NONE"` unless granted).

## Capability plane: SA2A

`resolve_capability(lease_token, capability, constraints)` ->
`Lease.lease_context/1 |> CapabilityPort.resolve/4` (`lib/xaas/ultracode/capability_port.ex`).
The subject is always the lease's; `constraints.subject` is a claim, and any mismatch on `repo`
or `base_sha` is `PROVENANCE_MISMATCH`. The decision is the capability-resolution court
(`CapabilityResolver.resolve_item/2`); the port has no provider code and no fallback.

Bound handle fields: `capability_id`, `requested`, `selected`, `subject`, `constraints`,
`authority_requirement` (`brce` | `none`), `invocation_contract` (`actuate` | `local`),
`provenance` (`resolution_class`, court `receipt`, `policy_digest`), `lease_token`, `work_id`,
`state: "bound"`. A capability is local only if its namespace is `recipe`/`local` or a segment is
a local verb, and no segment is an external verb; everything else is consequential (fail-closed).

Verdicts: `reuse`/`compose` bind; `frontier`/`generate`/`extend` -> `NO_CAPABILITY`;
`unresolved` -> `CAPABILITY_UNAVAILABLE` if a counted source errored/skipped, else
`NO_CAPABILITY`. Every failure appends one capability-gap NDJSON record (`record_gap/2`).
`check_handle/2` revokes a handle on a dead or different lease (`UNAUTHORIZED`, `revoked`) or a
moved base (`STALE_SUBJECT`).

Typed failures (closed set, `lib/xaas/ultracode/runtime_surface/failure.ex`), rendered as
`{"error": CODE, "failure": {"code", "details"}}`: `NO_CAPABILITY`, `AMBIGUOUS_CAPABILITY`,
`CAPABILITY_UNAVAILABLE`, `UNAUTHORIZED`, `WORK_NOT_FOUND`, `STALE_SUBJECT`,
`INVALID_TRANSITION`, `PROVENANCE_MISMATCH`, `CONFLICTING_REPLAY`,
`FORBIDDEN_EXTERNAL_SEMANTIC_EDGE`. Provider detail stays inside `details`.

## Construction plane: local

Tool rows in the policy JSON: `lease_admit: true` for `Read`, `Grep`, `Glob`, `Edit`, `Write`,
`Task`, `TodoWrite`. `RuntimeSurface.admit_tool/2` (called by `Lease.admit_tool/2`): refusal rows
win; `WebFetch`/`WebSearch` -> `forbidden_external_semantic_edge` naming
`UltraCode -> SA2A -> resolve_capability`; `Bash`, `git_push`, `publish` ->
`refused_no_authority`; `:ultracode_provider_tools` can only narrow.

Host gate `priv/zcode_plugin/marketplace/xaas-fabric/scripts/xaas-gate.mjs` loads the policy
`gate` section (`XAAS_SURFACE_PATH` or the repo path; a built-in floor never widens on load
failure). Order: `deny_tools` denied before any lease read or HTTP; `xaas-execution` MCP tools
allowed only when the name is in `gate.port_tools` (exact match, not a prefix); `Agent`
denied unless `XAAS_ALLOW_SUBAGENTS=1` (which `WorkerEnv` never forwards); `Bash` argv
allowlist:

- single simple command only (no chaining, pipes, redirection, substitution, globbing);
- `git` inside the leased worktree, subcommands `git_subs`, flags in `git_forbidden` and
  `--git-dir`/`--work-tree`/`--output` denied; sweep mode (`XAAS_SWEEP=1`) allows
  `git_sweep_subs` outside the worktree except `sensitive_home_dirs`;
- `read_helpers` (`ls cat head tail wc`) worktree-confined; `pwd`, `echo`, `date`;
  `node` only for `xaas-lease.mjs save|get|clear`;
- `sh`, `bash`, `zsh`, `env` refused (`SHELL_IS_NOT_AUTHORITY`): a worker-written script is
  arbitrary code no argv check can bound; acceptance runs go through the lease verifier suite.

Other tools after a lease go to the server `admit_tool`.

## Actuation plane: BRCE

The `actuate` MCP tool requires `capability`: the server re-resolves it for this lease (a wire
handle is never trusted), re-checks it with `check_handle/2`, and admits only
`invocation_contract == "actuate"` (else `UNAUTHORIZED` `capability_not_actuating`; missing ->
`capability_required`). Then `Lease.actuate/2`:

- `{resource, action}` must be in `:ultracode_actuation_registry` for the provider (empty by
  default); else `{:unregistered_actuation, ...}`. The subject id comes from the registry entry,
  never the wire;
- authority evidence is lease-provenanced (`lease_fingerprint` = sha256 of the token);
- `Xaas.Actuation.run/4` with the caller's `idempotency_key` (blank refused by the kernel).
  Same key + same resource/action/subject/input hash/projection hash replays the sealed
  result; any difference is `{:idempotency_conflict, key}` (`lib/xaas/actuation.ex`), which
  `Failure.from_term/1` maps to `CONFLICTING_REPLAY` (on the `actuate` wire, errors after the
  capability check are still `format_reason/1` strings, not `Failure` maps).

## Worker environment law

`Dispatch` spawns `/usr/bin/env -i` + `WorkerEnv.env_argv/1` (`lib/xaas/ultracode/dispatch.ex`,
`lib/xaas/ultracode/worker_env.ex`). Name precedence for `WorkerEnv.allowed?/1`:

1. name not matching `name_regex` -> refused;
2. `model_provider_names` and `port_credential_names` (`XAAS_MCP_TOKEN`) -> admitted;
3. `deny_names`, `deny_prefixes`, `deny_word_regex` -> refused;
4. `allow_names`, `allow_prefixes` (`LC_`) -> admitted; anything else refused.

Any value matching `credential_value_regex` (`scheme://u:p@`, `Password=`) is refused under
every name. URL names in `url_names_no_userinfo` must be plain `http(s)` URLs with a host and
no `@`, query or fragment. `XAAS_SURFACE_PATH` is set by `Dispatch` after all pairs, so no
caller can redirect the gate policy. Caller additions
pass the same law; explicit pairs (`env_added`: gate vars, repo `toolchain_env`, `:extra_env`)
may name unlisted variables but never denied ones, and win on conflict. Receipts carry names
only (`key_names/1`, `dropped/2`).

## Falsifier and witnesses

Falsifier: a leased worker reaches an external semantic edge, or a consequential DO, by any
route other than SA2A `resolve_capability` -> `actuate` -> registry -> `Xaas.Actuation.run/4`;
or a forge/cloud credential in the node environment reaches the worker process.

| Witness | Covers |
|---|---|
| `test/xaas/ultracode/runtime_surface_test.exs` | policy rows, `admit_tool/2`, codes |
| `test/xaas/ultracode/worker_env_test.exs` | allow/deny law, real `/usr/bin/env` child |
| `test/xaas/ultracode/dispatch_worker_env_test.exs` | fixture credentials absent from spawn env |
| `test/xaas/ultracode/capability_port_test.exs` | verdicts, provenance, revocation, dead SA2A |
| `test/xaas/ultracode/lease_surface_test.exs` | lease context, surface, envelope, subject court |
| `test/xaas/ultracode/gate_surface_test.exs` | real `node` gate reads the policy `gate` section |
| `test/xaas/zcode_plugin/gate_test.exs` | gate argv allowlist |
| `test/xaas_web/controllers/execution_fabric_surface_test.exs` | MCP surface tools |
| `test/xaas_web/execution_fabric_controller_test.exs` | MCP fabric incl. `actuate` |
| `test/xaas/ultracode/two_port_e2e_test.exs` | claim -> construct -> resolve -> actuate/replay |
| `test/xaas/actuation_test.exs` | kernel idempotency conflict |

## Residual edges

- Model-provider credentials (`ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN`, `ZCODE_API_KEY`) are
  admitted into the worker env by design; the worker holds a real external credential.
- No OS network sandbox on darwin: `Dispatch` states it is not an OS sandbox; network denial is
  the gate plus env law, not the kernel.
- Files outside `sensitive_home_dirs` stay readable: `Read`/`Grep`/`Glob` are denied only
  inside those dirs (`readPathDecision` in the gate, any path), and sweep-mode Bash reads
  reach anything under `HOME` except them.
- The ggen_igniter surface declaration is not yet emitted; `RuntimeSurface.admit_declaration/1`
  is the admission seam (request intersected with policy, one diag per offending edge).

## See Also

- `docs/claude/diataxis/reference/actuation-and-semantics.md` — actuation, idempotency, receipts.
- `docs/claude/diataxis/reference/http-api-surface.md` — `/internal-api` auth boundary.
- `docs/claude/diataxis/reference/sa2a-computation-boundary.md` — SA2A boundary.
