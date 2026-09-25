# Hand-written product-surface ledger

Rows are added in the same change as the hand-written artifact, each naming
the pack capability that should own the artifact so it can be paid down.
This ledger must shrink monotonically per milestone.

| Path | Semantic element | Missing capability | Intended owner pack | Date |
|---|---|---|---|---|
| mix.exs:4 | CalVer version string (`@version "26.9.15"`) | release: calver version stamp from system date | unadmitted — candidate `release-prep` capability in ggen-marketplace | 2026-09-15 |
| CHANGELOG.md:v26.9.15 section | release notes consolidating commits since last tag | release: changelog projection from git history | unadmitted — candidate `release-prep` capability in ggen-marketplace | 2026-09-15 |
| README.md feature-matrix publish row | publish-status fact | release: publish-status row template | unadmitted — candidate `release-prep` capability in ggen-marketplace | 2026-09-15 |
| lib/mix/tasks/ex_noun_verb_cli.ex | optional-dep compile-time guard (`Code.ensure_loaded?` around `use Igniter.Mix.Task`) | optional-dependency conditional-compilation template | ggen-marketplace `ex-noun-verb-cli-pack` templates | 2026-09-15 |
| test/mix/tasks/ex_noun_verb_cli_igniter_optional_test.exs | no-igniter consumer compile regression gate | optional-dependency consumer-compile gate | ggen-marketplace `ex-noun-verb-cli-pack` gates | 2026-09-15 |
| lib/ex_noun_verb_cli/dispatcher.ex + json_output.ex | JSON-error-envelope serializability (tuple detail sanitize) | envelope-sanitization template/gate | ggen-marketplace `ex-noun-verb-cli-pack` | 2026-09-15 |
| test/ex_noun_verb_cli/dispatcher_test.exs + json_output_test.exs | envelope-serializability regression tests | envelope-sanitization gate | ggen-marketplace `ex-noun-verb-cli-pack` gates | 2026-09-15 |
| docs/ (index, tutorials, how-to, reference, explanation) + README/spec amendments | v26.9.15 Diataxis documentation set | docs: diataxis doc-set templates per quadrant | ggen-marketplace `ex-noun-verb-cli-pack` templates | 2026-09-15 |
| lib/ex_noun_verb_cli/introspect.ex + escript --introspect | agent-facing registry manifest (the introspect capability) | introspect-manifest template (exists in clap-noun-verb: `--introspect`) | ggen-marketplace `ex-noun-verb-cli-pack` templates | 2026-09-15 |
| lib/ex_noun_verb_cli/chaining.ex resolve_references/2 + escript interleave | cross-group `@{N.path}` value threading | chain-reference resolution template | ggen-marketplace `ex-noun-verb-cli-pack` templates | 2026-09-15 |
| lib/ex_noun_verb_cli/{shell,completions,help}.ex + escript meta-flags | v26.9.16 ARD features (shell policy port, completion scripts, help projection) | completions/help projection templates (upstream: clap-noun-verb shell.rs + shell_completions example) | ggen-marketplace `ex-noun-verb-cli-pack` templates | 2026-09-15 |
| docs/working-backwards/{press-release,vision-2030,ARD-PRD}-v26.9.16 | Working Backwards release artifacts | release: working-backwards docs pack | unadmitted — candidate `working-backwards` capability | 2026-09-15 |

Paydown: admit a `release-prep` capability (version stamp, changelog
projection, README publish-row) in ggen-marketplace; the three rows above
become generator output and this ledger empties.
