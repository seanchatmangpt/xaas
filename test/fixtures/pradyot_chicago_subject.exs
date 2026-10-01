%{
  subject: "urn:chicago:agentic-payment:purchase-001",
  invariants: [
    :exact_subject_identity,
    :delegation_limit_refusal,
    :principal_refusal,
    :expiry_refusal,
    :pre_dispatch_replan,
    :unknown_after_dispatch_no_replay,
    :evidence_required_for_standing,
    :stale_receipt_refusal,
    :policy_drift_invalidates_plan,
    :projection_has_no_authority
  ]
}
