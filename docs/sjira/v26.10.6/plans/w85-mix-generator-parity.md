# W85: Mix-Generator Parity — v26.10.6 (Closure Plan Inventory #16 + #17)

Subject: `/Users/sac/xaas` @ `d1db2b03` (feat/playwright-surface), working tree (each generated target verified byte-identical to HEAD before the runs). Date: 2026-10-06. Toolchain: asdf elixir 1.20.2-otp-28 (`PATH=$HOME/.asdf/shims:$PATH`), ggen_igniter 26.10.1 (hex, from xaas deps), engine oxigraph.

Method: every generator was run into an in-repo scratch target (`.w85_scratch/`), sha256-compared against the tracked file, and the scratch was deleted afterwards. In-place regeneration was NOT performed: the three sa2a surfaces re-render with current formatter line-wrapping, so bytes would change — under the lane rule (in-place only if byte-identical) no tracked output was touched. Zero source edits, no git state changes. Lane residue: none (scratch removed, verified).

## Per-generator results

| # | generated target (tracked) | generator (located) | drift | evidence |
|---|---|---|---|---|
| 1 | `priv/ontop/xaas-mapping.generated.ttl` | NOT LOCATED — **permanent-UNKNOWN** | UNKNOWN | Search evidence in section below. |
| 2 | `lib/xaas/generated/zcode_event_registry.ex` | `mix ggen_igniter.sync`, pack `priv/packs/xaas_zcode_ocel_pack` | **NO** (byte-identical) | exit 0: `wrote .w85_scratch/zcode_event_registry.ex (engine: oxigraph, 4 queries, 63 total row(s)) (via reactor)`; scratch sha256 `d185723654af3eca4c8f710752ce78f5e4ce4f123b34041bdc4448993ddef861` == tracked. |
| 3 | `lib/xaas/generated/sa2a_bridge_contract.ex` | `mix ggen_igniter.sync` against `~/ggen-marketplace/packs/sa2a-bridge-pack` | **YES — formatting-only** | sha256 tracked `a3ee8136…` vs fresh `cfb96225…`; 6 changed lines, all line-wrapping of two long `@identity` strings; whitespace-stripped comparison: identical. |
| 4 | `lib/xaas/generated/sa2a_bridge_edges.ex` | same pack | **YES — formatting-only** | tracked `821faf64…` vs fresh `a74c2223…`; 5 long map lines re-wrapped; both copies identical after one common `mix format` pass. Tracked file lacks trailing newline. |
| 5 | `lib/xaas/generated/sa2a_mcp_descriptor.ex` | same pack | **YES — formatting-only** | tracked `dda0d8d0…` vs fresh `9760b12f…`; identical after common `mix format`. |

## Authoritative commands (all observed exit 0 this session)

The zcode pack's header command is INCOMPLETE: `mix ggen_igniter.sync --pack-dir` auto-discovers queries only from `gates/*.rq`, but this pack stores queries under `queries/` — without explicit `--query` flags the task refuses (`no *.rq files found in priv/packs/xaas_zcode_ocel_pack/gates/ and no explicit --query given`). Header defect, recorded here.

```bash
export PATH=$HOME/.asdf/shims:$PATH   # pinned toolchain; homebrew elixir shadows asdf

# (2) zcode_event_registry.ex — NO DRIFT
MIX_ENV=test mix ggen_igniter.sync \
  --pack-dir priv/packs/xaas_zcode_ocel_pack \
  --query object_types=priv/packs/xaas_zcode_ocel_pack/queries/020_object_types.rq \
  --query event_types=priv/packs/xaas_zcode_ocel_pack/queries/010_event_types.rq \
  --query qualifiers=priv/packs/xaas_zcode_ocel_pack/queries/030_qualifiers.rq \
  --query transitions=priv/packs/xaas_zcode_ocel_pack/queries/040_transitions.rq \
  --template priv/packs/xaas_zcode_ocel_pack/templates/zcode_event_registry.ex.eex \
  --out .w85_scratch/zcode_event_registry.ex \
  --manifest-dir .w85_scratch \
  --verify-cwd /tmp/w85/verify_proj \
  --yes

# (3)(4)(5) sa2a bridge surfaces — formatting-only drift
PK=$HOME/ggen-marketplace/packs/sa2a-bridge-pack
MIX_ENV=test mix ggen_igniter.sync \
  --ontology $PK/ontology.ttl \
  --query spec=$PK/ggen_igniter/queries/contract.rq \
  --template $PK/ggen_igniter/templates/sa2a_bridge_contract.ex.eex \
  --out .w85_scratch/sa2a_bridge_contract.ex \
  --manifest-dir .w85_scratch --verify-cwd /tmp/w85/verify_proj --yes

MIX_ENV=test mix ggen_igniter.sync \
  --ontology $PK/ontology.ttl \
  --query edges=$PK/ggen_igniter/queries/edges.rq \
  --template $PK/ggen_igniter/templates/sa2a_bridge_edges.ex.eex \
  --out .w85_scratch/sa2a_bridge_edges.ex \
  --manifest-dir .w85_scratch --verify-cwd /tmp/w85/verify_proj --yes

MIX_ENV=test mix ggen_igniter.sync \
  --ontology $PK/ontology.ttl \
  --query capabilities=$PK/ggen_igniter/queries/mcp_descriptor.rq \
  --template $PK/ggen_igniter/templates/sa2a_mcp_descriptor.ex.eex \
  --out .w85_scratch/sa2a_mcp_descriptor.ex \
  --manifest-dir .w85_scratch --verify-cwd /tmp/w85/verify_proj --yes
```

Environment notes for replay:
- The task's Reactor terminal `:verify` step runs `mix compile --warnings-as-errors` against the real project, which fails on this tree's pre-existing warnings regardless of drift; `--verify-cwd /tmp/w85/verify_proj` (a throwaway `mix new` project, documented escape hatch in the task's own `mix help ggen_igniter.sync`) was used so verification runs against a clean subject. Render output is unaffected.
- Out-of-root `--out` is refused by the task ("resolves outside the authorized project root"), hence the in-repo `.w85_scratch/` (now deleted).

## #1 — `priv/ontop/xaas-mapping.generated.ttl`: permanent-UNKNOWN

Search evidence (all observed zero hits this session):

- No provenance header in the file itself (starts directly with `@prefix rr:`), unlike every other generated surface in this repo.
- `grep -rn "xaas-mapping.generated"` over `/Users/sac/xaas/lib`, `/Users/sac/xaas/scripts`, `/Users/sac/xaas/config`, `/Users/sac/xaas/.github`, `/Users/sac/xaas/priv`, `/Users/sac/xaas/test`, `mix.exs`: no writer. The only repo references are the closure-plan documents themselves (`docs/sjira/v26.10.6/_CLOSURE_PLAN.md`, `plans/vector4-gen-parity.md`) — both say "generator not located".
- Introducing commit `28936f48` (2026-09-08, "manufacture Next Read recommendation engine … via ggen_igniter") added the file (675 lines, 64 `rr:TriplesMap` blocks vs 17 in hand-written `xaas-mapping.ttl`); the only mix task added in that commit, `lib/mix/tasks/xaas.library.manufacture.ex` (checked both at HEAD and at that commit), writes only Library domain files — not the mapping.
- `~/ash_r2rml` checkout (dep of xaas): mix tasks `install`, `types`, `types.diff`, `gen.semantic_types`, `generate_docs`, `test_livebooks` — none writes an R2RML mapping; no reference to the target path anywhere in that repo.
- `~/ggen`, `~/ggen_igniter`, `~/ggen-marketplace` checkouts: zero references to `xaas-mapping.generated`.
- The only test touching the mapping pair reads `priv/ontop/xaas-mapping.ttl` (the hand-written file), not the generated one (`test/xaas/semantics/registry_test.exs:67`).
- No CI lane or script regenerates or gates it.

Verdict: no executable generator exists on this machine for `priv/ontop/xaas-mapping.generated.ttl`; drift cannot be measured. Permanent-UNKNOWN (matches the prior lane's verdict in `vector4-gen-parity.md`; this lane adds the deeper ash_r2rml/ggen_igniter/ggen-marketplace sweeps as new negative evidence).

## Consequences / follow-ups

1. **zcode_event_registry.ex**: parity ALIVE, byte-identical. But the file header's regenerate command is wrong (missing required `--query` flags) — a follow-up header fix is warranted (out of W85 scope: no source edits).
2. **sa2a trio**: content is in parity but bytes are not; regenerating in place would produce a formatter-churn diff. Follow-up: one in-place regen commit (or pin a formatter/line-length in the template) to make the surfaces byte-reproducible; until then no CI drift gate can be added for them without a normalization step (e.g. `mix format` both sides before diffing).
3. **xaas-mapping.generated.ttl**: remains an ungated orphan projection with no locatable generator; either locate the tool that manufactured it on 2026-09-08 or delete/adopt it explicitly.
4. Prior lane receipt `vector4-gen-parity.md` rows for these surfaces upgrade: zcode NOT VERIFIED → NO drift; sa2a trio NOT VERIFIED → content-parity confirmed, byte-drift formatting-only.
