# Warnings that predate the CI test court being able to reach dialyzer at all
# (the court was cancelled or red before this step for weeks). Each is either a
# dependency's own code or an intentionally non-returning helper; none is in
# the verifier, lease, worktree or autonomic code.
#
# v26.9.22 wave (XAAS-26922-03): the dialyzer leg first ran on the merged
# tree. Fixed in code this wave: dispatch.ex (semantic_descriptor spec, dead
# gethostname catch-all, dead io_log nil clause) and
# zoe/private_meeting_inference.ex (sha256_file via File.open!/IO.binstream).
# The remaining entries are legacy ERRC/OCEL/R2RML/mix-task code this wave did
# not touch, plus two defensive nil-guards over RDF.Graph.description/2
# (sjira/ard_court.ex) whose lib type omits nil, and one defensive sum-type
# guard in dispatch.ex remove_descriptor/1 that dialyzer refines away at its
# call site. Each stays visible here for paydown by its owning pack.
[
  # deps/postgrex: improper list built on purpose for iodata.
  {"deps/postgrex/lib/postgrex/type_module.ex", :improper_list_constr},
  # Mix-task helpers that always raise or halt; "no local return" is their contract.
  {"lib/mix/tasks/xaas.internal_api_token.ex", :no_return},
  {"lib/mix/tasks/xaas.internal_api_token.ex", :no_return},
  {"lib/mix/tasks/xaas.ocel_validate.ex", :no_return},
  {"lib/mix/tasks/xaas.safe_generate_migrations.ex", :no_return},
  {"lib/mix/tasks/xaas.ultracode.learn.ex", :pattern_match_cov},
  {"lib/mix/tasks/xaas.ultracode.learn.ex", :pattern_match},
  {"lib/mix/tasks/xaas.ultracode.learn.ex", :unused_fun},
  {"lib/mix/tasks/xaas.ultracode.ocel_conformance.ex", :no_return},
  {"lib/xaas/actuation.ex", :pattern_match_cov},
  {"lib/xaas/castle.ex", :pattern_match_cov},
  {"lib/xaas/semantics/r2rml.ex", :call_with_opaque},
  {"lib/xaas/semantics/r2rml.ex", :call_without_opaque},
  {"lib/xaas/sjira/ard_court.ex", :pattern_match},
  {"lib/xaas/telemetry/ocel_ndjson.ex", :guard_fail_pat},
  {"lib/xaas/ultracode/dispatch.ex", :pattern_match},
  {"lib/xaas/ultracode/ocel/validator.ex", :guard_fail_pat},
  {"lib/xaas/ultracode/ocel_conformance.ex", :pattern_match_cov},
  {"lib/xaas/ultracode/wave_loop.ex", :pattern_match_cov},
  {"lib/xaas/ultracode/wave_loop.ex", :pattern_match},
]
