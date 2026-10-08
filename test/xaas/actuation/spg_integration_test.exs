defmodule Xaas.Actuation.SpgIntegrationTest do
  @moduledoc """
  Integration court for the SpgGate seam (W984dq5 work order §3) — the
  gate's first and only caller in `Kernel.do_admit/2`, exercised through
  the real product path: real `Xaas.Actuation.run/4` /
  `prepare_external/4` over real sandboxed Postgres, real Reactor, no
  mocks. Each case kills a named mutant class per the work order.
  """

  use ExUnit.Case, async: true

  alias Xaas.Marketplace.Provider
  alias Xaas.Operations.{ActuationIntent, ActuationReceipt}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create_provider! do
    Xaas.Generator.create_provider!(%{name: "SPG Integration Provider", org_id: "org-spg"})
  end

  defp run_opts(spg, extra \\ []) do
    defaults = [
      subject_id: nil,
      idempotency_key: "spg-integration-#{System.unique_integer([:positive])}",
      authorize?: false,
      authority: %{kind: "test_authority", source: "spg_integration_test", spg: spg}
    ]

    Keyword.merge(defaults, Keyword.delete(extra, :authority))
  end

  defp atom_identity(overrides \\ %{}) do
    Map.merge(
      %{
        graph_id: "spg-graph-1",
        graph_version: "v26.10.6",
        node_id: "node-a",
        edge_id: "edge-1",
        state: :admitted
      },
      overrides
    )
  end

  test "1. opt-in no-op: run/4 without a :spg key behaves exactly as before" do
    # Kills gate-mandatory mutants (gate consulted unconditionally).
    provider = create_provider!()
    key = "spg-noop-#{System.unique_integer([:positive])}"

    assert {:ok, first} =
             Xaas.Actuation.run(Provider, :actuate_status, %{status: :active},
               subject_id: provider.id,
               idempotency_key: key,
               authorize?: false,
               authority: %{kind: "test_authority", source: "spg_integration_test"}
             )

    assert first.status == :succeeded
    assert Provider |> Ash.get!(provider.id, authorize?: false) |> Map.fetch!(:status) == :active
  end

  test "2. gate-open DO: admitted :spg identity lets DO execute to a :succeeded receipt" do
    # Kills inverted-gate mutants (gate open but DO refused, or vice versa).
    provider = create_provider!()

    assert {:ok, result} =
             Xaas.Actuation.run(Provider, :actuate_status, %{status: :active},
               run_opts(atom_identity(), subject_id: provider.id)
             )

    assert result.status == :succeeded
    refute result.replay?
    assert result.receipt.status == :succeeded
  end

  test "3. gate-refused DO: unadmitted identity refuses typed, with NO intent/receipt rows" do
    # Kills fail-open and non-typed-refusal mutants; also proves the
    # refusal happens in do_admit/2's `with` (before find_or_create),
    # not inside the Reactor :do step.
    provider = create_provider!()
    key = "spg-refused-#{System.unique_integer([:positive])}"
    intents_before = length(Ash.read!(ActuationIntent, authorize?: false))
    receipts_before = length(Ash.read!(ActuationReceipt, authorize?: false))

    assert {:error, {:spg_gate_refused, :spg_not_admitted}} =
             Xaas.Actuation.run(Provider, :actuate_status, %{status: :active},
               subject_id: provider.id,
               idempotency_key: key,
               authorize?: false,
               authority: %{
                 kind: "test_authority",
                 source: "spg_integration_test",
                 spg: atom_identity(%{state: "PENDING"})
               }
             )

    assert length(Ash.read!(ActuationIntent, authorize?: false)) == intents_before
    assert length(Ash.read!(ActuationReceipt, authorize?: false)) == receipts_before
  end

  test "4. incomplete identity: missing node_id refuses :spg_identity_required" do
    # Kills required-field-relaxation mutants.
    provider = create_provider!()

    assert {:error, {:spg_gate_refused, :spg_identity_required}} =
             Xaas.Actuation.run(Provider, :actuate_status, %{status: :active},
               run_opts(atom_identity(%{node_id: nil}), subject_id: provider.id)
             )
  end

  test "5. string-keyed identity body is the gate's own normalize contract, not the seam's" do
    # Kills wrong-layer-tolerance mutants: SpgGate.admit/1 normalizes
    # string-keyed identity FIELDS, so a string-keyed body opens the
    # gate — while the seam's `:spg` KEY itself stays atom-only (a
    # string "spg" key in the authority map is ignored entirely, next
    # case).
    provider = create_provider!()

    assert {:ok, result} =
             Xaas.Actuation.run(Provider, :actuate_status, %{status: :active},
               run_opts(
                 %{
                   "graph_id" => "spg-graph-1",
                   "graph_version" => "v26.10.6",
                   "node_id" => "node-a",
                   "edge_id" => "edge-1",
                   "state" => "ADMITTED"
                 },
                 subject_id: provider.id
               )
             )

    assert result.status == :succeeded
  end

  test "6. F2 witness from the integration side: fingerprint_token/1 typed refusal" do
    # Witnesses the F2 refinement through the gate module used by the
    # seam; the amended unit-court test 5 covers it from the unit side.
    alias Xaas.Actuation.SpgGate

    assert {:error, :spg_fingerprint_atom_keyed} =
             SpgGate.fingerprint_token(%{
               "graph_id" => "g",
               "graph_version" => "1",
               "node_id" => "n",
               "edge_id" => "e"
             })

    assert {:ok, projected} = SpgGate.admit(atom_identity())
    assert is_tuple(SpgGate.fingerprint_token(projected))
  end

  test "7. external path parity: prepare_external/4 refuses through the same single funnel" do
    # Kills seam-coverage mutants — proves Kernel.do_admit/2 is the one
    # funnel for BOTH transactional and external admission.
    provider = create_provider!()

    assert {:error, {:external_admission_failed, {:spg_gate_refused, :spg_not_admitted}}} =
             Xaas.Actuation.prepare_external(Provider, :actuate_status, %{status: :active},
               run_opts(atom_identity(%{state: "PENDING"}), subject_id: provider.id)
             )
  end

  test "bonus: string \"spg\" authority key is ignored (fail-closed-by-absence, not a bypass)" do
    # Pins rule 4 of the work order §1: the atom-key-only channel. A
    # string-keyed "spg" is IGNORED (no gate), so DO proceeds — the
    # deliberate fail-closed-by-absence posture. This test would fail on
    # any mutant adding a string-key fallback at the seam.
    provider = create_provider!()
    key = "spg-stringkey-#{System.unique_integer([:positive])}"

    assert {:ok, result} =
             Xaas.Actuation.run(Provider, :actuate_status, %{status: :active},
               subject_id: provider.id,
               idempotency_key: key,
               authorize?: false,
               authority: %{:kind => "test_authority", :source => "spg_integration_test", "spg" => atom_identity(%{state: "PENDING"})}
             )

    assert result.status == :succeeded
  end
end
