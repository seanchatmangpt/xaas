# WBPR — The Semantic Manufacturing Reference Loop (GC-FRI-0800)

*Working-backwards press release dated Friday 2026-09-25 08:00 PT. Status: **DRAFT — awaiting operator acceptance**
(the one human edge of G0). This prose bounds the Friday checkpoint. Every sentence is compiled into
`propositions.ttl`. Any improvement it does not describe belongs to successor checkpoint GC-026923 and cannot reopen
this one.*

---

## FOR IMMEDIATE RELEASE

### Known work now runs without a language model: the first closed semantic manufacturing loop

**Friday, September 25, 2026.** Today, for the first time, a known class of software work ran from a semantic work
order to a verified, receipted consequence with every language-model worker switched off. It then updated its own
frontier and did the next piece of eligible work.

**The problem.** Before today every loop in the fleet ended in a conversation. Plans lived in chat transcripts,
standing was typed by hand, and a language-model session made each handoff between systems. When that session
stopped, the work stopped. Because each investigation uncovered more work, nothing could say when a goal was
finished.

**The loop.** The operator writes the future first: this press release. A compiler turns the prose into semantic
propositions and classifies each as bootstrap, first mile, deterministic core, last mile, or successor. Each work
order in the Semantic Jira graph then names:

- its exact subject: repository, commit and path scope;
- the target postcondition;
- its dependencies;
- the capability it requires;
- its evidence horizon, authority ceiling and consequence class;
- an acceptance predicate, a falsifier, and exclusions.

**The reference episode.** The first closed episode is deliberately boring. It is a formatting-drift repair in
ggen_igniter.

1. The frontier is derived from the work graph and its transition log.
2. The order's semantic tuple travels through the SA2A capability route into XaaS, and a digest of the tuple is
   identical at every hop.
3. The capability resolves to a deterministic recipe worker, not a model.
4. XaaS leases the work under its authority rules and runs the recipe in an isolated worktree at the exact subject.
5. An independent verifier observes the postcondition. Reverting the change makes the verifier fail, so the check
   is not vacuous.
6. The receipt carries identity, authority, consequence, replay and standing, and it validates.
7. An OCEL event records the consequence.
8. The receipt re-enters the graph, the order leaves the frontier, and its dependent becomes eligible.

**Cold start.** A fresh process with no conversation, no session memory and no home directory reconstructs every
subject, capability, authority boundary, receipt and frontier item from durable artifacts alone. It replays the
episode to the same standing byte for byte.

**Learning.** The first time this failure class appeared it was UNKNOWN and needed bounded exploration. That episode
was compiled into admitted MachineExperience. The second occurrence, on a different subject, routed as KNOWN and
ran with zero language-model calls and fewer steps.

**Where to stop.** Each repository touched by this checkpoint carries a bounded standing:

- **Critical-path repositories** (ggen_igniter and xaas) are ALIVE at an exact head with green CI.
- **Every other repository** is typed Successor, Blocked, Unsupported or Refused, with no unclassified unknowns.
- **Remaining work** is either named by this release or explicitly assigned to the successor checkpoint.

The same compiler turned the Western Digital failure-analysis narrative into a finite work graph. It produced a
five-to-eight-page proposal in which every claim is marked as observed proof, bounded architectural inference, or a
WD-dependent unknown.

"We stopped asking whether the system could be better and started asking whether the sentences in this release are
true," said the operator. "That question has an answer."

## What is deliberately NOT in this release (exclusions)

- No claim that language models are gone. They remain the tool for UNKNOWN semantics, including drafting this
  release.
- No production Western Digital integration, live WD data, or measured MTTR.
- No deployment, registry publish, or token rotation.
- No claim that every repository is ALIVE, and no claim that Claude-to-ZCode workflow takeover is proven.
- The ZOE Wednesday surface, ggen projection-drift repair, and the 176 synthesized v26.9.22 orders belong to
  successor GC-026923.

## FAQ

**Q: What makes this "finished"?**
A: The court `mix xaas.stop_court --checkpoint GC-FRI-0800` returns STOP=true. That means all thirteen gate
receipts G0–G12 are ALIVE, and every remaining frontier item is Successor, Blocked, Unsupported or Refused.

**Q: What happens to work discovered on Thursday?**
A: If it falsifies one of G0–G12, it is fixed. Otherwise it is filed under GC-026923.

**Q: Why formatting drift?**
A: It is the smallest KNOWN class that needs no dependencies, network or compile. That lets the loop, not the task,
be what is proven. Projection-drift repair through ggen is the first successor class.
