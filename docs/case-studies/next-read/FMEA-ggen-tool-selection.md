# FMEA — Generator-Tool Selection for the Next Read Case Study

Failure Mode and Effects Analysis for the specific failure class in
`RCA-ggen-tool-confusion.md`: picking the wrong code-generation tool/
mechanism when a repo has more than one plausibly-named candidate.
Severity/Occurrence/Detection scored 1 (low) - 5 (high); RPN = S x O x D.

| # | Failure mode | Effect | S | O | D | RPN | Prevention / detection control |
|---|---|---|---|---|---|---|---|
| 1 | Conflate a directory/file name (`.ggen_igniter/`) with the tool that produced it, without checking the tool's own `mix.exs`/`Cargo.toml`/binary | Real commands run through the wrong tool's CLI contract; work looks like progress but doesn't compose with what the user actually asked for | 4 | 3 | 4 | 48 | Before running any generator, grep the target repo's `mix.exs`/`mix.lock` (or `Cargo.toml`/`package.json`) for the exact dependency name the user named. Zero matches is a stop condition, not a "close enough, proceed" signal. |
| 2 | Trust an earlier exploration subagent's unverified claim ("ggen_igniter's own resource templates") as fact | A wrong premise propagates into a real plan and real ontology edits before anyone re-checks it | 4 | 3 | 3 | 36 | Subagent reports are evidence to verify, not conclusions to build on directly, per `no-overclaiming-conversational.md` — re-verify any claim about *which tool* produces a given artifact before acting on it, especially when two similarly-named tools exist. |
| 3 | Two real, independently-installed tools share a near-identical name (`ggen` binary vs. `ggen_igniter` package) in the same ecosystem | Same as #1, but the confusion is environment-structural, not just a one-off misread | 3 | 4 | 3 | 36 | When a repo references `ggen`-family tooling, explicitly enumerate every candidate (`which ggen`, `mix deps` for `ggen_igniter`, any `.ggen*` directories) and name which one a given file/directory actually belongs to, in writing, before the first mutating command. |
| 4 | Add ontology individuals that only describe generation plumbing (moduleName/mixTask/mixArgs) with no real domain semantics for the resource being generated | "Ontology has no depth" — the RDF graph degrades into a command-invocation log rather than a real model of the domain (Book/Checkout/Curation), losing the actual value of an ontology-driven approach | 3 | 3 | 4 | 36 | Model the domain's real classes/properties (grounded in a public ontology per `~/CLAUDE.md`'s Research Sources rule — BIBO/W3C-ORG here) *before* adding any generation-target individuals; a generation-target row should `renderOf`/reference a real domain individual, not stand alone. |
| 5 | Run a generator in `--dry-run`/preview mode and treat that as sufficient validation that the *tool choice* was correct | A successful dry-run of the wrong tool still "succeeds," masking the tool-selection error under a green result | 3 | 2 | 4 | 24 | A dry-run validates syntax/config for the tool you ran — it cannot validate that you ran the *intended* tool. Tool selection is a separate, prior check (see #1), not something a dry-run result can retroactively confirm. |
| 6 | Proceed past an ambiguous instruction ("use ggen_igniter") without a quick disambiguating check, in the name of autonomous/proactive execution | Autonomy is spent moving fast in the wrong direction rather than checking a cheap, high-value fact first | 4 | 2 | 3 | 24 | Proactive execution means not asking the user unnecessary questions — it does not mean skipping a 30-second `grep`/`find` fact-check the user's own instruction depends on. Cheap verification before a multi-file mutation is not the kind of "interruption" the proactive style discourages. |

## Highest-leverage prevention (RPN-ranked)

1. **(RPN 48) Dependency-grep gate before any generator invocation.** For
   any "use tool X" instruction, `grep`/`find` for X's real declaration in
   the target project (mix.lock, Cargo.lock, package.json, or the actual
   binary on `$PATH`) before running anything. Zero hits => stop and
   surface the gap, don't substitute an adjacent tool.
2. **(RPN 36, x3 tied) Verify subagent tool-identity claims; ground
   ontology additions in domain semantics before pipeline plumbing;
   explicitly enumerate same-named-tool candidates.** All three reduce to
   the same discipline: when two things could plausibly be "the tool the
   user means," name both explicitly and pick with evidence, not
   convenience.

## See also

- `docs/case-studies/next-read/RCA-ggen-tool-confusion.md`
- `~/.claude/rules/no-overclaiming-conversational.md`
- `~/.claude/rules/local-dfcm-manufacturing-engine.md` (law 4: execution
  outranks narrative — the same discipline applied here to tool selection)
