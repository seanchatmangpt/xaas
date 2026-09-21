# Warnings that predate the CI test court being able to reach dialyzer at all
# (the court was cancelled or red before this step for weeks). Each is either a
# dependency's own code or an intentionally non-returning helper; none is in
# the verifier, lease, worktree or autonomic code.
[
  # deps/postgrex: improper list built on purpose for iodata.
  ~r/postgrex\/type_module\.ex.*improper_list_constr/,
  # Mix-task helpers that always raise or halt; "no local return" is their contract.
  {"lib/mix/tasks/xaas.internal_api_token.ex", :no_return},
  {"lib/mix/tasks/xaas.safe_generate_migrations.ex", :no_return},
  # Defensive catch-all after exhaustive clauses.
  {"lib/xaas/actuation.ex", :pattern_match_cov},
  # Ash.Query.filter/2 is a macro; dialyzer sees it as a missing remote function.
  {"lib/xaas/platform/webhook_delivery.ex", :call_to_missing}
]
