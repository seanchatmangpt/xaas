<!-- Provenance: WBPR drafted by lane V23-W (wave B1c, v26.9.23; PRD section 9.2, the Friday G12
     deliverable) from the operator-supplied deck "FA Morning Brief System.zip" (page "FA Agent Case
     Study Deck", Case Study 2; text projection supplied/case-study-2.txt), autofde-lab PR 170,
     ggen-marketplace PR 474 and xaas PR 61. Status: DRAFT, awaiting operator acceptance. This file
     is provenance for candidate extraction (PR-001, AR-003); it is not executable authority, and no
     proposition extracted from it is admitted into GC-26.9.23. -->

# WBPR: Western Digital FA Morning Brief System, phase one

Status: DRAFT. This bounded future awaits operator acceptance and then acceptance by a Western Digital sponsor.

## 1. The bounded future

This WBPR describes the world that is observably true when phase one of the Western Digital failure analysis (FA) Morning Brief System is complete.
Phase one covers triage of a failed hard disk drive and its reported symptom for one product family at one site over an English corpus.
The goal is complete when an FA engineer starts the working day from a brief that states what needs a decision, what is recommended, what is unknown and what was already handled, and every statement in that brief is traceable to a cited source.
Completion is defined by this finite description, not by continued search for a better assistant.
Improvements discovered after acceptance become successor goals unless they falsify a proposition of this WBPR.

## 2. Actors and roles

The FA engineer owns every consequential disposition of a failure case.
A senior FA engineer may credit a recurring judgment as a named rule.
The FA assistant proposes rankings, explanations and next actions but holds no authority to act.
An independent verifier checks every claim in a brief against its cited source before the brief is shown.
The action service executes an authorized action and records a receipt for it.
Western Digital supplies the corpus, the data lake access, the authorization roles and the quality-system integration decision.

## 3. First mile: evidence ingestion

Slide decks, Confluence known-issue pages and Excel sheets are normalized into one FA case schema.
Every normalized case records symptom, signature, failure mode, evidence items, disposition and the exact source span of each field.
Low-confidence extractions are queued for review instead of being guessed.
Source access control lists are copied onto every indexed chunk and are enforced at retrieval time.
Structured build and test facts are read through typed, versioned, access-checked tools over a curated semantic layer, not through free-form text-to-SQL.
The typed tools return the build record, the test runs, the lot recurrence and the applicability conditions of a drive.

## 4. Core: triage by applicability

Triage of a failed drive yields one state, one next action, ranked candidate failure modes with their applicability, the closest prior cases and a receipt.
The state of a case is exactly one of decision required, recommended, unknown or handled.
A failure mode is admitted as known only when every applicability condition holds and no falsifier fires.
A candidate ranking from a language model or a learned ranker never admits a known failure mode by itself.
When some applicability conditions are unmet, the case shows how many conditions hold and names the missing one.
Every candidate failure mode carries a stated falsifier before any action is proposed.
A drive whose signature lies between two known clusters receives the discriminating test with the highest expected information gain per minute of station time.
A drive whose signature lies outside all known clusters opens a full FA investigation instead of the nearest known mode.
A drive with missing, stale or conflicting evidence is shown as unknown, and no failure mode is proposed for it.

## 5. The morning brief

The morning brief is a projection of admitted case state, never a separate source of truth.
The morning email carries no evidence; its links open the case view inside the assistant with the context preserved.
Every claim in the brief links to a source span and a timestamp, and an uncited claim is removed before display.
The brief shows access-denied, stale-evidence, pending-action and failed-verification states explicitly instead of omitting them.
Items handled without the engineer appear with the rule, the evidence and a way to reverse them.

## 6. Last mile: authorized consequence

Every write, every escalation and every novel-mode call requires an authorization by a named human.
The confirmation step states the consequence of each outcome before the engineer commits.
An authorized action produces a receipt with identity, authority, consequence, replay and standing.
Automatic closure applies only when all applicability conditions hold, and one closure in ten is sampled by a human spot-checker.
Write-back to the quality or manufacturing execution system happens only through the action service and only if Western Digital permits it.

## 7. Learning

Closing, reopening or routing a case records the verdict without extra data entry.
A reopened automatic closure suspends the rule that produced it.
A verified novel-mode investigation becomes reusable experience, so an equivalent later case routes as known.
The reranker is retrained weekly and proposed rules are reviewed monthly.

## 8. Claims discipline

Every claim in a proposal derived from this WBPR is classified as supplied, publicly observable, architectural inference or dependent on an unknown Western Digital input.
A Western Digital internal fact that was not supplied stays typed unknown and is never manufactured.
An observed proof is cited only with a receipt that the fleet receipt validator admits.

## 9. Measurement

The mean time to resolution of known failure modes is measured against a baseline recorded during a four-week shadow period.
The pilot reports top-three failure-mode agreement with the final disposition, the reopen rate of automatic closures and the number of uncited claims shown.
Targets for these metrics stay pending until Western Digital supplies the baseline and its measurement method.

## 10. Exclusions

Phase one excludes automatic test scheduling on stations.
Phase one excludes supplier-facing corrective action requests.
Phase one excludes open-ended chat across the corpus.
Phase one excludes root-cause authoring for novel failure modes.
Phase one excludes live integration with Western Digital systems until Western Digital authorizes it.

## 11. Falsifiers

The goal is falsified if a brief shows a claim without a resolvable source span.
The goal is falsified if a case is admitted as known while an applicability condition is unmet or a falsifier fires.
The goal is falsified if a consequential action executes without a named human authorization and a receipt.
The goal is falsified if an unsupplied Western Digital fact appears in a proposal as anything other than unknown.

## 12. Stop condition and successor policy

Phase one stops when a golden set of closed cases replays blind through triage, the shadow period has produced a baseline, and every falsifier above has been exercised without firing.
Work discovered during the pilot that falsifies no proposition of this WBPR enters a successor goal.

## 13. What Western Digital supplies

Western Digital supplies the current mean time to resolution by failure mode and how it is measured.
Western Digital supplies who may authorize closure and escalation.
Western Digital decides whether quality-system write-back through an API is allowed in phase one.
Western Digital supplies read access to the corpus and the data lake for the pilot product family.
