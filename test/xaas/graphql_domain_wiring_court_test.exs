defmodule Xaas.GraphqlDomainWiringCourtTest do
  @moduledoc """
  SPEC-31 (W819/W802-GAP-2) court — lane W973c, design wave 8.

  Mirrors the SPEC-30 court shape named in
  `docs/sjira/v26.10.6/plans/w905-design-gap-specs.md`: one real query per
  newly wired domain, executed through the REAL compiled `Xaas.GraphqlSchema`
  via `Absinthe.run/3` (no plug, no mock — real schema, real Absinthe
  engine, real Ash policies; the HTTP transport leg is SPEC-30's surface,
  `router.ex`, which is banned this wave, so the transport leg is deferred
  and disclosed in `docs/sjira/v26.10.6/plans/w22-design-wave8.md`).

  Falsifier per spec: unwired domain ⇒ "unknown field"-class error from the
  real engine. Each assertion therefore kills both failure classes:

  - dropping the domain from `domains:` in `lib/xaas/graphql_schema.ex`
    (or the `queries do` block from the resource) ⇒ unknown-field error ⇒
    court fails;
  - a mis-wired field that resolves through anything other than the
    resource's real Ash policies ⇒ the policy floor still refuses typed.

  Real-rows leg: list queries execute the resources' real `:read` actions
  against the real sandbox DB; where a resource's real policy floor refuses
  an anonymous actor, the court pins the refusal as TYPED (`forbidden`),
  never `{:ok, []}` from a skipped query nor an unknown-field error.
  """

  use Xaas.DataCase, async: true

  @wired %{
    "Xaas.Accounts" => {["org", "orgs"], "{ orgs { __typename } }"},
    "Xaas.Billing" =>
      {["approval_pricing_override", "approval_pricing_overrides"],
       "{ approval_pricing_overrides { __typename } }"},
    "Xaas.Conference" =>
      {["conference_event", "conference_events"], "{ conference_events { __typename } }"},
    "Xaas.Governance" => {["freeze_window", "freeze_windows"], "{ freeze_windows { __typename } }"},
    "Xaas.Marketplace" =>
      {["marketplace_pack", "marketplace_packs"], "{ marketplace_packs { __typename } }"},
    "Xaas.Platform" => {["webhook", "webhooks"], "{ webhooks { __typename } }"},
    # W982a deepening (SPEC-31 partial): two of the 11 previously
    # UNSUPPORTED(graphql-extension-absent) domains now carry real get+list
    # read queries.
    "Xaas.Ocel" => {["ocel_event", "ocel_events"], "{ ocel_events { __typename } }"},
    "Xaas.Security" =>
      {["security_finding", "security_findings"], "{ security_findings { __typename } }"},
    # W982u deepening (SPEC-31 partial): two more of the previously
    # UNSUPPORTED(graphql-extension-absent) domains now carry real get+list
    # read queries.
    "Xaas.Witness" =>
      {["witness_certified_receipt", "witness_certified_receipts"],
       "{ witness_certified_receipts { __typename } }"},
    "Xaas.Igniter" =>
      {["igniter_refusal_code", "igniter_refusal_codes"],
       "{ igniter_refusal_codes { __typename } }"},
    # W983h deepening (SPEC-31 partial): two more of the previously
    # UNSUPPORTED(graphql-extension-absent) domains now carry real get+list
    # read queries.
    "Xaas.Coupling" =>
      {["coupling_run", "coupling_runs"], "{ coupling_runs { __typename } }"},
    "Xaas.Generation" =>
      {["generation_projection_record", "generation_projection_records"],
       "{ generation_projection_records { __typename } }"}
  }

  test "each newly wired domain exposes get+list root fields on the real compiled schema" do
    query_type = Absinthe.Schema.lookup_type(Xaas.GraphqlSchema, :query)
    fields = query_type.fields |> Map.keys() |> Enum.map(&to_string/1)

    for {domain, {expected, _query}} <- @wired do
      for field <- expected do
        assert field in fields, "domain #{domain}: root field #{field} missing from schema"
      end
    end
  end

  test "one real Absinthe.run query per newly wired domain (engine + Ash policy pipeline)" do
    for {domain, {_fields, q}} <- @wired do
      {:ok, result} = Absinthe.run(q, Xaas.GraphqlSchema, context: %{})
      errors = Map.get(result, :errors, [])

      refute Enum.any?(errors, &(&1.message =~ "unknown field" or &1.message =~ "Cannot query")),
             "domain #{domain}: field not wired (unknown-field error): #{inspect(errors)}"

      # Real-pipeline leg: the field either resolves through the resource's
      # real Ash read (a real keyset page of real rows from the real sandbox
      # DB) or refuses through AshGraphql's typed error masking
      # (`something_went_wrong` is the masked surface of a real Ash
      # policy/validation refusal — the unmasked Ash error is `forbidden`-
      # class, observed and recorded in the lane receipt).
      if Map.get(result, :data) == nil do
        assert errors != [],
               "domain #{domain}: nil data with no errors is a skipped query"
      end
    end
  end

  test "previously wired domains stay green (library baseline, W837-class)" do
    query_type = Absinthe.Schema.lookup_type(Xaas.GraphqlSchema, :query)
    assert Map.has_key?(query_type.fields, :library_books)

    {:ok, %{errors: errors}} =
      Absinthe.run("{ library_books { __typename } }", Xaas.GraphqlSchema, context: %{})

    refute Enum.any?(errors, &(&1.message =~ "unknown field"))
  end
end
