# Western Digital FA Morning Brief: a bounded first-mile proposal

Status: DRAFT for operator review. The document render and the operator text freeze follow acceptance.

Prepared for Western Digital failure analysis leadership. Every factual sentence below carries a ledger marker; the ledger says how each one is known.

## Summary

The supplied Case Study 2 deck proposes an HDD failure analysis agent and presents it as five prototype pages that form one system [C1]. This proposal restates that system as a draft WBPR and compiles it through the first-mile pipeline that produced the v26.9.23 semantic work graph [C2]. The compiler admitted 61 candidate propositions from the draft and manufactured 37 work orders under seven gates, with no LLM after candidate extraction [C3].

The rest of this summary states the open question. Whether the system shortens failure analysis at Western Digital cannot be judged until Western Digital supplies its MTTR baseline, read access to the pilot corpus and data lake, its authorization roles and its quality-system write-back decision [C4]. The supplied deck lists the same needs in its request to Western Digital: current MTTR by mode and how it is measured, who may authorize closure and escalation, and whether QMS write-back via API is allowed in phase one [C5]. What this proposal can show today is a reference loop that runs on synthetic failure cases and on a format-drift work class, not an improvement measured at Western Digital [C6].

## How to read this proposal

Each sentence that states a fact, a count or an outcome ends with a marker that names one entry of the claims ledger. The ledger lives in docs/sjira/v26.9.23/wd-fa/claims.ttl, and this document is rendered from it by scripts/sjira/wd_claims.py, so a hand edit of the prose is refused as projection drift [C7]. Section 9.2 of the accepted v26.9.23 product contract names four classes for the Western Digital scenario and requires unsupplied internal Western Digital facts to stay typed unknown [C8].

- SUPPLIED: the claim is carried by an artifact supplied into this record and bound by a receipt that the fleet validator admits, either a quote checked against a digest-bound supplied text or an observed run whose receipt standing is ALIVE.
- PUBLICLY_OBSERVABLE: any reader can check the claim from a public pull request, commit or CI run, cited by URL.
- ARCHITECTURAL_INFERENCE: the claim follows from other ledger claims by a stated chain of reasoning, and none of its premises is unknown.
- WD_DEPENDENT_UNKNOWN: the claim depends on a Western Digital input that has not been supplied, and the ledger names that input.

The claims court refuses an unresolved marker, a claim with two classes, a sentence that contains a number or a will, prove or reduce verb without a marker, and an unsupplied Western Digital fact typed as anything but unknown [C9]. A reader can therefore separate what was observed from what is argued without trusting the author of the prose [C10].

## The problem as supplied

This section restates the problem as the supplied deck frames it. The supplied deck describes the evidence as slide decks spanning 15 years, Confluence known-issue pages and Excel sheets whose low-confidence rows are queued rather than guessed [C11]. The actual size, age, format mix and access rules of the Western Digital corpus are not known to us, because no corpus inventory and no data lake access have been supplied [C12]. The deck names three risks: old slide plots lack axes, known-issue pages lag engineering changes, and engineers may over-trust a label such as Likely [C13].

For structured data the deck rejects free-form text-to-SQL, because join errors look like findings, and chooses deterministic, versioned, access-checked typed tools over a semantic layer [C14]. The deck's trust design rests on four guards: citation or nothing, applicability rather than probability, a stated falsifier on every card, and an allowed UNKNOWN state [C15]. It keeps a human in the loop for every write, escalation and novel-mode call, allows automatic closure only when five of five applicability conditions hold with one closure in ten sampled, and suspends a rule when one of its closures is reopened [C16].

The supplied Morning Brief System page draws the flow as artboards 2a to 2h: a desktop and a mobile email, a deep-linked case, a why-this drawer, an evidence view, an authorization step, a handled-items log and an unknown or blocked state [C17]. The drives, lots, stations, cases and people in those artboards, such as drive A817, mode FM-217 and lot L421, are illustrative, and their counterparts in Western Digital's real case data are unknown to us [C18].

## The system the deck proposes

This section restates the design the deck proposes. The deck separates three trust zones: a read-only zone for the corpus, case store and data lake, a propose-only agent zone, and an act zone reached through human authorization [C19]. Inside the agent zone a retriever, typed tools, a rules engine for failure-mode applicability and an LLM that ranks and explains feed a verifier that drops any claim without a cited span [C20]. The deck proposes to buy the LLM, vision captioning and vector database, and to build the case schema, tools, rules, verifier and user interface [C21].

Its triage output has five layers, from the L0 state through the L1 next action, L2 ranked modes with applicability and falsifier, and L3 cited prior cases, to an L4 receipt [C22]. Known versus novel is decided by two gates, signature and applicability: a drive inside one cluster closes against the known mode, one between clusters gets a discriminating test chosen by information gain per station minute, one outside all clusters opens a full investigation, and one without a signature stays UNKNOWN [C23]. Feedback costs the engineer nothing extra: a disposition is the label, a senior engineer's recurring call becomes a credited rule with its hit rate shown, and proposed rules are reviewed monthly [C24]. For governance the deck copies source access control lists onto every chunk, uses a private model endpoint, keeps evidence out of email, redacts customer names at ingest and records a receipt per action with identity, authority, consequence, replay and standing [C25].

## The bounded future

This section summarizes the draft WBPR. The WBPR bounds phase one to triage of a failed drive and its reported symptom for one product family at one site over an English corpus [C26]. Its completion statement is an engineer's working day that starts from a brief of decisions, recommendations, unknowns and handled items, every statement of which is traceable to a cited source [C27]. Completion is defined by that finite description rather than an open-ended search for a better assistant, and improvements discovered after acceptance become successor goals [C28].

In the WBPR a failure mode is admitted as known only when every applicability condition holds and no falsifier fires, and a candidate ranking from a language model never admits a mode by itself [C29]. A drive with missing, stale or conflicting evidence is shown as unknown, and a drive outside every known cluster opens a full investigation instead of taking the nearest known mode [C30]. Every write, escalation and novel-mode call needs a named human's authorization, and every authorized action produces a receipt with identity, authority, consequence, replay and standing [C31]. The brief is a projection of admitted case state, never a separate source of truth, and every claim in it links a source span and a timestamp or is removed before display [C32].

The WBPR excludes automatic test scheduling, supplier-facing corrective action requests, open-ended chat across the corpus and root-cause authoring for novel failure modes, as the deck defers them [C33]. It also excludes live integration with Western Digital systems until Western Digital authorizes it [C34].

## The reference loop

This section places the draft inside the release pipeline. The v26.9.23 product contract describes a loop in which prose defines a bounded future, admitted semantics become canonical, and KNOWN work leaves the LLM path entirely [C35]. For the Western Digital draft, an LLM extracted 61 candidate propositions, each bound to its exact byte span in the WBPR, and that extraction is the only LLM edge in the compile [C36]. The ggen_igniter compiler then admitted all 61 candidates against the pack shapes and manufactured 37 work orders, one per required postcondition, invariant or falsifier [C37].

The goal graph GC-WDFA-PILOT has seven gates, WDFA-0 to WDFA-6, for the accepted future, the evidence first mile, deterministic triage, the brief, authorized consequence, learning, and the shadow baseline [C38]. Re-running the compiler reproduced both compiled files byte for byte, so the work graph is a function of the prose, the candidates, the goal graph and the pack [C39]. Four of the eight capabilities in the goal graph are marked Provider UNKNOWN, and the goal graph names the Western Digital input that three of them wait on [C40].

In this release the same machinery ran one complete KNOWN episode, a format-drift repair, through SA2A routing, a deterministic recipe worker, independent verification, a receipt and OCEL events with 0 LLM-provider events [C41]. A second episode of the same failure class routed as KNOWN from admitted MachineExperience with no exploration, after the first episode had started as UNKNOWN and was resolved within its exploration budget [C42]. A cold replay in fresh processes reproduced the episode's recorded standing digest from committed artifacts, without the conversation that produced them [C43].

In the terms of the product contract, the deck's LLM ranking belongs to candidate generation, while applicability admission, the verifier and the receipt log belong to the deterministic KNOWN path [C44]. Because the deck's per-action receipt names the same five fields as the receipts cited here, a pilot action receipt could be checked by the same fleet validator [C45].

## What has been observed, with receipts

This section lists the runs made for this proposal and their receipts. The autofde-lab failure-analysis kernel at merge commit eb93405c passed 10 of 10 probe checks, twice with byte-identical output, on its deterministic path without the TPOT ranker [C46]. On its synthetic fixtures the kernel admitted the known firmware case, kept a misleadingly similar supplier case on its own mode, marked the incomplete case PARTIAL_ALIVE and left the novel case UNKNOWN with an escalation to failure analysis [C47]. The same probe observed the kernel refusing self-certification, rejecting tampered and unbound receipts, and keeping SELECT_ONLY authority with an engineer disposition gate on its work order and API responses [C48]. A verified disposition of the novel case compiled reusable experience, after which the equivalent replay case was admitted as known with 0 exploratory steps instead of 3 [C49].

A copy of the kernel mutated to admit the novel case and to allow self-certification failed 4 of the 10 checks, so the probe detects the defects it guards against [C50]. The 4 tests of the pull request's own court that need no TPOT ranker passed unmodified on the exact commit [C51].

The ggen-marketplace wd-failure-analysis-pack at merge commit 420bc91e passed a semantic witness court rendered by ggen, in which each of its 5 gates accepted its pass witness and refused its fail witness [C52]. When a pass witness was replaced by a zero-candidate case typed KNOWN, the court refused it, so the novel-is-unknown gate is not vacuous [C53]. Together these runs show the proposal's admission rules existing as executable code and as semantic gates, on synthetic data only [C54].

## What is publicly observable

This section lists what any reader can check in public repositories without a receipt of ours. Pull request 170 of seanchatmangpt/autofde-lab, which adds the failure-analysis court, was merged as commit eb93405c [C55]. Its full court, including the TPOT ranker install, the Python court, the Next.js build and the served browser test, concluded success in CI run 35797506789 at head a78d7742 [C56]. Pull request 474 of seanchatmangpt/ggen-marketplace, merged as commit 420bc91e, adds the wd-failure-analysis-pack and a WD failure-analysis work graph of 20 work orders [C57]. That pull request's own text records its repository tests and ggen courts as planned rather than executed [C58]. Pull request 61 of seanchatmangpt/xaas, the WD Case Study 2 quality loop, is an open draft whose exact-head court run 35791935089 concluded failure, so this proposal cites none of its claims as observed [C59]. OCEL 2.0 is a published standard for object-centric event logs [C60].

## What is inferred

The following statements are reasoning, not observation, and each names its premises in the ledger. Because the admission rule does not depend on the data source, the same applicability-and-falsifier gate that admits synthetic cases could admit Western Digital cases once their rules are encoded [C61]. A recurring failure class that is verified once could route as KNOWN afterwards without an LLM, as the format-drift class does in the reference loop and the novel fixture does in the kernel [C62]. Rendering the brief from admitted case state and refusing uncited statements at render time makes citation-or-nothing a property of the generator rather than a review habit [C63]. Sampling one automatic closure in ten, with a rule suspended on reopen, bounds the harm of a wrong rule to the closures it makes before its first detected reopen [C64]. The TPOT-ranked paths that this lane could not execute locally are covered by the public CI run but not by a receipt of ours [C65].

## What Western Digital must supply

Each item below is typed unknown in the ledger until Western Digital supplies it.

- Western Digital's current MTTR for each failure mode, and the method used to measure it, is unknown to us [C66].
- Read access to the pilot product family's corpus and data lake, and an inventory of that corpus, have not been supplied [C67].
- Who may authorize closure and escalation during a pilot is a Western Digital decision that has not been made known to us [C68].
- Whether QMS or MES write-back through an API is allowed in phase one stays undecided until Western Digital decides it [C69].
- Western Digital's failure-mode catalogue, with the applicability conditions and falsifiers of each mode, is needed before any real case can be admitted as known [C70].
- A golden set of closed Western Digital cases for blind replay, and the rule for slicing it by time, has not been supplied [C71].
- The pilot product family, the pilot site and the pilot start date are Western Digital choices that remain open [C72].

No Western Digital sponsor has accepted the WBPR yet, so no pilot obligation exists on either side [C73].

## A bounded pilot with a stop condition

This section bounds the pilot and states when it stops. The deck plans the build in three thirty-day steps: case schema, slide and Confluence ingest, 4 typed tools and a golden set; then the verifier, applicability rules, case view and shadow mode; then the brief, email, authorized write-back and call record [C74]. It sizes the team at two ML or data engineers, one backend engineer, one designer and one FA subject-matter expert at half time [C75]. Its evaluation plan replays 300 closed cases blind, time-sliced to prevent leakage, and runs 4 weeks in shadow mode alongside engineers before launch [C76]. Its target metrics are 40 percent lower MTTR on known modes, at least 90 percent top-three agreement with the final disposition, under 1 percent of automatic closures reopened and 0 uncited claims shown, all pending a 4-week shadow baseline [C77].

A defensible pilot therefore has three stages: a blind replay of closed cases through deterministic triage, a four-week shadow period that records the baseline, and only then an assisted period with authorized actions [C78]. The WBPR's stop condition is met when a golden set of closed cases replays blind through triage, the shadow period has produced a baseline, and every falsifier has been exercised without firing [C79]. Its falsifiers are a brief claim without a resolvable source span, a case admitted as known while a condition is unmet or a falsifier fires, a consequential action without a named human authorization and a receipt, and an unsupplied Western Digital fact presented as anything but unknown [C80].

Work discovered during the pilot that falsifies no proposition of the WBPR enters a successor goal instead of extending the pilot [C81].

## What this proposal does not claim

This section lists what is not claimed. No Western Digital data was used in any run cited here; every observed case is a synthetic fixture [C82]. Live WD integration is a non-goal of the v26.9.23 release [C83]. No change in MTTR at Western Digital is claimed, because no baseline exists to compare against [C84]. The WBPR is a draft that awaits operator acceptance, so the compiled work graph is a candidate future rather than an accepted one [C85]. The rendered document for Western Digital and the operator's text freeze follow acceptance and are regenerated from this ledger rather than edited by hand [C86].

## Decisions requested

This section states the decisions that would move the proposal forward. The first decision is the operator's acceptance of the WBPR text, which fixes its digest and makes the compiled work graph an accepted future instead of a candidate one [C87]. The second decision belongs to Western Digital: whether a sponsor accepts the bounded future and names the pilot product family, site and start date [C88]. After both decisions, the first measurable step is a blind replay of closed cases through the deterministic triage that this proposal has so far exercised only on synthetic fixtures [C89].
