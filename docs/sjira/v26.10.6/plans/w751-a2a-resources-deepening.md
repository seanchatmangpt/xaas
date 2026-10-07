# W751 — A2A Resources Deepening (Lane Receipt)

- **Lane**: W751, campaign v26.10.6, repo `/Users/sac/xaas`
  (canonical checkout, branch `feat/playwright-surface`, HEAD `a0723bf6`).
- **Subject**: new file `test/xaas/a2a_resources_deepening_test.exs` + this receipt.
  No other files touched. Not committed (lane contract: coordinator owns commits).
- **Build isolation**: `MIX_BUILD_ROOT=_build-laneW751`, `MIX_ENV=test`,
  `PATH=$HOME/.asdf/shims:$PATH` (pinned toolchain elixir 1.20.2-otp-28).
- **Standing**: **ALIVE** for the asserted resource-level behavior on the exact
  subject above; 9/9 courts pass on the last run.

## Falsifier

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW751 \
  mix test test/xaas/a2a_resources_deepening_test.exs
```

Last real run (real tail):

```
.........
Finished in 1.7 seconds (0.00s async, 1.7s sync)

Result: 9 passed
```

## Courts (what is now pinned, all real Ash actions on the real ETS store, no mocks)

- **(a) Agent -> Task binding + REAL status surface**
  - a1: Agent create -> Task create bound to the agent; row read back via fresh
    query (real store state, not the return value).
  - a2: status membership IS enforced — `:cancelled` refused with
    `%Ash.Error.Invalid{}` via the `one_of` constraint.
  - a3: honest absence of a transition machine — `submitted -> working ->
    input_required -> working -> completed` AND the illegal `completed ->
    submitted` are both ACCEPTED via `:update`; artifacts ride `:update`.
    (W715 pattern: assert the actual machine or its absence.)
  - a4: `unique_task_id` identity enforced (`Ash.Error.Invalid` on duplicate).
- **(b) Cross-resource integrity — the real behavior, asserted not assumed**
  - b1: a Task bound to a nonexistent Agent ("ghost-agent") is **ACCEPTED**
    (no FK/relationship); row persists; `Catalog.tasks_for_agent/1` serves it.
  - b2: destroying the parent agent leaves the child task dangling by design;
    parent read answers `{:error, %Ash.Error.Invalid{errors:
    [%Ash.Error.Query.NotFound{}]}}`; orphan task still served by catalog.
- **(c) Agent-card consistency vs `GET /a2a/v1/.well-known/agent-card.json`**
  - c1: the real served card (through the real endpoint + bearer token) passes
    W699's pinned-field pre-checks, ingests via `Catalog.ingest/1`, and
    projects name/version/description/skills byte-consistent; the
    `supportedInterfaces -> transport_bindings` mapping is asserted field-by-field
    (url/protocolBinding/protocolVersion).
  - c2: the resource attribute surface honestly carries exactly the W699-shared
    members (name/url/description/version/skills/transport_bindings) and does
    NOT carry the wire-only members (`capabilities`, `defaultInputModes`,
    `defaultOutputModes`) — asserted via `Ash.Resource.Info.attributes/1`.
  - Cross-check via `Catalog` upsert-on-name also exercised in c1 (identity).
- **(d) Determinism**: same card + task sequence replayed from a wiped store
  lands in an identical projected state (all stable fields equal; fresh UUID PK
  per replay — asserted `refute first.id == second.id`).

## Typed gaps (UNSUPPORTED / disclosed)

- **UNSUPPORTED (transition-machine)**: `Xaas.A2a.Task` has NO status
  transition machine — any in-set status -> any in-set status is accepted by
  `:update` (including terminal -> non-terminal). Pinned as honest absence
  (a3), not repaired by this lane (resources were undocketed for deepening,
  not for behavior change).
- **UNSUPPORTED (referential integrity)**: `agent_id` is a plain string with
  no relationship/FK to `Xaas.A2a.Agent` — dangling references are accepted
  and survive parent destroy (b1/b2). Pinned as real behavior; not repaired.
- **Wire-only card members** (`capabilities`, `defaultInputModes`,
  `defaultOutputModes`) are not projected onto the resource surface (c2
  pins the omission honestly).
- **c1 note**: pre-existing `XaasWeb.A2A.V1ProtocolTest`-style wire court
  already pins the card's wire shape; c1 is a projection-consistency court,
  not a wire-shape court.

## Notes for the coordinator

- `MIX_BUILD_ROOT=_build-laneW751` could NOT be deleted at lane end
  (`rm -rf` denied by the permission system). Per the lane contract it is
  left for the coordinator to delete before integration commit (fanout
  cleanup law).
- Real warnings during the run are pre-existing (PromEx/Grafana nxdomain,
  AshA2A legacy_compat memory-store profile) — not session-introduced.
- The W699 wire court file (`test/xaas_web/a2a_v1_wire_deepening_test.exs`)
  is excluded from this run by the campaign's `:eu_ai_act` tag exclusion;
  c1 re-derives only the card fields it needs on the wire before ingest.
