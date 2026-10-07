# W640 — Differential SHACL admission court (W639 design, C14 falsifier)

Lane W640, v26.10.7 fleet seal. Date: 2026-10-07. Repo: `/Users/sac/xaas`, branch
`feat/playwright-surface`. NOT committed (lane contract); artifact is
`test/xaas/semantics/w640_differential_shacl_test.exs` in the working tree.

## Standing

**ALIVE (differential-admission, ×2 fresh roots)**: on the repaired shapes
surface, host `violations/1` and guest `op:"shacl"` AGREE on conforms-boolean
AND violated focus-node sets across the 4 semantic corpus cases; the raw
profile bytes are refused TYPED by the guest, witnessed as case C0. 5/5 ×2.

## Subject

- New: `test/xaas/semantics/w640_differential_shacl_test.exs` (5 cases, 232 lines).
- Read-only consumption of: `lib/mix/tasks/xaas.airo.compile_shacl.ex`
  (`violations/1`), `lib/xaas/semantics/graphlaw_wasm.ex` (verify_digest/2,
  digest/1), `priv/graphlaw.wasm` + `priv/graphlaw.wasm.sha256`
  (W637 artifact, sha256 `b7664a5ed21c254da1ba1a2cf497e6de23406ce935a8c6ce8a9ea8cc7ae43121`),
  `priv/airo_risk_description.ttl` (W982m instance graph), `priv/airo/profile.shacl.ttl`
  (W615 profile).
- Dependencies: W637 receipt (present at lane start), W638 receipt (landed
  mid-lane at 14:41; waited/polled per coordination clause; module was in
  flight and changed twice during the lane — zero-import judge → wasi-allowlist
  judge — and the court tracked the disk state).

## Agreement matrix (real output, ×2 fresh roots, identical both runs)

| Case | Mutation | Host (`violations/1`) | Guest (`op:"shacl"`) | Agreement |
|---|---|---|---|---|
| C0 profile-bytes | raw W615 profile as shapes | (n/a — generator surface) | `ok:false, EngineRejected, Turtle, "iri-disallowed-char"` (typed) | TYPED REFUSED witnessed |
| C1 conforming | none (W982m graph) | `[]` | `conforms:true, results:[]` | AGREE |
| C2 control-unbound | drop kernel mitigates line | exactly `{ActuationKernel: control_binds_risk_concept}` | `conforms:false`, foci `{ActuationKernel}` (`OrConstraintComponent` on shape `airo-shape-RiskControl`) | AGREE |
| C3 risk-uncited | uncite UnreceiptedActuationRisk (all 3 binding citations) | exactly `{ActuationKernel: control_binds…, UnreceiptedActuationRisk: risk_cited_by_control}` | `conforms:false`, foci identical | AGREE |
| C4 hazard-uncited | C3 + drop FreezeWindowGate's Hazard bindings | `{ActuationKernel, UnreceiptedActuationRisk, FreezeWindowGate}`; FreezeWindowViolation (Hazard) NOT flagged | `conforms:false`, foci identical; FreezeWindowViolation not flagged | AGREE (negative-differential: both scope to airo:Risk only) |

Guest results carried `component=sh:OrConstraintComponent`, `severity=Violation`,
`shape=<…#shapes-…-shape-RiskControl>` — the profile's compiled constraints fired
as designed.

## Court findings (cross-lane)

- **Finding (a) — RESOLVED mid-lane**: the initial on-disk `GraphlawWasm`
  (zero-import judge) refused the real wasip1 artifact
  (`:import_surface_mismatch`). W638's landed version has a hard WASI
  allowlist judge + derived stubs; that version admits the artifact.
- **Finding (b) — OPEN, generator defect**: `priv/airo/profile.shacl.ttl` is
  not strict-Turtle: the `airo-sh:` prefix IRI `https://w3id.org/airo#shapes#`
  carries a second `#` (illegal inside an IRI). RDF.ex tolerates
  it; the graphlaw/purrdf guest refuses it typed
  (`EngineRejected/Turtle/iri-disallowed-char`). The W615 generator
  (`priv/airo/profile.shacl.ttl` emitter) must fix the namespace (`airo#shapes-`
  suffices — the court's repaired surface uses exactly that one-string
  replacement and the whole agreement matrix passes on it). Until fixed,
  the profile bytes cannot serve as the guest shapes argument.
- **Finding (c) — OPEN, host defect**: `GraphlawWasm` instantiates with
  zero-value WASI stubs; real `op:"shacl"` workloads TRAP
  (`:call_trapped`, wasm backtrace). Root cause hypothesis (unverified):
  zero-value `random_get` starves the guest's RNG → Rust panic (panic=abort)
  → trap. The court therefore executes on a REAL WASI store
  (`Wasmex.Store.new_wasi/1`, native wasmex WASI implementation) while
  keeping artifact identity pinned via `GraphlawWasm.verify_digest/2` to the
  W637 digest; export surface re-judged per boot. W638's ALIVE standing is
  hereby scoped: its witnessed surface (capabilities round trip) does not
  include real SHACL workload execution.

## Method / μ

- Command (both runs):
  `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW640 mix test test/xaas/semantics/w640_differential_shacl_test.exs`
  → `Result: 5 passed` ×2 (9.5s). Excludes: repo-standard tags.
- One canonical checkout, no worktrees; lane build root `_build-laneW640`.
- Generated-vs-handwritten: the court is handwritten (irreducible residue:
  differential assertion over two checker identities); checkers themselves
  are pre-existing capital (W615 host court; W637/W638 artifact+host).

## Transport failures (recorded, then repaired forward)

1. My first corpus surgery used `@attr` with value on the next line (parsed
   as attribute READ → nil pattern). Fixed: same-line values.
2. `Wasmex.call_function/4` takes the timeout positionally (not an opts list).
3. `Wasmex.Module.exports/1` returns the map directly (not `{:ok, map}`).
4. `Wasmex.Memory.read_binary/4` returns the binary directly.
5. FreezeWindowViolation is `airo:Hazard`, not `airo:Risk` — first C3 design
   ("controls stay bound") is impossible: unciting a Risk removes every
   binding to it, so the minimal uncite fires BOTH constraint classes. The
   landed C3 asserts exactly that.

## Falsifier status

W639's falsifier ("a conforming instance admitted by `violations/1` but
rejected by `op:"shacl"` — or vice versa — kills the design") did NOT fire on
the repaired surface; it FIRED in the transport sense on the raw profile
bytes (C0, finding b). Constraint 3 (file citations) stays host-side per the
design — not attempted guest-side.

## Boundary / next

- Finding (b) blocks "profile bytes as-is" guest admission; a one-string
  generator fix (`airo#shapes-`) is identified but belongs to the W615
  surface owner (not edited this lane).
- Finding (c) blocks real-workload execution through the host transport
  itself; fix direction: real WASI store (`new_wasi`) or a real
  `random_get` stub, then re-run this court against `GraphlawWasm.invoke`
  directly.
- Hand-rolled `violations/1` remains the host side of the differential; the
  differential does not establish SHACL conformance of the profile beyond
  the corpus.
- `_build-laneW640` left in place for the coordinator: lane `rm -rf` of the
  build root was denied by the session permission system (disclosed).
