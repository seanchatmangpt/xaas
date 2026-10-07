# UltraCode Runtime Contract (v26.10.6)

Reference for the two-port runtime law a leased UltraCode worker runs under. Every statement
below is derived from code on branch `feat/playwright-surface` (v26.10.6 campaign, HEAD
`a0723bf6`); the policy DATA is
`priv/ultracode/runtime_surface.json` (schema `xaas-ultracode-runtime-surface/v1`), compiled by
`lib/xaas/ultracode/runtime_surface.ex` (a malformed policy fails the build).

```text
ExternalSemanticPorts(UltraCode) = {SA2A, sJira}
local construction = {filesystem, local_shell, compiler, test_runner, generator, local_git}
direct_external = deny; consequential DO only via BRCE (Xaas.Actuation.run/4)
```

## Worker verbs (MCP `tools/call`, `lib/xaas_web/controllers/execution_fabric_controller.ex`)

The MCP surface `POST /internal-api/execution/mcp` exposes exactly ten tools (the
`@mcp_tools` registry and the `dispatch_tool/2` clauses, same file). Nine require a live
lease token; only `claim_next` does not.

| Verb | Lease required | Required args (wire) | Kernel call |
|---|---|---|---|
| `claim_next` | no | `provider` (defaults to `ProviderRegistry.default_provider/0`) | `Lease.claim_next/3` |
| `heartbeat` | yes | `lease_token` | `Lease.renew/1` |
| `admit_tool` | yes | `lease_token`, `tool` | `Lease.admit_tool/2` |
| `record_provider_event` | yes | `lease_token`, `event` | `Lease.record_provider_event/2` |
| `close_candidate` | yes | `lease_token`, `final_head`, `outcome` | `Lease.close/4` |
| `refuse` | yes | `lease_token`, `reason` | `Lease.refuse/3` |
| `cancel_work` | yes | `lease_token`, `reason` | `Lease.cancel/3` (seals a `:blocked` receipt with `cancelled_by` evidence) |
| `actuate` | yes | `lease_token`, `capability`, `resource`, `action`, `idempotency_key` | capability re-resolution + `Lease.actuate/2` |
| `resolve_capability` | yes | `lease_token`, `capability` | `Lease.lease_context/1` + `CapabilityPort.resolve/4` |
| `surface` | yes | `lease_token` | `Lease.surface/1` |

A directed `claim_next` may pass `epoch_id`; a malformed (non-UUID) `epoch_id` is the typed
`invalid_epoch_id` refusal — never a silent fallback to oldest-first (`claim_opts/1`,
`execution_fabric_controller.ex:414-421`).

## Work plane: sJira

`claim_next` returns the lease fields plus `Lease.claim_envelope/3`
(`lib/xaas/ultracode/lease.ex`): `surface` and `work`.

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

## Token floor (W723 court)

The MCP fabric sits behind `XaasWeb.Plugs.RequireInternalApiToken` (fail-closed). The W723
deepening court (`test/xaas_web/require_internal_api_token_deepening_test.exs`, 16/16 pass)
pins the matrix on the real plug + router:

- absent `INTERNAL_API_TOKEN` + no header -> `503` with exact body
  `%{"error" => "internal_api_misconfigured", "detail" => "INTERNAL_API_TOKEN is not set on the server"}`, halted;
- absent env + wrong bearer -> still `503` (fail-closed outranks auth);
- env present + no/wrong bearer -> `401` with exact body
  `%{"error" => "unauthorized", "detail" => "missing or invalid Bearer token"}`, halted;
- valid token -> unhaltered, `assigns[:current_org]` nil on the legacy env tier;
- Bearer parse discipline: exact `["Bearer " <> token]` single-element match, nonempty token;
  lowercase/ALL-CAPS scheme, missing space, empty credentials all `401` (empty credentials
  under absent env = `503`).

Known residual (W723 court finding, unchanged): on the `/internal-api` json-api router scope
an incompatible `Accept` header raises `Phoenix.NotAcceptableError` BEFORE the token floor —
406 outranks auth there; only the `/api` forward scope has the floor-first fix. The W745
court (`test/xaas_web/execution_fabric_deepening_test.exs`, courts d.1/d.2) re-pins the same
401/503 matrix directly on `/internal-api/execution/mcp`.

## Refusal-shape contract (W745 / W747 courts)

The W745 execution-fabric deepening court (`test/xaas_web/execution_fabric_deepening_test.exs`)
pins the exact wire shapes a provider worker sees on the MCP surface:

- consequential verbs without a valid lease answer typed `Failure` maps:
  `actuate` with an unknown token -> `{"error": "WORK_NOT_FOUND", "failure": {"code":
  "WORK_NOT_FOUND", "details": {"reason": "no_lease", "detail": "<token>"}}}`;
  live lease but no `capability` -> `{"error": "UNAUTHORIZED", "failure": {"code":
  "UNAUTHORIZED", "details": {"reason": "capability_required", "required":
  "UltraCode -> SA2A -> resolve_capability -> actuate(capability)"}}`;
- `admit_tool`/`heartbeat`/`close_candidate` on an unknown lease answer the string form
  `{"error": "no_lease:\"<token>\""}` (`format_reason/1` shape, not a `Failure` map);
- missing `lease_token` on `actuate` -> the bare transport refusal
  `{"error": "lease_token_required"}`;
- missing `resource`/`action`/`idempotency_key` never reaches the registry: the capability
  court answers `UNAUTHORIZED` first, so an unregistered pair is never downgraded to a shape
  error; a live lease + actuating capability + unregistered `{resource, action}` pair is the
  typed `unregistered_actuation` string naming the pair;
- unknown verb -> `{"error": "unknown_tool:\"<name>\""}`; malformed JSON-RPC envelope ->
  `400` `{"error": "bad_request", "detail": ":invalid_request"}`; non-object JSON body ->
  `400` `{"error": "bad_request", "detail": ":invalid_json"}`;
- any unexpected raise inside the dispatch answers typed JSON-RPC `500`
  `{"jsonrpc": "2.0", "id": null, "error": {"code": -32603, "message": "internal error"}}` —
  never the HTML DebugPage;
- refusal shapes are deterministic: the same request twice returns identical body bytes;
- the MCP `refuse` verb seals a real `:refused` Receipt, durably readable on the lawful
  `GET /internal-api/execution/epochs/:id/receipts` read path (epoch lands `:failed` through
  the atomic lease-guarded write).

The W747 court (`test/xaas/actuation/run_idempotency_deepening_test.exs`) pins the
`Xaas.Actuation.run/4` idempotency/replay contract underneath `actuate`: same key twice
replays the original consequence state (no new intent/receipt rows, `replay: true`); different
keys for equivalent intents produce two real receipts (no dedup); replay survives process
restart; a missing key and missing/delegated-without-authority evidence are the exact typed
refusals; key reuse while the intent is still `:executing` is NOT replayable; two full
succeed-then-replay cycles produce byte-identical envelopes.

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
| `test/xaas_web/require_internal_api_token_deepening_test.exs` | W723 auth-floor matrix (401/503, Bearer parse, Accept ordering) |
| `test/xaas_web/execution_fabric_deepening_test.exs` | W745 MCP refusal shapes, actuate-to-kernel routing, determinism |
| `test/xaas/actuation/run_idempotency_deepening_test.exs` | W747 replay/idempotency contract of `Xaas.Actuation.run/4` |

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

## Addendum (post-W749, verified 2026-10-07, lane W874)

Spot-verified against code at `feat/playwright-surface` @ `a0723bf6` (working tree).
Every W749-era claim checked still holds: ten `@mcp_tools` rows / ten verbs
(`execution_fabric_controller.ex:72-212`), typed `invalid_epoch_id` on a malformed
`claim_next` `epoch_id` (`execution_fabric_controller.ex:417,682`), the closed
failure-code set (`runtime_surface/failure.ex:11-28`), the W840 clock-seam routing
(`lease.ex:372-377` `live_leases/1`, `lease.ex:513-521` `renew/1`), the warming-up
health branch (`health_controller.ex:202-243`), and all witness files on disk.

### Clock-seam unification (W840)

`Lease.live_leases/1` and `Lease.renew/1` now read `DurationBudget.now()` (the
`:ultracode_clock` seam), not `DateTime.utc_now/0`: the capacity meter, the claim
kernel's reclaim filter, and the renewal base all judge expiry on ONE clock
(`lib/xaas/ultracode/lease.ex:372-377, 513-521`). Consequences: a fast-forwarded seam
frees the slot of a kernel-expired lease (`live_leases/1` excludes it; a
capacity-fenced claim can bind the pool), and a renewal is observable against the seam
(`lease_expires_at = advanced_now + 30m`, `last_heartbeat_at = advanced_now`). Receipts:
`docs/sjira/v26.10.6/plans/w811-lease-kernel-deepening.md` (findings 1-2, drift asserted
as gap) and `w840-clock-seam.md` (repair; 23 + 84 tests green, ALIVE). `updated_at` and
receipt `sealed_at` stamps remain real wall clock.

### Health contract: `ultracode_tick` warming_up (W836 — supersedes W752's 503 reading)

Under Oban `testing: :manual` (empty sandbox `oban_jobs`), the real `ultracode_tick`
contract is typed `skipped(:warming_up)` with aggregate 200 — `warming_up` grace is
node boot + 7 minutes (`health_controller.ex:202-243`; seam
`:health_node_boot_at_override`). W752's "503" reading is the past-grace case only:
past boot+7min with zero tick evidence is a real 503 error ("appears dead, not just
warming up"); post-boot staleness (>5 min since last tick) is a separate error branch.
Fail-closed aggregate: only real `"error"` degrades to 503; `"skipped"` is not down.
Full 10-check court: `test/xaas_web/health_court_test.exs` (11 tests, receipt
`docs/sjira/v26.10.6/plans/w836-health-court.md`, ALIVE 11/11 x2). Typed gap: no check
has a timeout — a hung collaborator hangs the request.

### Lease-kernel court coverage (W811)

`test/xaas/ultracode/lease_kernel_deepening_test.exs` (21 W811 courts + W840 seam
courts, 23 green) pins: claim expiry mechanics (30m TTL, strict `:lt` liveness, typed
`{:lease_expired, token}`, re-claim overwrites token), heartbeat extension +
`{:no_lease}`/`{:lease_not_live, :failed}` refusals, `admit_tool`
court-before-registry ordering (expiry/terminality never demoted to a registry
verdict), `refuse/3` exactly-once + slot release + bearer-token-never-in-evidence,
determinism of oldest-first claims and `pool_capacity/1` parsing. Receipt:
`docs/sjira/v26.10.6/plans/w811-lease-kernel-deepening.md` (PARTIAL_ALIVE; the two
drift findings it recorded are repaired by W840 above).

### JSON:API content negotiation (W817)

The token floor outranks content negotiation on BOTH scopes: every unauthenticated x
incompatible-`Accept` cell answers the exact 401 body, never 406
(`test/xaas_web/jsonapi_content_negotiation_test.exs`, 16 tests, receipt
`docs/sjira/v26.10.6/plans/w817-negotiation-court.md`, ALIVE 16/16 x2). The residual
stated above (authenticated incompatible `Accept` raises `Phoenix.NotAcceptableError`
before the floor on the `/internal-api` json-api scope) is confirmed unchanged by this
court. Content-Type discipline is split: `application/json` POST gets a real 415
document from AshJsonApi; `text/plain` raises `Plug.Parsers.UnsupportedMediaTypeError`
first.

## See Also

- `docs/claude/diataxis/reference/actuation-and-semantics.md` — actuation, idempotency, receipts.
- `docs/claude/diataxis/reference/http-api-surface.md` — `/internal-api` auth boundary.
- `docs/claude/diataxis/reference/sa2a-computation-boundary.md` — SA2A boundary.
