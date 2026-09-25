# RCA — Ran the Rust `ggen` CLI Instead of `ggen_igniter`

## Summary

While scaffolding the `Xaas.Library` domain for the Next Read case study, I
appended `agp:CodegenTarget` rows to `ontology.ttl` and ran `ggen sync run`
(the standalone Rust `ggen` binary at `~/.local/bin/ggen`). The user
corrected me: the instruction was to use `ggen_igniter` (the real Elixir
hex package at `~/ggen_igniter`, `app: :ggen_igniter`, with real mix tasks
`mix ggen_igniter.sync` / `.plan` / `.doctor` / `.replay` / `.install`), not
the Rust CLI. I ran the wrong tool.

## What actually happened, in order

1. I read `xaas/ggen.toml` (`[ontology] source = "ontology.ttl"`,
   `[templates] dir = "templates-hooks"`) and `xaas/templates-hooks/
   ash-gen-resource.txt.tmpl` / `ash-igniter-codegen.txt.tmpl` — real Tera
   templates with `sh_after:` frontmatter, an established, working pattern
   in this repo with real prior receipts (`.agp-receipts/
   Operations-ash.gen.domain.txt`, etc.).
2. I loaded the `run-ggen` skill, which documents the standalone Rust
   `ggen` binary's CLI contract (`ggen sync run`, `ggen.toml` in cwd, Tera
   templates, `--dry-run`).
3. I appended `agp:CodegenTarget` individuals to `ontology.ttl` and ran
   `ggen sync run --dry-run` — the Rust binary, successfully, but the
   **wrong tool**.

## Root cause

**I conflated the directory name with the tool.** The directory in xaas is
named `.ggen_igniter/` (and holds a `manifest.json`), and the earlier
exploration agent's report described the `templates-hooks/*.tmpl` +
`sh_after:` mechanism as "`ggen_igniter`'s own resource templates." I never
verified that claim against `ggen_igniter`'s actual mix.exs (`app:
:ggen_igniter`, real tasks under `lib/mix/tasks/ggen_igniter.*.ex`) or
checked whether xaas's `mix.exs`/`mix.lock` even declares `ggen_igniter` as
a dependency. **It does not** — confirmed via `grep -n "ggen_igniter"
mix.exs mix.lock` returning zero matches, run only after the user's
correction, not before acting.

The real, distinct facts I should have checked first:
- `ggen_igniter` (`~/ggen_igniter`) is a **real Elixir package** whose real
  CLI shape is `mix ggen_igniter.sync --ontology <path> --query
  name=<path.rq> --template <path.eex> --out <path>` (EEx templates,
  explicit flags, no `ggen.toml`) — see
  `~/ggen_igniter/lib/mix/tasks/ggen_igniter.sync.ex`'s own moduledoc.
- The Rust `ggen` binary (`~/.local/bin/ggen`, installed separately) is a
  **different tool**, with a different CLI shape (`ggen.toml` +
  `[templates] dir` + Tera `.tmpl` files with frontmatter), which is what
  xaas's `templates-hooks/*.tmpl` + `ggen.toml` actually target.
- xaas's `.ggen_igniter/` directory name does not mean the `ggen_igniter`
  Elixir package produced or consumes it — its own `manifest.json` shape
  (`out_template`, `outputs`, `pack_dir`, `template`) matches the Rust
  `ggen` binary's manifest tracking, not `ggen_igniter`'s.
- **xaas does not depend on `ggen_igniter` at all right now.** Whatever the
  intended integration is, it has not been wired as a real mix dependency
  in this repo yet — a real, disclosed gap, not something to paper over by
  running the adjacent Rust tool and calling it equivalent.

## Secondary finding: "the ontology has no depth"

The `agp:CodegenTarget` rows I added (`agp:XaasLibraryGenDomain`,
`agp:LibraryBookGenResource`, etc.) are flat generation-plumbing
individuals — `moduleName`/`domainModule`/`mixTask`/`mixArgs`/`rank` only.
They describe *how to invoke a generator*, not *what a Book/Checkout/
Curation actually is* semantically. Contrast with the existing
`pcc:Capability` individuals these rows sit alongside in `ontology.ttl`,
which carry real domain semantics (`xar:requiredAuthority`,
`xar:reversible`, `xar:standing`, `xar:capabilityClass`,
`skos:closeMatch togaf:Capability`). I added pipeline plumbing without
first modeling the Library domain's own real classes/properties/
relationships (grounded in the BIBO/W3C-ORG public ontologies already
identified as the right vocabulary source, per the plan file) — a real,
separate gap from the tool-confusion one above, not the same mistake.

## Corrective actions (not yet executed — see FMEA for prevention)

1. Do not run any generation until `ggen_igniter`'s actual mix-task
   contract is confirmed against xaas: either (a) add `{:ggen_igniter,
   ...}` as a real dep and drive scaffolding via `mix ggen_igniter.sync
   --ontology ... --query ... --template ... --out ...` (EEx, not Tera),
   or (b) get explicit confirmation from the user that the existing Rust
   `ggen` + `templates-hooks/*.tmpl` mechanism (which the earlier
   exploration agent described, unverified, as "ggen_igniter's own") is in
   fact the intended one, despite the naming mismatch.
2. Leave the `agp:CodegenTarget` rows added to `ontology.ttl` in place but
   inert (no `ggen sync run` executed against them for real, only a
   `--dry-run`) until (1) is resolved — do not silently revert without the
   user's direction, but do not build further on them either.
3. Before scaffolding `Xaas.Library`'s resources, do the real domain
   modeling pass (BIBO/ORG-grounded classes/properties) the plan already
   called for, not just generation-target plumbing.

## See also

- `docs/case-studies/next-read/FMEA-ggen-tool-selection.md`
- `~/.claude/plans/use-the-claude-design-mcp-purring-candle.md` — the
  governing plan, step 2
- `~/ggen_igniter/lib/mix/tasks/ggen_igniter.sync.ex`
