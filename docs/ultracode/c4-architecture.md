# Chatman Ultracode — C4 Architecture (Bootstrap vs. Target)

**Version:** v26.9.15
**Date:** 2026-09-14
**Standing:** DESIGN — L1-L3 admitted, L4 = UNKNOWN (deliberately not yet invented)

This is the binding decomposition for Chatman Ultracode inside `xaas`. It exists to
prevent two recurring mistakes already caught and corrected earlier in this design
pass: (1) treating Ultracode as a new standalone daemon/infrastructure project
instead of an XaaS product profile, and (2) conflating the bootstrap tooling used to
build Ultracode (Claude Code, cloud routines) with Ultracode's own target
architecture. This doc encodes the correction so future cycles don't re-derive it.

## The central falsifier

$$
Remove(ClaudeCode) \Rightarrow Behavior(Ultracode) = Unchanged
$$

Claude Code — including the hourly cloud routine currently building this out — is
**bootstrap/migration infrastructure**, never part of the target System Context.
The acceptance test for "Ultracode is ALIVE" is exactly:

$$
\boxed{ClaudeRoutine \rightarrow XaaS.Ultracode.Run}
$$

When the current hourly Claude routine can be deleted and the identical engineering
loop continues from durable XaaS state (AshOban ticking `XaaS.Ultracode.Run`,
Reactor running the EpochReactor DAG, receipts landing in the Evidence Plane), the
scheduling/continuity portion of Ultracode has crossed from DESIGN to ALIVE. Before
that point, missed-epoch detection is bootstrap safety (protect
$T_{now} < T < T_{UltracodeAlive}$); after that point it is an ordinary domain
invariant (`ExpectedEpoch ∧ ¬CompletedEpoch ⇒ MissedEpoch`), owned and scheduled by
AshOban like everything else.

## Level 1 — System Context (target state)

```text
Sean
  │  Goal / Norm / Authority
  ▼
XaaS
  └── Chatman Ultracode product profile
        │
        ├── supplier capabilities
        │     ├── ash_a2a
        │     ├── ash_r2rml
        │     ├── ggen_igniter
        │     ├── ggen-marketplace
        │     └── beam4pm
        │
        └── external delivery / reasoning systems
              ├── GitHub
              └── ZAI
```

Claude Code is not in this diagram. It is `MigrationInfrastructure`, not
`UltracodeArchitecture`.

## Level 2 — Containers (target state)

One release, eight planes — composition, not a second daemon:

```text
XaaS BEAM Release
│
├── Semantic Plane        — Ash resources, ash_r2rml projections, ProjectProfile
├── Temporal Plane        — AshOban, Oban
├── Orchestration Plane   — Reactor
├── Continuity Plane      — OTP, DurableServer, AshStateMachine
├── Intelligence Plane    — ZAI adapter, HDDL/FOND, solver interfaces
├── Manufacture Plane     — ggen, ggen_igniter
├── Governance Plane      — BRCE, CommandBus, Authority broker, Admission/refusal
├── Evidence Plane        — Receipt store, OCEL, Machine Experience
└── Delivery Plane        — Git broker, PR/package projection, release candidate
```

$$
\boxed{Ultracode\ is\ composition,\ not\ another\ container}
$$

## Level 3 — Components (component chain + tightened consequence path)

```text
Run → Epoch → AshOban → EpochReactor
```

EpochReactor steps:

```text
OBSERVE → ADMIT → PLAN → CONSTRUCT → VERIFY → CHICAGO → RECEIPT → LEARN
```

**Correction applied here:** not every step crosses `CommandBus.run/4`. Only
consequence-bearing operations cross the BRCE/CommandBus fence — CommandBus is a
governance boundary, not a generic function-call bus.

```text
Observe   → no DO authority
Plan      → no DO authority
Solve     → no DO authority
Generate  → CONSTRUCT
Verify    → OBSERVE
Package   → CONSTRUCT
```

while these must cross `Proposal → Admission → Authority → DO → Receipt`:

```text
push
open PR
merge
publish
deploy
delete
spend
external disclosure
```

This preserves `SELECT ≠ CONSTRUCT ≠ DO` as a real structural boundary rather than
letting CommandBus become a pass-through for every step.

## Level 4 — deliberately UNKNOWN

$$
L4 = UNKNOWN
$$

No module names are imposed manually. The next implementation work earns L4 by
producing modules like `XaaS.Ultracode.{Run,Epoch,ProjectProfile,Receipt,
Experience,EpochReactor,Scheduler,Provider.ZAI,GitBroker,Authority}` — but those
names must emerge from this repo's existing namespaces and generated architecture,
not be typed in by hand ahead of the ontology. The lawful sequence is:

$$
C4_{L1-L3} \rightarrow Ontology \rightarrow XaaS\ ProductProfile \rightarrow ggen \rightarrow Code \rightarrow C4_{L4}
$$

never:

$$
C4_{L1-L3} \rightarrow HumanWritesModules
$$

## What this changes for the standing hourly routine

The hourly Ultracode routine (`trig_01X4MaMBcr9DuFhVVZjJuLbQ`) is itself an instance
of `MigrationInfrastructure` per this doc's own falsifier. Its job across cycles is
to build toward the point where it can delete itself — i.e. drive toward
`ClaudeRoutine → XaaS.Ultracode.Run` — not to become a permanent operational
component. Each cycle should prefer work that shortens the distance to that
milestone (real AshOban scheduled action wiring a real `Run`/`Epoch` tick; a real
multi-step EpochReactor; the tightened consequence-path classification above) over
decorative scaffolding.

## 2040 target state — where this trajectory terminates

This section is the long-horizon terminus this repo's near-term work should be
read against. It does not change any near-term acceptance criteria above; it
changes what "shortens the distance to the milestone" *means* when a cycle has a
choice between two otherwise-equal gaps.

$$
\boxed{XaaS_{2040} = O^* + \mu + \Pi + \mathcal{A} + R + MX}
$$

where $O^*$ = admitted semantic enterprise state, $\mu$ = lawful manufacture,
$\Pi$ = planning/constraint machinery, $\mathcal{A}$ = authority calculus, $R$ =
receipts/provenance/replay, $MX$ = accumulated Machine Experience. Supplier
identity is explicitly excluded from the core ontology:

$$
SupplierIdentity \notin CoreOntology
$$

ZAI is a swappable reasoning provider, not the architecture. GitHub is a
swappable delivery counterpart, not the architecture. Elixir/BEAM may remain the
best runtime substrate but the durable thing is the semantic contract, not the
runtime's name.

**The commercial product is Governance + Evidence, not generated code.** An
enterprise customer must be answerable from machine evidence (receipt/replay),
not reconstructed incident prose: why something exists, what obligation created
it, what admitted it, what planned/selected it, what authorized its
consequences, what manufactured it, what exact artifact ran, what qualified it,
what happened, whether it replays, what was learned, what future reasoning was
retired.

**Ontology is the product; software is one projection of it.** Other lawful
projections of the same graph: APIs, A2A capabilities, organizational controls,
workflows, dashboards, contracts, simulations, process models, audit views,
documentation, training material, regulatory evidence, financial models,
operational systems. $Graph \rightarrow \{P_1, \dots, P_n\}$.

**Intelligence is an exception handler for unknown semantics, not a structural
dependency.** Normal path: known state → ontology → constraints → planner →
solver → generator → verifier → execution, with zero frontier-model calls.
Abnormal path (and only this path uses a reasoning provider): UNKNOWN → frontier
reasoner → candidate semantics → admission → formalization → permanent
machinery. Every successful formalization should reduce that problem class's
future call probability: $P(LLM \mid c, t{+}1) < P(LLM \mid c, t)$ once class
$c$ is formalized.

**Constitutional KPIs, customer-visible, not internal-only:**

$$
HID = \frac{HumanImplementationTransitions}{TotalEngineeringTransitions} \rightarrow 0
\qquad
LRD = \frac{LLMCallsOnKnownClasses}{KnownClassExecutions} \rightarrow 0
\qquad
IRR = \frac{NewlyMechanizedRecurringClasses}{RecurringClassesDiscovered} \rightarrow 1
$$

**Manufacture closes recursively but stays governed** — this is what
distinguishes it from unbounded self-modification:

```text
observed recurrence → candidate abstraction → semantic pack → verifier →
adversarial qualification → admission → reusable manufacturer
```

$\mu_{t+1} = Learn(\mu_t, Receipts_t)$, but a generator never rewrites itself
outside that pipeline. This is *self-expanding verified manufacturing
vocabulary*, not self-modifying AI.

**Invariants that must survive unchanged from 2026 to 2040** (their disappearance
"because the model got smarter" would be architectural regression, not
progress):

$$
SELECT \neq CONSTRUCT \neq DO
\qquad
Capability \neq Authority
\qquad
PlannerOutput \neq Permission
$$

**Correction to this doc's earlier framing of BRCE:** the invariant is not "no
DO without a human." It is:

$$
\boxed{No\ DO\ without\ AdmittedAuthority}
$$

In the near term almost all irreversible authority is human-held in practice,
which is why earlier sections of this doc and the standing hourly-cycle
instructions say things like "workers get CONSTRUCT at most, never
MERGE/PUBLISH/DEPLOY/DELETE without separately granted authority" — read
"separately granted authority" as *admitted authority*, which today is
overwhelmingly human-sourced but is not definitionally human. As policy matures,
narrow, bounded, reversible DO operations (merge a low-risk generated dependency
repair, rotate an ephemeral worker, publish a reversible internal package, scale
within an approved budget, repair a known runtime state) can be admitted without
a human in the loop for that specific call — while large financial commitment,
external legal representation, novel disclosure, irreversible deletion, new
normative policy, and high-impact production migration remain human-authority
domains indefinitely. The admission boundary is a policy object, not a hardcoded
"ask Sean" branch — do not hand-code either extreme.

**Terminus, one sentence:** by 2040, XaaS is the enterprise semantic operating
substrate — recurring work is manufactured deterministically from admitted
meaning, frontier intelligence is reserved for unresolved novelty, and
governance plus evidence, not generated code, is the primary customer-facing
trust product.

## See Also

- `docs/ultracode/PROGRESS.md` — per-cycle log (created by the first hourly cycle)
- `CLAUDE.md` — xaas project instructions, Chicago-style testing, verification
  discipline, operating mode
