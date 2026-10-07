# Ash Configuration Reference

Dry, factual enumeration of xaas's real Ash configuration surface: config keys, domains,
extensions, custom types, and environment variables. This is a reference (Diataxis) doc — for
why these choices were made, see the companion Explanation doc (`explanation/ash-is-the-xaas.md`).

## Compile-time config (`config/config.exs`)

### `:kanban` / `:xaas` app config

| Key | Value |
|---|---|
| `ecto_repos` | `[Xaas.LegacyRepo, Xaas.Repo]` |
| `ash_domains` | `[Xaas.Library, Xaas.Accounts, Xaas.A2a, Xaas.Billing, Xaas.Conference, Xaas.Coupling, Xaas.Generation, Xaas.Graphlaw, Xaas.Governance, Xaas.Igniter, Xaas.Ledger, Xaas.Marketplace, Xaas.Ocel, Xaas.Operations, Xaas.Platform, Xaas.Security, Xaas.TemporalMemory, Xaas.Ultracode, Xaas.Witness]` — 19 domains (`config/config.exs:13-33`, re-verified 2026-10-06) |
| `ash_authentication` | `[return_error_on_invalid_magic_link_token?: true]` |
| `base_resources` | `[Xaas.Resource]` |

`Xaas.Resource` (`lib/xaas/resource.ex`) is a thin `defmacro __using__` wrapper around
`use Ash.Resource, unquote(opts)` — every real `Xaas.*` resource module does
`use Xaas.Resource, otp_app: :kanban, domain: ..., data_layer: AshPostgres.DataLayer, ...`.

### `:ash` global config

| Key | Value |
|---|---|
| `tracer` | `[OpentelemetryAsh]` |
| `allow_forbidden_field_for_relationships_by_default` | `true` |
| `include_embedded_source_by_default?` | `false` |
| `show_keysets_for_all_actions?` | `false` |
| `default_page_type` | `:keyset` |
| `policies` | `[no_filter_static_forbidden_reads?: false]` |
| `keep_read_action_loads_when_loading?` | `false` |
| `default_actions_require_atomic?` | `true` |
| `read_action_after_action_hooks_in_order?` | `true` |
| `bulk_actions_default_to_errors?` | `true` |
| `transaction_rollback_on_error?` | `true` |
| `redact_sensitive_values_in_errors?` | `true` |
| `many_to_many_destroy_destination_on_match?` | `true` |
| `known_types` | `[AshPostgres.Timestamptz, AshPostgres.TimestamptzUsec, AshMoney.Types.Money]` |
| `custom_types` | see [Custom types](#custom-types-registered-under-ash-config) below |

### Custom types registered under `:ash` config

```elixir
custom_types: [
  money: AshMoney.Types.Money,
  capability_class: Xaas.Governance.Types.CapabilityClass,
  interface: Xaas.Governance.Types.Interface
]
```

| Short type code | Module | Definition |
|---|---|---|
| `:money` | `AshMoney.Types.Money` | (from `ash_money` dep) |
| `:capability_class` | `Xaas.Governance.Types.CapabilityClass` | `lib/xaas/governance/types/capability_class.ex` — `use Ash.Type.Enum, values: [:observe, :select, :construct, :do]` |
| `:interface` | `Xaas.Governance.Types.Interface` | `lib/xaas/governance/types/interface.ex` — `use Ash.Type.Enum, values: [:cli, :api, :mcp, :a2a]` |

## The 19 real Ash domains and their extensions

All 19 domains live directly under `lib/xaas/*.ex` (one file per domain), each
`use Ash.Domain, otp_app: :xaas, extensions: [...]`, each with `admin do show? true end`
where extensions permit. Resource counts are read directly from each domain's real
`resources do ... end` block (re-verified 2026-10-07 at HEAD `a0723bf6`; 116 resources total).
Extension columns record which extensions a domain `use`s — that is code
wiring, not proof the corresponding protocol is served over HTTP (see
[GraphQL surface status](#graphql-surface-status) below for the AshGraphql
case).

| Domain module | File | Extensions | Resource count |
|---|---|---|---|
| `Xaas.Library` | `lib/xaas/library.ex` | `AshJsonApi.Domain`, `AshGraphql.Domain`, `AshAdmin.Domain`, `AshAi` | 7 |
| `Xaas.Accounts` | `lib/xaas/accounts.ex` | `AshJsonApi.Domain`, `AshGraphql.Domain`, `AshAdmin.Domain`, `AshTypescript.Rpc` | 5 |
| `Xaas.A2a` | `lib/xaas/a2a.ex` | `AshAdmin.Domain` | 2 (`Xaas.A2a.Agent`, `Xaas.A2a.Task`) |
| `Xaas.Billing` | `lib/xaas/billing.ex` | `AshJsonApi.Domain`, `AshGraphql.Domain`, `AshAdmin.Domain`, `AshTypescript.Rpc` | 8 |
| `Xaas.Conference` | `lib/xaas/conference.ex` | `AshJsonApi.Domain`, `AshGraphql.Domain`, `AshAdmin.Domain` | 7 (`Event`, `Track`, `Session`, `Speaker`, `Sponsor`, `Attendee`, `Registration` — all Ets-backed) |
| `Xaas.Coupling` | `lib/xaas/coupling.ex` | `AshAdmin.Domain` | 1 |
| `Xaas.Generation` | `lib/xaas/generation.ex` | (none) | 1 |
| `Xaas.Graphlaw` | `lib/xaas/graphlaw.ex` | `AshAdmin.Domain` | 2 (`Xaas.Graphlaw.EngineLimit`, `Xaas.Graphlaw.Capability`) |
| `Xaas.Governance` | `lib/xaas/governance.ex` | `AshJsonApi.Domain`, `AshGraphql.Domain`, `AshPaperTrail.Domain`, `AshAdmin.Domain` | 28 |
| `Xaas.Igniter` | `lib/xaas/igniter.ex` | `AshJsonApi.Domain`, `AshGraphql.Domain`, `AshAdmin.Domain`, `AshTypescript.Rpc` | 2 (`Xaas.Igniter.PackManifest`, `Xaas.Igniter.RefusalCode`) |
| `Xaas.Ledger` | `lib/xaas/ledger.ex` | `AshJsonApi.Domain`, `AshGraphql.Domain`, `AshAdmin.Domain` | 4 |
| `Xaas.Marketplace` | `lib/xaas/marketplace.ex` | `AshJsonApi.Domain`, `AshGraphql.Domain`, `AshAdmin.Domain`, `AshTypescript.Rpc` | 3 |
| `Xaas.Ocel` | `lib/xaas/ocel.ex` | `AshAdmin.Domain` | 5 |
| `Xaas.Operations` | `lib/xaas/operations.ex` | `AshJsonApi.Domain`, `AshGraphql.Domain`, `AshAdmin.Domain`, `AshTypescript.Rpc`, `Xaas.Operations.ProjectMeasure.Extension` | 21 |
| `Xaas.Platform` | `lib/xaas/platform.ex` | `AshJsonApi.Domain`, `AshGraphql.Domain`, `AshAdmin.Domain` | 7 |
| `Xaas.Security` | `lib/xaas/security.ex` | `AshAdmin.Domain` | 2 (`Xaas.Security.Finding`, `Xaas.Security.Posture`) |
| `Xaas.TemporalMemory` | `lib/xaas/temporal_memory.ex` | (none) | 1 |
| `Xaas.Ultracode` | `lib/xaas/ultracode.ex` | `AshJsonApi.Domain`, `AshGraphql.Domain`, `AshAdmin.Domain` | 8 |
| `Xaas.Witness` | `lib/xaas/witness.ex` | `AshAdmin.Domain` | 2 (`Xaas.Witness.CertifiedReceipt`, `Xaas.Witness.VerificationKey`) |

### GraphQL surface status

The `AshGraphql.Domain` entries in the table above record **extension
presence only — they do not imply HTTP GraphQL exposure**. At v26.10.6:

- `Xaas.GraphqlSchema` (`lib/xaas/graphql_schema.ex`) compiles, but is **not
  mounted over any HTTP route**: no `Absinthe.Plug` forward exists in
  `lib/xaas_web/router.ex`, the endpoint, or either JSON:API router.
- Only **3 domains** are wired into the schema (`Xaas.Operations`,
  `Xaas.Library`, `Xaas.Marketplace`) — not "most" of the 19 listed above.
- Standing: `UNSUPPORTED(graphql-http-surface)` per
  `docs/sjira/v26.10.6/plans/w802-graphql-surface.md` (verified 2026-10-07 at
  HEAD `a0723bf6`).

What the domains added since the original eight own:

- `Xaas.Coupling` — admission path for the formal proposal coupling engine
  (`Xaas.Coupling.CouplingRun` wires proposal sets into
  `Xaas.Coupling.Engine`'s box-constrained weighted-least-squares solver).
- `Xaas.Generation` — the deterministic generation closure
  (`g(CanonicalGraph) -> Projection`); `ProjectionRecord` is the admission
  boundary forbidding `CanonicalGraph + ManualPatch`.
- `Xaas.Ocel` — object-centric event log: typed `Event`s relate to *sets* of
  typed `Object`s (`EventObject`), objects relate to objects (`ObjectObject`),
  and object state is an append-only fold of `ObjectStateDelta`s.
- `Xaas.TemporalMemory` — bitemporal process memory (`Observation`,
  `Xaas.TemporalMemory.Query.as_of/2`, deterministic replay verifier).
- `Xaas.Ultracode` — Run/Epoch/Receipt control plane for the execution fabric
  (`Run`, `Epoch`, `Receipt`, plus the five `CapitalCensus.*` resources
  `ExperienceCluster`, `Gap`, `Resolution`, `WorkOrder`, `Episode`; see `docs/ultracode/`).

What the six domains added on `feat/playwright-surface` (v26.10.x convergence) own:

- `Xaas.A2a` — A2A protocol surface as Ash resources (PW4):
  `Xaas.A2a.Agent` and `Xaas.A2a.Task` (`lib/xaas/a2a.ex`, commit `bab0f861`).
- `Xaas.Conference` — AGNTCon+MCPCon 2026 domain (XA1r): `Event`, `Track`, `Session`,
  `Speaker`, `Sponsor`, `Attendee`, `Registration`, all Ets-backed private tables
  (`lib/xaas/conference.ex`, commit `9fb8f020`). `Registration :create` enforces
  `EnforceSessionCapacity` (`lib/xaas/conference/registration.ex:60,170-215`): when
  `Session.capacity` is set (nil = unlimited), the count includes only ACTIVE statuses
  `:registered`/`:attended` — a `:cancelled` registration frees its slot, so
  re-registering after cancel succeeds (`:cancelled` is terminal in W795's forward-only
  transition set, re-openable only to `:attended`). Receipt
  `docs/sjira/v26.10.6/plans/w925-slot-release.md` (closes W893's
  `GAP(CancelDoesNotReleaseSlot)`).
- `Xaas.Graphlaw` — graphlaw engine-registry surface as Ash resources (PW6):
  `Xaas.Graphlaw.EngineLimit` and `Xaas.Graphlaw.Capability` (`lib/xaas/graphlaw.ex`,
  commit `cb65ce7b`).
- `Xaas.Igniter` — ggen_igniter surface catalog (PW7): `Xaas.Igniter.PackManifest` and
  `Xaas.Igniter.RefusalCode` (`lib/xaas/igniter.ex`, commit `5fee7516`).
- `Xaas.Security` — estate security posture domain (PW10): `Xaas.Security.Finding` and
  `Xaas.Security.Posture` (`lib/xaas/security.ex`, commit `84099b8f`; domain registered in
  `ash_domains` by `01f4838f`).
- `Xaas.Witness` — certified-receipt witness surface (PW5); see
  [Witness surface](#witness-surface-xaaswitness) below.

## Next Read Library Domain Specification (`Xaas.Library`)

### Resources
1. **`Book`** (`lib/xaas/library/book.ex`): Catalog items with atomic updates (`:borrow_copy`, `:return_copy`), calculations (`:is_available`, `:has_multiple_copies`), and PubSub notifications (`library:books:events`, `library:books:inventory:<id>`).
2. **`Checkout`** (`lib/xaas/library/checkout.ex`): Circulation transactions with atomic triggers (`Xaas.Library.Changes.DecrementBookInventory`) and student-scoped PubSub notifications (`circulation:events`, `circulation:student:<user_id>`). `:borrow` enforces a per-student concurrent cap of 3 open (`:borrowed`/`:overdue`) checkouts — aggregate across books, counted fresh from the DB in an `Ash.Changeset.before_action` guard, refused typed (`InvalidArgument` on `:user_id`) before inventory fires (`lib/xaas/library/checkout.ex:12,90-112`; receipt `docs/sjira/v26.10.6/plans/w902-batch3-repairs.md`, W796-G1).
3. **`HoldRequest`** (`lib/xaas/library/hold_request.ex`): Reservation queues for unavailable titles.
4. **`Curation`** (`lib/xaas/library/curation.ex`): Librarian spotlight recommendations (`recommendations:curation_events`, `recommendations:grade:<grade_band>`).
5. **`RecommendationLog`** (`lib/xaas/library/recommendation_log.ex`): Audit trail of 6-factor weight vectors and rank outputs.
6. **`School`** (`lib/xaas/library/school.ex`): Real row for a Library school (Schema.org `schema:EducationalOrganization`); exactly one row carries `default?: true`, replacing the former hardcoded school-string constant.
7. **`PersonaGrant`** (`lib/xaas/library/persona_grant.ex`): Deny-by-default authorization record binding an authenticated A2A/MCP caller credential to the `Xaas.Accounts.User` id it is allowed to act as.

### Ash AI MCP Server Tools
Exposed at `/mcp` via `AshAi.Mcp.Router`:
- `:list_books` -> `Xaas.Library.Book.read`
- `:books_by_grade_band` -> `Xaas.Library.Book.by_grade_band`
- `:active_curations_for_grade` -> `Xaas.Library.Curation.active_for_grade`

## Witness surface (`Xaas.Witness`)

Added on `feat/playwright-surface` (PW5, commit `3508f427`). The authority for
this surface is the code itself: `lib/xaas/witness.ex`,
`lib/xaas/witness/catalog.ex`, `lib/xaas/witness/certified_receipt.ex`, and
`lib/xaas/witness/verification_key.ex`. Domain extension: `AshAdmin.Domain`
only — the domain is configured in `ash_domains` but is closed to HTTP (no
router entry, not mounted in either JSON:API router; reachable through AshAdmin
and direct Ash calls, not over the wire).

Resources:

- `Xaas.Witness.CertifiedReceipt` (`lib/xaas/witness/certified_receipt.ex`,
  table `witness_certified_receipts`) — an immutable, signature-bearing
  certified receipt over a subject. Payload fields (`subject`, `payload_hash_hex`,
  `algorithm`, `signature_hex`, `verifying_key_hex`) are write-once at create
  time; policies forbid every action except `:read`, create `:ingest`, and the
  narrow `:record_verification` update, which refuses once `verified` is true
  (verification results are also write-once). Stored algorithms: `es256`,
  `ed25519`, `es256k`, `ml_dsa65` (`lib/xaas/witness/certified_receipt.ex:20`);
  all 6 wire algorithms (the 4 stored atoms plus `ES256K_RECOVERABLE` and
  `ML-DSA-65` aliases) round-trip real signatures in the W698 deepening
  courts — ECDSA/Ed25519 via `:crypto`, ML-DSA-65 via the real OpenSSL CLI
  (`pkeyutl -rawin`, FIPS 204) — each with tampered-message negative controls
  (`docs/sjira/v26.10.6/plans/w698-witness-deepening.md`).
- `Xaas.Witness.VerificationKey` (`lib/xaas/witness/verification_key.ex`) — a
  registered verifying key (kid + algorithm + key material); registering the
  same kid twice is refused by identity `:unique_kid`
  (`lib/xaas/witness/verification_key.ex:33`).
- `Xaas.Witness.Catalog` (`lib/xaas/witness/catalog.ex`) — the context that
  ingests affidavit's mutation-baseline JSON plus signing-surface metadata into
  these resources and records verification results. Supported wire algorithms
  additionally include `ES256K_RECOVERABLE` and `ML-DSA-65` aliases.

Identity constraints and ingest semantics (W709/W726):

- Duplicate `(subject, payload_hash_hex)` or duplicate `kid` creates surface
  as a typed `Ash.Error.Invalid` ("has already been taken"), not
  `Ash.Error.Unknown` wrapping a raw `Ecto.ConstraintError`: the identity
  `:unique_subject_payload`
  (`lib/xaas/witness/certified_receipt.ex:49`) and `:unique_kid`
  (`lib/xaas/witness/verification_key.ex:33`) are backed by indexes renamed to
  Ash's derived constraint names by migration
  `priv/repo/migrations/20261007000000_rename_witness_identity_indexes.exs`
  (`witness_certified_receipts_unique_subject_payload_index`,
  `witness_verification_keys_unique_kid_index`; guarded no-op renames,
  reversible `down`). Cited from
  `docs/sjira/v26.10.6/plans/w726-witness-constraint-fix.md`.
- `Catalog.ingest/1` is idempotent-reuse: re-ingesting the same subject
  payload or re-registering the same kid reuses the existing receipt/key
  (byte-identical) instead of faulting
  (`lib/xaas/witness/catalog.ex:115-117`, `lib/xaas/witness/catalog.ex:152`;
  contract cited from `docs/sjira/v26.10.6/plans/w709-witness-durability.md`).

E2E spec `e2e/witness.spec.cjs` (lane W1, v26.10.6) targets a read-only
`/witness` LiveView; the route is mounted at `lib/xaas_web/router.ex:62`
(`live("/witness", WitnessLive)`) and the LiveView is
`lib/xaas_web/live/witness_live.ex`; the domain resources are real and
AshAdmin-visible.
