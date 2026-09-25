# wave1-06: XaaS authority/secrets mapping for the ZCode bridge

Read-only survey of /Users/sac/xaas (+ zcode-cli auth shape). No secrets printed; filenames and env-var NAMES only.

## 1. The consequence fence today

There is NO `CommandBus` module in code — it is a target-architecture concept
(`docs/ultracode/c4-architecture.md:74`). The fence exists as TWO real code paths
plus one governance doc.

### Path A — consequential DO (ActuationIntent path)

- `Xaas.Actuation.run/4` — `/Users/sac/xaas/lib/xaas/actuation.ex:14`; "ontology
  projection -> admission -> intent -> prepared receipt -> Ash.Reactor DO ->
  sealed receipt" (moduledoc :5-6), wrapped in one data-layer transaction so a
  committed mutation cannot outrun its receipt (`actuation.ex:32-46`).
- `Xaas.Actuation.Reactor` (`actuation.ex:107`): ash_steps `:admit`
  (`actuation.ex:133`) → `:do` (`actuation.ex:147`, with `undo`) → `:receipt`
  (`actuation.ex:157`). Kernel: `Xaas.Actuation.Kernel.admit/2`
  (`actuation.ex:175`), authority gate `admit_authority/2`
  (`actuation.ex:325-331`).
- Admission row = `Xaas.Operations.ActuationIntent`
  (`/Users/sac/xaas/lib/xaas/operations/actuation_intent.ex`): `create :admit`
  (:35-55) runs `Validations.FrontierEvidence` + `Validations.CausalAdmission`
  (:53-54); status vocabulary `[:admitted, :executing, :succeeded, :failed,
  :refused]` (:121-126); idempotency identity (:133).
- Frontier evidence: `/Users/sac/xaas/lib/xaas/actuation/validations/frontier_evidence.ex:6-8`
  — "fails closed on malformed bundles; absence allowed; once supplied, all four
  producer classes + exact authority ceilings + digest must validate."
- Causal admission: `/Users/sac/xaas/lib/xaas/actuation/validations/causal_admission.ex:40-63`
  — `causal.required == true` demands status `admitted`, a known strategy
  (`rct|iv|backdoor|frontdoor|observational_assumptions`), and all evidence
  fields (`verifier, dag_proof_hash, assumptions_hash, placebo_result_hash,
  falsifier`).

### Path B — provider-pull (ZCode) path: the Ultracode lease seam

- `Xaas.Ultracode.EpochReactor` (`/Users/sac/xaas/lib/xaas/ultracode/epoch_reactor.ex`):
  Observe(:36) → Admit(:57) → Plan(:82) → Construct(:108) → Verify(:202) →
  Receipt(:255). The `:admit` step refuses any epoch not `:expected`/`:running`
  (:57-67) and performs NO authority-ceiling check — `AuthorityCeiling` is
  deliberately not modeled (:50-56; also `lib/xaas/ultracode.ex` moduledoc).
- `Xaas.Ultracode.Lease` (`/Users/sac/xaas/lib/xaas/ultracode/lease.ex`) — the
  admission court a ZCode worker actually faces:
  - `claim_next/3` (:61) — race-safe single filtered bulk UPDATE; lease token is
    the only capability (:19-20).
  - `admit_tool/2` (:151-159) — per-consequence admission: construction tools
    allowed; consequence tools `{:error, {:refused_no_authority, tool}}` (:155);
    unknown class `{:error, {:unknown_tool_class, tool}}` (:156).
  - `close/4` (:192) — head-verified against `git rev-parse HEAD` in the
    epoch's worktree; mismatch → `:build_broken`, unavailable verifier →
    `:partial_alive` (:274-287).
  - `refuse/3` (:220) — typed refusal seals a `:refused` Receipt.
- HTTP/MCP transport: `XaasWeb.ExecutionFabricController`
  (`/Users/sac/xaas/lib/xaas_web/controllers/execution_fabric_controller.ex`) —
  `POST /internal-api/execution/hooks/:event` (:104) and
  `POST /internal-api/execution/mcp` (:196) exposing
  claim_next/heartbeat/admit_tool/record_provider_event/close_candidate/refuse
  (:28-96). Already defaults `provider` to `"zcode"` (:117, :259).
- AshOban loop: `Xaas.Ultracode.Reactor` (`lib/xaas/ultracode/reactor.ex`) driven
  by the `:tick` scheduled action on `Xaas.Ultracode.Run`; provider-pull
  `:running` epochs go `:await_provider` and never auto-complete
  (`epoch_reactor.ex:88-94, 113-117`).

### What stands in for "operator authority" in code

- No Authority module exists: `lib/xaas/ultracode.ex` moduledoc — "this repo has
  no `Authority` module/system and none is invented here."
- Path A: authority = the `:authority` map passed as an opts key to
  `Xaas.Actuation.run/4` (`actuation.ex:26`, default `%{}`), persisted on the
  intent (`actuation_intent.ex:109-113`). Delegated actuation
  (`authorize?: false`) with an empty authority map is refused:
  `{:error, :delegated_actuation_requires_authority_evidence}`
  (`actuation.ex:325-329`). The map may carry `frontier_evidence` and/or
  `causal` certificates (fail-closed validations above).
- Path B: authority is NOT configurable — "the ceiling is a fence, not a
  configurable grant" (`lease.ex:26-27`). Hardcoded tool lists
  (`lease.ex:44-46`).
- Governance doc: `docs/ultracode/c4-architecture.md:243` —
  `No DO without AdmittedAuthority`; :249-257 — today overwhelmingly
  human-sourced, but the boundary "is a policy object, not a hardcoded 'ask
  Sean' branch — do not hand-code either extreme."

## 2. What a ZCode executor may/may not do without fresh operator authority

MAY (construction class, under a live lease token) — `lease.ex:44`:
`Edit, Write, Read, Grep, Glob, Task, TodoWrite, WebFetch`, plus fabric
operations claim_next / heartbeat / record_provider_event (observation only,
`lease.ex:166-180`) / close_candidate (head-verified) / refuse.

REFUSED (`REFUSED_NO_AUTHORITY` family) — `lease.ex:46`:
`Bash`, `git_push`, `publish` → `{:error, {:refused_no_authority, tool}}`
(:155). Unknown tool class → refused (`UNKNOWN != allowed`, :156). No/expired
lease → typed refusals (:243-261). So push / merge / publish / deploy / delete /
spend / external disclosure are unreachable from the bridge without a fresh
cut: the consequence classes would first need `AuthorityCeiling` modeled as a
real field + real check (`epoch_reactor.ex:50-56` explicitly demands this be
added, not implied).

c4-architecture.md:100-120: Observe/Plan/Solve have no DO authority; only
push, open PR, merge, publish, deploy, delete, spend, external disclosure cross
`Proposal → Admission → Authority → DO → Receipt`.

## 3. Bridge credentials (shape only)

xaas side:
- `/Users/sac/xaas/secrets/` filenames only: `.databaseurl`,
  `.grafanaadminpassword`, `.postgrespassword`, `.secretkeybase`,
  `secrets.enc.yaml`.
- Internal API gate: `INTERNAL_API_TOKEN` env var, constant-time compared
  Bearer token, fail-closed 503 when unset
  (`lib/xaas_web/plugs/require_internal_api_token.ex:21-33`).
- Other env names referenced in `config/runtime.exs`: `DATABASE_URL` (:38),
  `ONETIME_REVOKE_KEY` (:47), `SECRET_KEY_BASE` (:77), `POOL_SIZE`, `PHX_HOST`,
  `PORT`, `EX4PM_OCEL_INGEST_URL` (:163), `ECTO_IPV6`.

zcode side (/Users/sac/dev/zcode-cli, read-only):
- Provider/model auth env vars match
  `/^(ZCODE|ZAI|BIGMODEL|ZHIPU|ANTHROPIC)_.*(KEY|TOKEN|MODEL|CONFIG|PROVIDER|BASE_URL)/`
  (`src/prompt-preflight.ts:32`) — e.g. a `*_API_KEY` family; values never
  printed here.
- User config: `~/.zcode/cli/config.json` (`src/model-access.ts:54-62`) with
  `provider.<id>.options.apiKey` (:192); per-repo `zcode.json`,
  `.zcode/config.json`, `.env` also consulted (`src/prompt-preflight.ts:41-45`).
  OAuth via `zcode login` (zcode:// callback, `src/zai-oauth.ts`).
- The bridge bearer: `mix xaas.gen_zcode_plugin --token-env XAAS_INTERNAL_TOKEN`
  (default `XAAS_INTERNAL_TOKEN`, `lib/mix/tasks/xaas.gen_zcode_plugin.ex:49`);
  renders `.mcp.json` with `"Authorization": "Bearer ${XAAS_INTERNAL_TOKEN}"`
  (`priv/templates/zcode_plugin/.mcp.json.eex`) — token VALUE never enters the
  rendered tree or VCS (`xaas.gen_zcode_plugin.ex:33-34`).
- TWO distinct secrets must not be conflated: (a) the bridge bearer
  (`INTERNAL_API_TOKEN` on the server == the worker's `XAAS_INTERNAL_TOKEN`),
  and (b) zcode's own model-provider credential (`ZAI_*`-family /
  config.json apiKey).

## 4. Ledger requirements for a bridge implementation (xaas side)

Ledger format (`/Users/sac/xaas/HANDWRITTEN.md:6`):
`path | semantic element | missing capability | intended owner pack | date`.

Existing bridge-related rows (lines 11-21) — the bridge is ALREADY largely
ledgered:
- `lib/xaas/ultracode/lease.ex` | ActuationLease kernel | no admitted pack
  expresses a lease/claim/admit/close edge | ggen-marketplace
  ultracode-actuation-lease-pack | 2026-09-15
- `lib/xaas_web/controllers/execution_fabric_controller.ex` | MCP JSON-RPC +
  hook transport | no admitted pack renders a stateless MCP server inside
  Phoenix with internal-token gate | ggen-ecosystem-mcp-surface-pack family
  extension | 2026-09-15
- `priv/templates/zcode_plugin/**` | ZCode plugin projection templates |
  zcode-plugin-pack (admit after live qualification against ZCode 3.11.2) |
  2026-09-15
- `lib/mix/tasks/xaas.gen_zcode_plugin.ex` | plugin projection generator |
  zcode-plugin-pack | 2026-09-15
- `test/xaas/ultracode/lease_test.exs` | lease-edge qualification tests |
  ultracode-actuation-lease-pack gates/ | 2026-09-15

Any NEW hand-written bridge file needs its own row in that exact format.
Concretely: widening `admit_tool/2` with a configurable authority ceiling
(Path B) is a real semantic addition — its row would name the missing
capability "admitted authority-ceiling admission on the Ultracode seam"
(`epoch_reactor.ex:54-56` demands a real field + real check) and an intended
owner pack; growing the ledger requires a paydown plan in the same change
(HANDWRITTEN.md:24-33 paydown plan is the current one: qualify plugin live
against ZCode 3.11.2, then promote to packs, then delete repo-local copies).

## 5. Tripwire tests (admission/refusal)

- `/Users/sac/xaas/test/xaas/ultracode/lease_test.exs`
  - :86-92 consequence refusal: `{:error, {:refused_no_authority, "git_push"}}`
    and `"Bash"` — a bridge that smuggles Bash through would break this.
  - :94-98 unknown-class fence (`TimeMachine` refused).
  - :101-103 no lease, no admission.
  - :107-141 head verification (alive / build_broken on mismatch /
    partial_alive when unverifiable).
  - :143-150 refused receipt sealing (`refusal_reason` in evidence).
  - :155-167 await-provider (no auto-complete) + legacy semantics.
- `/Users/sac/xaas/test/xaas_web/execution_fabric_controller_test.exs`
  - :97-118 fail-closed token gate: unset `INTERNAL_API_TOKEN` → 503; wrong
    bearer → 401.
  - :131-136 pre_tool_use without lease = typed 403 deny.
  - :184 claim → admit → head-verified close loop; :222 natural-casing "ALIVE"
    not downgraded; :245 refuse receipt; :259 attacker-chosen refusal reason
    never crashes/atoms.
- `/Users/sac/xaas/test/xaas/causal_admission_test.exs` :43 (no admitted
  certificate → cannot reach DO), :67 (admitted persists), :98 (unsupported
  strategy refused before DO).
- `/Users/sac/xaas/test/xaas/actuation_test.exs` :48 (Reactor is the admitted
  DO path), :155 (idempotency conflict refused); authority-map shape in use:
  `%{kind: "test_authority", source: ...}` (:65, :88, :130, :142, :167, :178).
- `/Users/sac/xaas/test/xaas/frontier_evidence_test.exs`,
  `/Users/sac/xaas/test/xaas/ultracode/epoch_reactor_test.exs`.

## Key conclusion for the bridge

The ZCode executor connective tissue ALREADY EXISTS and is already
zcode-defaulted: lease kernel + execution fabric (MCP + hooks) + plugin
generator + templates, all ledgered 2026-09-15. The bridge's lawful surface is
exactly `claim_next → heartbeat → admit_tool(allow) → record_provider_event →
close_candidate(final_head) | refuse`. What the bridge may NOT do is invent an
authority path: consequence tools are a hardcoded fence; adding any
configurable ceiling requires modeling `AuthorityCeiling` as a real field +
check (`epoch_reactor.ex:50-56`) plus a fresh operator authority cut crossing
Path A's `Proposal → Admission → Authority → DO → Receipt`, with a new
HANDWRITTEN.md row per hand-written file.
