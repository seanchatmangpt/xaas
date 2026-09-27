# Legacy recovery sensing

XaaS does not decide whether legacy behavior is semantically equivalent. That
standing belongs to the external court.

The `legacy_recovery` sensing profile consumes a
`beam4pm-legacy-equivalence/1` report stored inside the exact sensed checkout.

- `EQUIVALENT` + zero counterexamples => zero repair work.
- `COUNTEREXAMPLE` => one deterministic Ultracode item per witness.
- contradictory reports, malformed receipts, unsupported schemas, or authority
  above `OBSERVE` are refused.

Example profile:

```elixir
%{
  "type" => "legacy_recovery",
  "file" => "evidence/legacy-equivalence.json",
  "allowed_paths" => ["lib/**", "test/**"],
  "max_items" => 20
}
```

Register that profile name through `:ultracode_sensing_profiles` and bind the
repository entry's `sensing:` field to the same name. The existing Autonomic
fallback law then turns a failed/absent backlog script into semantic recovery
work without creating a second scheduler.

The worker is instructed to repair the candidate and rerun the same beam4pm
court. It may not weaken/delete the witness or change admitted semantics simply
to obtain a passing verdict.
