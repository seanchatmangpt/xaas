# W603 — Operator authority/refusal receipt export (v26.10.7 WP-1, OS-14 / Art. 12(3))

Standing: **ALIVE** (lane scope). Subject: `/Users/sac/xaas` branch
`feat/playwright-surface` (no `release/v26.10.7` branch exists — checked; worked on
the current branch, uncommitted per lane discipline, coordinator owns commits).

## Files written (lane-owned)

- `lib/xaas/operations/authority_ledger_export.ex` (new) — `Xaas.Operations.AuthorityLedgerExport`
- `lib/mix/tasks/xaas.export_authority_ledger.ex` (new) — `mix xaas.export_authority_ledger [--since ISO8601] [--out PATH]`
- `test/xaas/operations/authority_ledger_export_test.exs` (new) — the Chicago court
- `docs/sjira/v26.10.7/plans/w603-authority-ledger.md` (this receipt)

## Cross-lane unblock fixes (compile-freeze SLA, disclosed, minimal)

1. `lib/xaas/operations/authority_ledger_export.ex` — a `require Ash.Query` header
   comment attributed "W984ci" appeared on disk from another lane while this file was
   in flight; kept (it is the correct fix: `Ash.Query.filter` macros need
   `require Ash.Query` in a plain module).
2. `lib/xaas/actuation/quiescent_stop.ex` — another lane left the `@moduledoc`
   heredoc closed early, stranding W984ct prose in the module body (SyntaxError on
   em-dash at line 30). Removed the early `"""` closer so the moduledoc extends to
   the intended end. Verified: quiescent court `test/xaas_web/quiescent_fabric_tie_test.exs`
   still **9 passed** after the edit.
3. `lib/mix/tasks/xaas.airo.compile_shacl.ex` — another lane's in-flight file broke
   the shared compile (`Enum.join("#") <> "#"` — `Enum.join/2` arity error).
   Minimal fix: `|> Enum.join("#") |> Kernel.<>("#")`. Remaining warning in that
   file (`RDF.Description.has_object?/2` undefined at line 263) is that lane's
   in-flight code, left to its owner.

## Export surface spec

`mix xaas.export_authority_ledger [--since ISO8601] [--out PATH]` (default stdout;
`--out` writes canonical bytes to a file). Emits ONE RFC 8785 JCS canonical JSON
bundle (`Xaas.Semantics.Jcs` facade over the pinned `jcs` hex 0.2.0) containing:

- `refusal_variants`: the typed refusal-code vocabulary — all 71 variants from
  `docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json` via
  `Xaas.Semantics.AiroRiskMapping.variants/0` (same source of truth; each entry
  `{variant, sites}`).
- `entries`: authority entries in window — `Xaas.Operations.AuditLogEntry` rows
  (source `audit_log_entry`, occurred_at + authority/subject/metadata projections)
  and `Xaas.Operations.ActuationReceipt` rows (source `actuation_receipt`, status +
  resource_module/action/subject + ontology IRI/projection/input/result hashes +
  replay_token), sorted by `{source, id}`, each carrying `leaf_hash`.
- `merkle_root`: SHA-256 Merkle root over sorted leaves
  (`leaf = sha256(JCS(entry-without-leaf_hash))`, pairwise `sha256(l<>r)`, odd leaf
  duplicated, single leaf = itself, empty = 64 hex zeros). **Disclosed substitution**:
  no `blake3` hex package in deps (verified mix.exs/mix.lock), so SHA-256 — same
  honest-crypto choice as `Xaas.Witness.AuditChain`; bundle self-describes via
  `"hash_algorithm": "sha256"`.
- `since`, `ledger_version` (1), `hash_algorithm`.

Determinism: no wall-clock field; entries sorted; JCS encoding ⇒ byte-identical
bundles for the same row set.

Typed refusals (Mix.raise, non-zero exit):
- `REFUSED(empty_authority_ledger, detail: %{entries: 0, refusal_variants: m, since: dt|nil})`
- `REFUSED(refusal_ledger_unreadable, detail: %{path: ...})`
- `REFUSED(invalid_since, detail: %{value, reason})`
- `REFUSED(invalid_option, detail: [...])`

## Verification (real commands, real output)

`PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW603`:

- `mix compile` — exit 0 (full 946-file app; one pre-existing warning in another
  lane's `approval_causal_anatomy.ex`).
- `mix test test/xaas/operations/authority_ledger_export_test.exs` — **9 passed, 0 failed**:
  1. bundle bytes deterministic ×2 (module surface);
  2. refusal vocabulary present (71 variants, matches AiroRiskMapping), both entry
     sources present, `hash_algorithm == "sha256"`;
  3. root recomputes from emitted bundle (module surface);
  4. root content-sensitivity (one subject-byte rewrite flips root) — mutation rationale;
  5. `--since` window excludes a 2020 row;
  6. empty selection window ⇒ typed `{:error, {:empty_ledger, ...}}` (module);
  7. empty window via real mix task run ⇒ typed `REFUSED(empty_authority_ledger)` Mix.Error;
  8. mix task `--out` determinism ×2 fresh runs: byte-identical files, root recomputes
     from decoded bytes;
  9. invalid `--since` ⇒ typed `REFUSED(invalid_since)`, not a crash.

×2-fresh-root requirement: satisfied by test 8 (two independent task executions over
real rows, byte-identical bytes + recomputable root).

## Exclusions / disclosed constraints

- Reads use `authorize?: false` — the operator-facing internal surface, mirroring
  `Xaas.Governance.Changes.WriteAuditLogEntry`'s internal-write idiom
  (AuditLogEntry read is a bypass-open carve-out; ActuationReceipt policy is
  forbid-always).
- Receipt fixture drives the real actuation kernel (admitted causal certificate,
  the causal_admission_test idiom) because `ActuationReceipt :prepare` validates the
  `belongs_to :intent` exists — no synthetic rows.
- The empty-ledger refusal is exercised over a genuinely empty selection window
  (`since: 2999-01-01`), not an empty-table fiction: the shared test DB durably
  holds committed rows from other runs and sandbox transactions see committed data.
- Ash 3 public-filter rule discovered en route: query filters may reference only
  public attributes — audit entries filter on public `occurred_at` (not private
  `inserted_at`); receipts on public `started_at`.
- MIX_BUILD_ROOT `_build-laneW603` deleted at lane close (lane-lease cleanup law).
