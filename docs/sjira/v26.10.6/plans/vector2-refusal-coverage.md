# Vector 2 — Refusal Exhaustion & Negative Path Coverage (v26.10.6 convergence audit)

Method: every `REFUSED*` atom and typed `{:error, ...}` refusal variant declared under
`lib/` in `/Users/sac/xaas` and `/Users/sac/ash_surface`, cross-referenced by exact token
against `test/` in the same repo. A variant counts as covered only when its exact atom or
string appears in the test tree. Read-only audit: no builds, no git mutations, only this
file written.

## Summary

- **ash_surface**: every distinct `REFUSED_*` variant declared in `lib/` also appears in
  `test/` at the token level (`comm -23` of lib vs test token sets is empty). No
  variant-level gaps. Two quality caveats below (doctest-only coverage; untyped JS throws).
- **xaas**: **50 distinct `REFUSED_*` variants are declared in `lib/` and appear nowhere
  in `test/`**. Evidence:
  `comm -23 <(grep -rhoE 'REFUSED[A-Z_]*' /Users/sac/xaas/lib | sort -u) <(grep -rhoE 'REFUSED[A-Z_]*' /Users/sac/xaas/test | sort -u)`
  → 50 lines. Plus 4 actuation error atoms and both fail-closed branches of the
  internal-API token plug have no negative fixture.

## Uncovered refusal variants — exact list

Format: path | variant | required negative fixture

### A. Castle engine (`/Users/sac/xaas/lib/xaas/castle.ex`)

| path | variant | required negative fixture |
|---|---|---|
| castle.ex:260,278 | `REFUSED_XAAS_REACTOR_CONTEXT_REQUIRED` | missing/malformed `Xaas.Reactor` context → deterministic `{:error, atom}` halt; assert no intent/receipt rows written |
| castle.ex:272 | `REFUSED_XAAS_CHECKPOINT_WITNESS_MISMATCH` | mutated checkpoint witness → typed refusal, zero state yield |
| castle.ex:274 | `REFUSED_XAAS_CASTLE_CHECKPOINT_REQUIRED` | missing checkpoint → typed refusal, no fallback to ungated execution |
| castle.ex:324 | `REFUSED_XAAS_ADMISSION_EXPIRED` | expired admission on castle path → refusal, no rows |
| castle.ex:326 | `REFUSED_XAAS_ADMISSION_MISMATCH` | foreign admission → refusal, no rows |
| castle.ex:358 | `REFUSED_XAAS_INTENT_NOT_EXECUTING` | stopped intent re-dispatch → refusal |
| castle.ex:417 | `REFUSED_XAAS_CHECKPOINT_HASH_REQUIRED` | checkpoint without hash → refusal before actuation |
| castle.ex:995,998 | `REFUSED_INVALID_CASTLE_DIGEST` | non-hex/wrong-length digest → refusal |
| castle.ex:822 | `REFUSED_CASTLE_AUTHORITY_NOT_ALLOWED` | adapter profile outside authority → refusal, no DO |
| castle.ex (castle family) | `REFUSED_UNRECEIPTED_CASTLE_DO` (965), `REFUSED_WRONG_CASTLE_IDENTITY` (949), `REFUSED_UNKNOWN_CASTLE_ADAPTER_PROFILE` (821), `REFUSED_INVALID_CASTLE_ADAPTER_PROFILE` (824), `REFUSED_INVALID_CASTLE_CONSTRUCT_INTENT` (598), `REFUSED_INVALID_CASTLE_EXECUTION_INTENT` (620), `REFUSED_INVALID_CASTLE_RECEIPT_DIGEST` (961), `REFUSED_CASTLE_CONSTRUCT_DIGEST` (887), `REFUSED_CASTLE_CONSTRUCT_NOT_ALIVE` (909), `REFUSED_CASTLE_CHECKPOINT_DIGEST` (449), `REFUSED_CASTLE_CHECKPOINT_EVIDENCE_PATH` (453), `REFUSED_CASTLE_CHECKPOINT_PROTOCOL_MISMATCH` (429/866), `REFUSED_CASTLE_CHECKPOINT_SOURCE_MISMATCH` (432/869), `REFUSED_CASTLE_CHECKPOINT_WITNESS_MISMATCH` (435/872), `REFUSED_CASTLE_EVIDENCE_ROOT_DRIFT` (884), `REFUSED_CASTLE_KERNEL_DRIFT` (875), `REFUSED_CASTLE_RUNTIME_IDENTITY` (855), `REFUSED_CASTLE_RUNTIME_CONFIGURATION` (857), `REFUSED_CASTLE_SIGNING_IDENTITY_DRIFT` (878), `REFUSED_CASTLE_ADAPTER_PROFILE_DRIFT` (881), `REFUSED_AMBIGUOUS_CASTLE_EVIDENCE` (683), `REFUSED_UNEXPECTED_CASTLE_EVIDENCE_RECORD` (673), `REFUSED_UNVERIFIED_CASTLE_EVIDENCE` (677), `REFUSED_NON_JSON_CASTLE_RESPONSE` (934), `REFUSED_CASTLE_EXIT` (938) | per-variant fixture: mutate exactly one evidence field (digest / witness / release identity / adapter profile / exit status / response encoding), assert the exact `{:error, ...}` tuple and that no castle state (files, rows, receipts) changed. 25 variants, zero fixtures exist (`grep -r 'REFUSED_CASTLE' /Users/sac/xaas/test` → no hits) |
| castle.ex:941 | `BLOCKED_CASTLE_TRANSPORT` | subprocess raise → `{:error, {:BLOCKED_CASTLE_TRANSPORT, msg}}`; assert no consumer string-matches the message |

### B. VKG engine (`/Users/sac/xaas/lib/xaas/semantics/vkg/`)

| path | variant | required negative fixture |
|---|---|---|
| witness.ex:152 | `REFUSED_XAAS_VKG_WITNESS` | subject with no parseable witness → typed refusal; assert no observation rows written |
| replay.ex:95 | `REFUSED_XAAS_VKG_REPLAY` | replay of an unreceipted head → typed refusal; assert nothing persisted |
| semantics/vkg.ex:52 | `REFUSED_VKG_EMPTY_CATALOG` | empty catalog edge → typed refusal, not a crash |

(`REFUSED_XAAS_VKG_WORKSPACE`, `REFUSED_XAAS_VKG_QUERY` are token-covered in test/.)

### C. Actuation engine (`/Users/sac/xaas/lib/xaas/actuation.ex`) — error-atom refusals

None of these atoms appear anywhere in `/Users/sac/xaas/test`:

| path | variant | required negative fixture |
|---|---|---|
| actuation.ex:534 | `:external_admission_identity_mismatch` | foreign admission → deterministic halt, no receipt minted |
| actuation.ex:541 | `:external_input_mismatch` | mutated input vs admission input → halt, no state yield |
| actuation.ex:538 | `:external_projection_mismatch` | mutated projection → halt, no receipt |
| actuation.ex:531 | `:external_receipt_intent_mismatch` | receipt bound to a different intent → halt |
| actuation.ex:764 | `:subject_id_required` | missing subject → typed halt before any changeset |
| actuation.ex:410 | `{:error, {:external_checkpoint_conflict, key}}` | concurrent checkpoint on the same idempotency key → conflict refused, prior receipt intact |
| actuation.ex:382-386 | untyped rescue → `{:ok, {:error, {:exception, struct, Exception.message(error)}}` (line 383) | raising delegate → assert original exception struct preserved (not stringified-only) and no partial state yield |

### C′. Doctest-only coverage trap (ash_surface)

ash_surface's variant-level coverage is partly doctest-only: `vocabulary.ex:20-103`
(`refusal_code?` exercised only against toy inputs `REFUSED_X`, `REFUSED_`,
`REFUSED_\nX`) and `standing.ex:108-109`. Doctests are not adversarial fixtures.
Required: a real negative fixture proving a fabricated standing claim
(`:REFUSED_NO_AUTHORITY` asserted without evidence) is refused by the
standing-evidence check, not merely by the prefix regex gate.

### C″. Health surface HTTP mapping (ash_surface)

`REFUSED_INVALID_SUBJECT` / `REFUSED_INVALID_OPTION` (health.ex:81) have test-tree hits,
but no fixture asserts the documented `200`/`503` HTTP mapping — only the
`{:error, report}` tuple shape.

### C‴. JS projector refusal parity (ash_surface)

The emitted JS runtime (docstring at `ir/event_projection.ex:41-47`; projector source
`projectors/js.ex:497`) throws `Error("REFUSED_UNKNOWN_ACTION: " + id)` and
`Error("REFUSED_NOT_DO_BOUNDARY: ...")` as **untyped string throws**. The Elixir tests
assert these codes, but a string throw is not a machine-readable refusal; the JS errors
carry no structured `{standing, reason}` field.

### D. Fail-closed plug paths
(`/Users/sac/xaas/lib/xaas_web/plugs/require_internal_api_token.ex:70-105`)

| path | branch | required negative fixture |
|---|---|---|
| require_internal_api_token.ex:91-96,103-105 | no bearer header + `INTERNAL_API_TOKEN` unset → `{:error, :misconfigured}` → 503 fail-closed | request with no header, env unset → assert 503 and zero rows written |
| require_internal_api_token.ex:104 (via `authenticate_via_env`) | wrong token + env set → `{:error, :unauthorized}` → 401 | request with `Bearer wrong` → assert 401, zero rows |
| all refusal paths | `conn.assigns[:current_org]` must never be assigned | assert `assigns[:current_org]` nil on every refusal |

Current test evidence: `test/xaas_web/internal_api_router_test.exs` exercises only the
happy path and an Accept-mismatch (tests at lines 25 and 41, both authenticate with the
real env token, line 22). The only 401 assertion in the web test tree is the MCP plug
(`mcp_library_tools_test.exs:143`) — a different plug. **The `RequireInternalApiToken`
fail-closed floor (declared floor in `/Users/sac/xaas/CLAUDE.md`) has zero direct negative
tests.**

### E. Mix-task refusals — covered, listed for exhaustiveness

`REFUSED_NO_EMITTER` and `REFUSED_PER_REPO_CAPACITY_NO_REPO_ALIAS`
(`mix/tasks/xaas.run_validate.ex:33,105`) are covered by
`test/xaas/ultracode/run_validation_test.exs` and
`test/xaas/ultracode/run_validate_task_test.exs`. The remaining mix-task `REFUSED` sites
(`stop_court.ex` 11 sites, `successor.ex`, `episode.ex`, `fabric.redeploy.ex`,
`machine_experience.ex`, `release_audit.ex`, `replay.ex`, `autonomic.controls.ex`,
`sjira.ard_court.ex`, `sjira.engineer_work.ex`, `safe_generate_migrations.ex`,
`telemetry.check_ontology_staleness.ex`, `release_snapshot.verify.ex`) emit bare
`"REFUSED"` strings to stdout, not typed tuples — see section F.

### F. Untyped / string-matching / swallow patterns (flagged — no deterministic-halt fixture is possible until these are typed)

| path | pattern | problem |
|---|---|---|
| castle.ex:941 | `rescue error -> {:error, {:BLOCKED_CASTLE_TRANSPORT, Exception.message(error)}}` | exception reduced to raw string; not machine-readable; no test |
| actuation.ex:383 | `rescue error -> {:ok, {:error, {:exception, error.__struct__, Exception.message(error)}}}` | struct name kept, message stringified; consumers key on this tuple — no fixture pins it |
| sa2a/court.ex:69 | `{:error, {:refused, :malformed_request, Exception.message(error)}}` | stringified message inside an otherwise typed tuple |
| zoe/private_meeting_inference.ex:175 | `refusal(:model_output_not_json, Exception.message(error))` | typed atom + stringified detail; acceptable shape, zero coverage |
| stop_court.ex:1956 | `{:error, "#{path} is not JSON: #{Exception.message(error)}"}` | bare string refusal |
| eds/falsifier.ex:84 | `{:error, "falsifier predicate raised: #{Exception.message(e)}"}` | bare string refusal |
| a2a/zoe_event_simulation_agent.ex:58 | `{:error, "invalid simulation JSON: #{...}"}` | bare string refusal |
| a2a/next_read_user_agent.ex:159 | `{:error, "browse failed: #{...}"}` | bare string refusal |
| marketplace_catalog_live.ex:71,74 | `assign(socket, :ingest_refusal, Exception.message(error))` | raw exception string into LiveView assigns (untyped) |
| health_controller.ex:96 | `error -> {:error, Exception.message(error)}` | untyped |
| capability_coverage.ex:59 | `e -> {:error, Exception.message(e)}` | untyped |
| sjira.engineer_work.ex:73 | `{:halt, {:refused, :invalid_jsonl, %{line: n, error: string}}}` | partial typing only (detail is a string) |
| ash_surface projectors/js.ex:497 (emitted JS) | `throw new Error("REFUSED_UNKNOWN_ACTION: " + id)` | untyped string throw, no machine-readable code field |

No literal `rescue _ -> :ok/nil` swallow-rescues were found in either `lib/` tree
(`grep -rn 'rescue _ ->\|catch _ ->'` over both repos → zero hits). The two rescues in
the core engines (castle.ex:940, actuation.ex:382) convert to error tuples rather than
swallow, but stringify the message.

## Standing

All findings are pre-existing state on `feat/playwright-surface` (d1db2b03); this audit
introduced no code changes. Exact command evidence is cited per section. Falsifier for
this report: re-run the `comm -23` command in the Summary — if the castle/vkg variants
gain test-tree tokens, the list above shrinks accordingly.