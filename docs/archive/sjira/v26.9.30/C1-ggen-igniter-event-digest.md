# C1: ggen_igniter must export event_digest/1 (plan doc, no edits in ~/ggen_igniter)

Source: ERRC sweep wf_b22a847a-0e5, action C1 (cost 4, gain 5). Standing: UNKNOWN. This is a plan, not a ticket
for the xaas ultracode sensing profile (no `## Status` section on purpose).

- `lib/xaas/ultracode/semantic_jira_bridge.ex` compiles only when ggen_igniter ships the 26.9.20 SemanticJira API.
- Making `GgenIgniter.SemanticJira.TransitionLog.event_digest/1` public is not enough: the bridge also calls
  `TransitionLog.legacy_event_digest` (`semantic_jira_bridge.ex:966`), which does not exist upstream.
- Local `~/ggen_igniter` is at 26.9.30 with untracked files; hex 26.9.29 lacks the `semantic_jira/` directory.
- Required upstream work: export both functions, publish a hex version, then raise the floor in xaas `mix.exs`
  and re-run `mix compile` and `mix test test/xaas/ultracode/semantic_jira_bridge*`.
- Owner decision pending: scope and timing of the cross-repo release.
