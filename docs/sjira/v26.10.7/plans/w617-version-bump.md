# W617 — Version bump to 26.10.7 (WP-5, v26.10.7 campaign)

Date: 2026-10-07 · Lane W617 · Repo `/Users/sac/xaas` · Branch `feat/playwright-surface`

## Change

- `VERSION`: `26.10.6` → `26.10.7` (trailing newline preserved, `printf '26.10.7\n'`).
- `mix.exs` **not edited** — it reads `VERSION` via the W908 guarded
  `File.read("VERSION")` / `Mix.raise("REFUSED(mix_boot, ...)")` block
  (`mix.exs:15-24`); the literal `26.10.6` in the tree lives only in `VERSION`.

## Location inventory

Version-bearing pins surveyed in `lib/` + `config/`:

| Location | Verdict |
|---|---|
| `VERSION` | **Bumped** (the one lawful pin) |
| `lib/mix/tasks/xaas.release_audit.ex:14` `@version File.read!("VERSION")` | Tracks VERSION automatically — no edit |
| `config/config.exs:281/292` `version:` | Dep configs, not the release version — left |
| `lib/**` `v26.10.6` occurrences (router comments, eu_ai_act tasks, doctor task receipt paths, ledger validation comments) | **Left** — they pin real v26.10.6 campaign artifacts under `docs/sjira/v26.10.6/`, `docs/cro/artifacts/*-v26.10.6.*`, which still exist on disk. Bumping them would break the evidence paths. |
| No `/version` endpoint or health payload pins release version found in `lib/`/`config/` (only dep/protocol `version` fields) | — |

## Gates (real output)

1. **Fresh strict compile** (`MIX_ENV=test MIX_BUILD_ROOT=_build-laneW617
   PATH=$HOME/.asdf/shims:$PATH mix compile --force`): **EXIT=0**
   (warnings only: `xaas.actuation.ex` unused carried_input_hash / dead cond
   clause, `refusal_ledger_export.ex`, `compile_shacl.ex` RDF predicates,
   ash_affidavit envelope tag — all pre-existing).
2. **`mix xaas.release_audit`**: **EXIT=1, typed REFUSED with 19 findings.**
   First finding is the expected tag-vs-VERSION refusal the task briefed:
   `REFUSED(release_audit, detail: %{finding: "release tag v26.9.29 does not
   match VERSION baseline 26.10.7 — pins diverged"})`.
   Note: **newest existing tag is `v26.9.29`** (tags: v26.9.22, v26.9.24,
   v26.9.29) — tag `v26.10.6` does NOT exist in the repo. The other 18 findings
   (Ash domain order/counts 82-vs-70, missing canonical source modules, broken
   diataxis Markdown links, legacy 49/69-resource claims, missing 70-resource
   total in architecture overview) are pre-existing audit findings in the
   working tree, some of which concurrent lane W612 is actively hardening.
   **Do not mask; this is the audit working.** Coordinator must cut tag
   `v26.10.7` (and ideally the missing `v26.10.6`) once the audit findings are
   cleared, so pins agree at release.
3. **Affected version tests** (`test/mix/tasks/xaas_release_audit_test.exs` +
   `test/xaas/release_audit_enoent_court_test.exs`): **11/17 passed, 6 failed**
   at VERSION=26.10.7. Baseline control (same suites with `VERSION` swapped
   back to `26.10.6` via `git show HEAD:VERSION` file swap, no stash): **9/17
   failed** — failures are **pre-existing** (concurrent W612 churn on
   `lib/mix/tasks/xaas.release_audit.ex`, modified in the shared tree), not
   session-introduced; the bump actually reduces failures 9→6 under current
   W612 intermediate state.

## Standing

- Version bump itself: **ALIVE** (VERSION=26.10.7 on disk; compile EXIT=0
  witnessed on exact file set; VERSION restored and re-read after baseline
  control).
- Release-readiness gate: **BLOCKED(release_audit)** — 19 typed findings,
  tag `v26.10.7` absent (as is `v26.10.6`). Tag-advance sequencing required:
  clear W612 findings → commit → tag `v26.10.7` → audit passes only when
  newest tag == VERSION.
- Lane hygiene: `_build-laneW617` deletion was **denied by harness
  permissions** (rm -rf refused twice); directory left in place for
  coordinator cleanup per campaign law.

## Falsifiers

- `cat VERSION` returns anything other than `26.10.7`.
- `mix xaas.release_audit` first finding is not the pins-diverged typed
  refusal while tags remain unmoved.
