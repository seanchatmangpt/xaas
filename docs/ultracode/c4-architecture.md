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

## See Also

- `docs/ultracode/PROGRESS.md` — per-cycle log (created by the first hourly cycle)
- `CLAUDE.md` — xaas project instructions, Chicago-style testing, verification
  discipline, operating mode
