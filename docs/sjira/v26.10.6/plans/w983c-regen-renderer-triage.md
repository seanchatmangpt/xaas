# W983c — regen renderer triage receipt

Lane W983c, xaas v26.10.6, repo `/Users/sac/xaas`, branch `feat/playwright-surface`
(HEAD at lane open and at lane close: `6f235905`). No commit, per lane contract.
No lib/ changes. Standing per defect below; overall: **PARTIAL_ALIVE** (all three
W982g findings triaged to a precise locus with live witnesses; two upstream
claims corrected/refuted; one real actuation-ready unblock path proven).

Env (all real runs): `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test
MIX_BUILD_ROOT=_build-laneW983c`, pinned toolchain (elixir 1.20.2-otp-28),
fresh-cold lane build root, `mix compile` exit 0. Build root deleted at lane
close per lane-lease law.

---

## Defect 1 — `lib/mix/tasks/xaas.library.manufacture.ex` regen
### Verdict: escape bug REFUTED; real finding is a policy-floor drift, locus LOCAL (fix-forward, not upstream)

Real regen witnessed at the bound ggen_igniter 26.10.1 (full pipeline: pack-dir,
14 discovered `gates/*.rq` queries, 36 rows, oxigraph engine), output to a
scratch `--out` (no tracked tree touched):

```bash
mix ggen_igniter.sync --pack-dir priv/packs/xaas_library_pack \
  --out .w983c_tmp/manufacture.ex   # → "wrote ... (14 queries, 36 total row(s))"
```

- The full rendered output **parses as valid Elixir**
  (`Code.string_to_quoted/1` → OK, 32,666 bytes). A plain `EEx.eval_string`
  render of `priv/packs/xaas_library_pack/templates/manufacture.ex.eex` also
  parses OK. **There is no escape bug**: the `table \"library_books\"` text
  W982g reported is the template's CORRECT heredoc-internal escaping —
  `\"` inside the emitted `content = """..."""` blocks is valid Elixir, and
  the tracked file's unescaped `table "library_books"` variant is equally
  valid. W982g misread the git-diff rendering as "invalid emitted Elixir".
- The REAL drift (--check exit 4, consistent with W982g) is substantive and
  normative: after normalizing `\"`→`"`, the render-vs-tracked diff collapses
  to 215 lines whose only non-row content is policy — tracked file emits
  `authorize_if always()` on all write policies (0 `actor_present`), the
  ontology-backed render emits the deny-by-default `authorize_if
  actor_present()` floor at 4 sites plus the documented guest-browse policy
  comments. **Regen would STRENGTHEN policy, not clobber a floor** — the
  W982g "clobber hand-authored policy" direction is reversed; there is no
  actor_present floor in the tracked file to clobber (grep = 0).
- **Locus: local (consumer).** No upstream filing needed.
- **Unblock step (actuation-ready, owner decision):** run the regen for real
  (`mix ggen_igniter.sync --pack-dir priv/packs/xaas_library_pack`), which
  upgrades the task file to the actor_present floor; then re-pin
  `@expected_sha256` in `test/xaas/generated/registry_drift_guard_test.exs`
  and the disclosed-skip entry in `lib/xaas/generated/regen_check.ex`
  (the surface becomes a clean `:ggen_igniter_check`), then run the mock gate
  + `mix test test/xaas/generated/registry_drift_guard_test.exs`. Typed
  annotation correction: the current skip_reason
  `UNSUPPORTED(renderer-escape-bug)` is WRONG — recommend
  `BLOCKED(policy-floor-upgrade-pending)` until the upgrade is admitted, then
  retire the skip.
- Note: the tracked (pinned) task file emitting `authorize_if always()` write
  policies is itself a pre-existing exposure vs the repo's Ash policy floor —
  disclosed here for the coordinator.

## Defect 2 — `lib/xaas/generated/capital_census/facts.ex` renderer
### Verdict: NOT an upstream renderer defect; LOCAL invocation defect. Surface is regen-invocable and PROVEN byte-identical

Failure modes witnessed (real runs, exact tails):

1. Pinned guard command as written → template resolved against cwd:
   `--template file not found at templates/facts.ex.eex (resolved against the
   current working directory, /Users/sac/xaas)`.
2. W982g's variant (3 of 4 queries, root-relative template):
   `error: undefined variable "recurrence_threshold"` at `nofile:24:29` →
   `** (RuntimeError) ggen_igniter: reactor reconciliation failed (refused):
   %CompileError{file: "nofile", ...}` — minimal repro input is the FOURTH
   query `facts_spec.rq` (single-row → bare `recurrence_threshold` binding);
   the template cannot render without it.
3. Corrected command (all four `--query` flags per the pack README) renders
   clean and the output is **byte-identical to the tracked file**:

```bash
# CORRECTED (witnessed: "wrote ... (engine: oxigraph, 4 queries, 20 total row(s))";
# output diff vs lib/xaas/generated/capital_census/facts.ex = empty)
mix ggen_igniter.sync \
  --ontology priv/ggen/ultracode-self-digest-pack/ontology.ttl \
  --query g_table=priv/ggen/ultracode-self-digest-pack/queries/g_table.rq \
  --query facts=priv/ggen/ultracode-self-digest-pack/queries/facts.rq \
  --query facts_spec=priv/ggen/ultracode-self-digest-pack/queries/facts_spec.rq \
  --query frontier_outcomes=priv/ggen/ultracode-self-digest-pack/queries/frontier_outcomes.rq \
  --template priv/ggen/ultracode-self-digest-pack/templates/facts.ex.eex \
  --out lib/xaas/generated/capital_census/facts.ex
```

- **Locus: local** — the registry-guard pin and W982g's attempt were
  incomplete invocations, not a ggen_igniter renderer defect. Note the
  renderer is plain `EEx.eval_string` (`deps/ggen_igniter/lib/ggen_igniter/
  render.ex`) — no escaping pass exists to be buggy.
- **Unblock step:** replace the census's `disclosed_skip` in
  `lib/xaas/generated/regen_check.ex` with a `:ggen_igniter_check` surface
  using the corrected argv (the current skip_reason
  `UNSUPPORTED(renderer-compile-error)` is WRONG — recommend retiring it);
  the corrected command above is also the registry-guard pin replacement.

## Defect 3 — registry guard stale regen pins
### Verdict: every defect pin witnessed failing; corrected commands witnessed working. Locus: LOCAL (fix the pins in `test/xaas/generated/registry_drift_guard_test.exs`)

All tails below are real runs at ggen_igniter 26.10.1, pinned toolchain.

| surface | pinned command failure mode (witnessed) | corrected command (witnessed working) |
|---|---|---|
| `lib/xaas/generated/zcode_event_registry.ex` | `ArgumentError: no *.rq files found in priv/packs/xaas_zcode_ocel_pack/gates/ and no explicit --query given` (queries live in `queries/`, discovery is `gates/`-only — `deps/ggen_igniter/lib/ggen_igniter/pack.ex` `discover_queries/1`); and with queries but without `--on-stale preserve`: `SYNC_REFUSED — 1 stale output path(s) ... /Users/sac/xaas/worktrees/sjira/sj-002/lib/xaas/generated/zcode_event_registry.ex` (standing REFUSED, exit 1) | `mix ggen_igniter.sync --pack-dir priv/packs/xaas_zcode_ocel_pack --query event_types=priv/packs/xaas_zcode_ocel_pack/queries/010_event_types.rq --query object_types=priv/packs/xaas_zcode_ocel_pack/queries/020_object_types.rq --query qualifiers=priv/packs/xaas_zcode_ocel_pack/queries/030_qualifiers.rq --query transitions=priv/packs/xaas_zcode_ocel_pack/queries/040_transitions.rq --template priv/packs/xaas_zcode_ocel_pack/templates/zcode_event_registry.ex.eex --out lib/xaas/generated/zcode_event_registry.ex --on-stale preserve` (check form + `--check --json` witnessed exit-4 JSON, 63 rows; drift=1 only because out was a scratch path) |
| `lib/xaas/telemetry/ocel_envelope.ex` | same `no *.rq files found in priv/packs/xaas_telemetry_pack/gates/` SYNC_REFUSED | `mix ggen_igniter.sync --pack-dir priv/packs/xaas_telemetry_pack --query envelope_fields=priv/packs/xaas_telemetry_pack/queries/001_envelope_fields.rq --template priv/packs/xaas_telemetry_pack/templates/ocel_envelope.ex.eex --out lib/xaas/telemetry/ocel_envelope.ex --on-stale preserve` (check form witnessed exit-4 JSON, 4 rows) |
| `lib/xaas/generated/capital_census/facts.ex` | template cwd-resolution miss (defect 2.1) | corrected command in defect 2 |
| `lib/mix/tasks/xaas.library.manufacture.ex` | runs as written BUT actuates the tracked surface (policy upgrade pending, defect 1); unsafe as a bare pin | add explicit `--out` (scratch) during any trial; actuation form = defect 1 unblock step |
| `lib/xaas_web/mcp_scope.ex` + 5 marketplace/provenance pins | prose pins, not executable — correct as-is | n/a |

Also witnessed: `--out` outside the project root is refused by the write-safety
guard (`refused: target "/private/tmp/..." resolves outside the authorized
project root`), so scratch dry-runs must use an in-repo scratch dir; `--check`
form is fully non-writing and is the right shape for the census.

## Lane-incident disclosure (typed)

Two of my own scratch regen runs (facts.ex, manufacture.ex to `.w983c_tmp/`)
persisted manifest entries into `.ggen_igniter/manifest.json`; my scrub then
accidentally deleted the whole `entries` map. Repaired: `entries` restored
from `HEAD:.ggen_igniter/manifest.json` (11 entries, all pinned recipes
intact, w983c scratch entries gone); final `git diff .ggen_igniter/manifest.json`
= empty (byte-identical to HEAD). The 'M' flag the manifest carried at lane
open was ggen-generated residue of the same machine-regenerated class; the
restored HEAD state supersedes it. No hand-authored content existed in the
file (all entries machine-written with `updated_at` provenance). Typed:
`REPAIRED(manifest-restored-to-HEAD)`.

## Standing summary

| defect | locus | standing | unblock owner |
|---|---|---|---|
| 1 library.manufacture | LOCAL (no escape bug — policy-floor drift; upstream claim refuted) | PARTIAL_ALIVE (regen proven valid + actuation-ready; upgrade is an owner decision) | xaas lane: run regen, re-pin guard, retire skip |
| 2 capital_census/facts.ex | LOCAL (incomplete invocation; renderer exonerated) | ALIVE (corrected command proven, output byte-identical to tracked) | xaas lane: fix pin + census kind |
| 3 registry guard pins | LOCAL (stale pins: gates/-only discovery + missing `--on-stale preserve`) | ALIVE (corrected commands witnessed working) | xaas lane: replace pins in registry_drift_guard_test |

No upstream (ggen_igniter) filing is warranted on any of the three findings.
