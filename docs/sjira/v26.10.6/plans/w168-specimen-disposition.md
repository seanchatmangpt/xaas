# W168 — Parked Specimen/Court Test File Disposition

Repo: `/Users/sac/ash_surface`, lane W168, v26.10.6 convergence.
Subject: 24 untracked court/specimen test files (W153-v2 sync-installer outputs) + `fixture/burn_in/` tree.
Date: 2026-10-06.

## Gate result

`git check-ignore` was run on every one of the 24 files. **Zero are gitignored.**
`git status --porcelain` independently shows all as `??` (untracked, not ignored).
Therefore, per the disposition rule ("never delete non-ignored files"), **nothing was
deleted**. The DELETE path (step 2) was not taken: its precondition — all 24
check-ignore-confirmed as scratch — failed on all 24.

Secondary gate: only 4 of 24 reference the missing `composition_specimens` dir
(`test/ash_{a2a,r2rml}_composition_court.exs`, `test/{audit_trail,notification_extension}_composition_court.exs`
— 8 refs each). `test/composition_specimens/` does not exist. The other 20 reference
fixture paths (`fixture/malformed_specimens`, `fixture/info_mutants/info_mutant.exs`,
`fixture/transformer_mutants/`, `fixture/mix.exs`) that may or may not exist; that
question is open for the manual reviewer, and is the only thing keeping these from a
clean commit decision.

Incidental finding: 3 sibling files (`test/ash_r2rml_composition_test.exs`,
`test/audit_trail_composition_test.exs`,
`test/notification_extension_composition_test.exs`) ARE gitignored scratch and would
have been lawful deletes had they been on the parked list; the sibling
`test/ash_a2a_composition_test.exs` is untracked-not-ignored (on the parked list, retained).

## Disposition

- **Deleted:** none.
- **Retained for manual review:** all 24 (list below), plus `fixture/burn_in/`
  (subdirs: `ash_surface`, `ash_a2a`, `ash_r2rml`, `audit_trail`, `notification_extension`;
  files: `closure_receipt.exs`, `evidence_export.exs`, `runtime_burn_in.exs` per family).
- No git mutations performed.

## The 24 retained files

Descriptions are from the files' own first test/moduledoc text.

| file | lines | refs missing specimens dir | what it is |
|---|---|---|---|
| test/ash_a2a_composition_court.exs | 317 | 8 | compose-green court: each extension's Info getters see only its own facts (resource drafts) |
| test/ash_a2a_composition_test.exs | 42 | 0 | compiled-fixture check: fixture carries the AshA2A.Dsl extension |
| test/ash_a2a_info_parity_court.exs | 205 | 0 | DSL info-parity court (Spark transformer persist/probe entities) |
| test/ash_a2a_spark_parity_court_test.exs | 123 | 0 | Spark parity court |
| test/ash_a2a_transformer_court_test.exs | 327 | 0 | Spark transformer court |
| test/ash_a2a_verifier_court_test.exs | 269 | 0 | verifier court |
| test/ash_r2rml_composition_court.exs | 317 | 8 | compose-green court (AshR2RML family) |
| test/ash_r2rml_igniter_idempotence_court_test.exs | 311 | 0 | igniter clean-install/re-install idempotence court |
| test/ash_r2rml_info_parity_court.exs | 205 | 0 | DSL info-parity court |
| test/ash_r2rml_spark_parity_court_test.exs | 151 | 0 | Spark parity court |
| test/ash_r2rml_transformer_court_test.exs | 327 | 0 | Spark transformer court |
| test/ash_r2rml_verifier_court_test.exs | 304 | 0 | verifier court |
| test/audit_trail_composition_court.exs | 317 | 8 | compose-green court (AuditTrail family) |
| test/audit_trail_igniter_idempotence_court_test.exs | 311 | 0 | igniter idempotence court |
| test/audit_trail_info_parity_court.exs | 205 | 0 | DSL info-parity court |
| test/audit_trail_spark_parity_court_test.exs | 102 | 0 | Spark parity court |
| test/audit_trail_transformer_court_test.exs | 327 | 0 | Spark transformer court |
| test/audit_trail_verifier_court_test.exs | 231 | 0 | verifier court |
| test/notification_extension_composition_court.exs | 317 | 8 | compose-green court (NotificationExtension family) |
| test/notification_extension_igniter_idempotence_court_test.exs | 311 | 0 | igniter idempotence court |
| test/notification_extension_info_parity_court.exs | 205 | 0 | DSL info-parity court |
| test/notification_extension_spark_parity_court_test.exs | 99 | 0 | Spark parity court |
| test/notification_extension_transformer_court_test.exs | 327 | 0 | Spark transformer court |
| test/notification_extension_verifier_court_test.exs | 224 | 0 | verifier court |

## Rationale

The disposition mandate conditions deletion on `git check-ignore` confirming every file
as ignored scratch. Real output shows the opposite: all 24 are untracked and un-ignored,
i.e. committable content by git's own accounting. Deleting committable court tests on an
unverified "same-day scratch" prior would be μ on unadmitted O. The manual reviewer
needs only two facts per file: does its referenced fixture exist, and does it pass under
the pinned toolchain (`asdf` elixir 1.20.2-otp-28). Files whose fixtures exist and pass
are candidates for adoption into `test/extras/` or the main suite; the rest are
deletion candidates with a per-file receipt.
