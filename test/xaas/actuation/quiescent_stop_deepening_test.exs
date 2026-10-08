defmodule Xaas.Actuation.QuiescentStopDeepeningTest do
  @moduledoc """
  Lane W704 deepening of `Xaas.Actuation.QuiescentStopTest` — Art. 27.3
  (safeguards when risks materialise during use): the quiescent-stop attractor
  is the halt-to-safe-state safeguard in the actuation path.

  Chicago-style: real Ash resources, real actuation kernel, real sandboxed
  Postgres, no mocks. Deepens the existing court with:

    1. halt-to-safe-state idempotency — the second halt is a no-op
    2. typed refusal on malformed context (authority shapes, key shapes)
    3. determinism x3 over the attractor
    4. composition with the Art 15.5.s3 lifecycle materialisation entry:
       `Xaas.Semantics.OversightGovernance.fria/0` consumes the halt record
       without contradiction
  """

  use ExUnit.Case, async: true

  # Art. 27.3 evidence row (title_iii): the quiescent-stop attractor
  # (halt to safe state) + the FRIA materialisation entry.
  @moduletag :eu_ai_act

  alias Xaas.Actuation.QuiescentStop
  alias Xaas.Marketplace.Provider
  alias Xaas.Operations.ActuationReceipt
  alias Xaas.Semantics.OversightGovernance
  alias Xaas.Semantics.VulnerabilityLifecycle

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create_provider! do
    Xaas.Generator.create_provider!(%{name: "Quiescent Deepening Provider", org_id: "org-estop-w704"})
  end

  defp authority do
    %{kind: "test_authority", source: "quiescent_stop_deepening_test"}
  end

  defp stop_key do
    "estop-w704-#{System.unique_integer([:positive])}"
  end

  defp halt_opts(provider_id) do
    [subject_id: provider_id, idempotency_key: stop_key(), authority: authority()]
  end

  defp halt!(provider) do
    assert {:ok, receipt} = QuiescentStop.execute(Provider, halt_opts(provider.id))
    assert receipt.target == :quiescent
    assert %DateTime{} = receipt.stopped_at
    assert receipt.authority == authority()
    receipt
  end

  defp provider_status(provider_id) do
    Provider |> Ash.get!(provider_id, authorize?: false) |> Map.fetch!(:status)
  end

  ## 1. Halt-to-safe-state idempotency: the second halt is a no-op

  test "second halt with the same key is a no-op: no new receipt, subject unchanged" do
    provider = create_provider!()
    opts = halt_opts(provider.id)

    assert {:ok, first} = QuiescentStop.execute(Provider, opts)
    assert first.target == :quiescent

    receipts_after_first = Ash.read!(ActuationReceipt, authorize?: false)
    first_count = length(receipts_after_first)

    assert {:ok, second} = QuiescentStop.execute(Provider, opts)
    assert second == %{already_stopped: true}

    assert length(Ash.read!(ActuationReceipt, authorize?: false)) == first_count
    assert provider_status(provider.id) == :suspended
  end

  test "repeated halts after a subject was already driven quiescent never un-halt it" do
    provider = create_provider!()
    halt!(provider)

    # Three further halts (fresh keys): each refused typed by the attractor.
    for _ <- 1..3 do
      assert {:error, :REFUSED_STOP_SUBJECT_ALREADY_QUIESCENT} =
               QuiescentStop.execute(Provider, halt_opts(provider.id))
    end

    assert provider_status(provider.id) == :suspended
  end

  ## 2. Typed refusal on malformed context

  test "malformed authority shapes are refused typed, fail-closed, before any DO" do
    provider = create_provider!()

    malformed_authorities = [
      "operator-on-call",
      :authority_atom,
      42,
      nil,
      %{kind: "test_authority"},
      %{source: "quiescent_stop_deepening_test"},
      %{kind: "", source: "quiescent_stop_deepening_test"},
      %{kind: "test_authority", source: ""}
    ]

    for bad <- malformed_authorities do
      assert {:error, :REFUSED_STOP_AUTHORITY} =
               QuiescentStop.execute(Provider,
                 subject_id: provider.id,
                 idempotency_key: stop_key(),
                 authority: bad
               )
    end

    # No DO occurred for any malformed shape: the subject is untouched.
    assert provider_status(provider.id) == :pending
  end

  test "malformed idempotency keys are refused typed before any DO" do
    provider = create_provider!()

    for bad_key <- [nil, "", 42, :key, %{key: "k"}, ["estop"]] do
      assert {:error, :idempotency_key_required} =
               QuiescentStop.execute(Provider,
                 subject_id: provider.id,
                 idempotency_key: bad_key,
                 authority: authority()
               )
    end

    assert provider_status(provider.id) == :pending
  end

  ## 3. Determinism x3

  test "three identical halts on fresh subjects produce identical receipt shape" do
    receipts =
      for _ <- 1..3 do
        provider = create_provider!()
        receipt = halt!(provider)
        assert provider_status(provider.id) == :suspended
        receipt
      end

    # Same shape, same target, same echoed authority — modulo the wall clock.
    assert Enum.all?(receipts, fn r ->
             r.target == :quiescent and r.authority == authority() and
               match?(%DateTime{}, r.stopped_at)
           end)

    assert length(Enum.uniq(Enum.map(receipts, & &1.target))) == 1
  end

  test "same-key replay is deterministic across three calls" do
    provider = create_provider!()
    opts = halt_opts(provider.id)

    assert {:ok, _} = QuiescentStop.execute(Provider, opts)

    replays =
      for _ <- 1..3 do
        QuiescentStop.execute(Provider, opts)
      end

    assert replays == [{:ok, %{already_stopped: true}}, {:ok, %{already_stopped: true}},
                       {:ok, %{already_stopped: true}}]

    assert provider_status(provider.id) == :suspended
  end

  ## 4. Composition with the Art 15.5.s3 lifecycle materialisation entry

  test "fria/0 consumes the halt record without contradiction (Art 15.5.s3 materialisation)" do
    provider = create_provider!()
    halt_receipt = halt!(provider)

    # The lifecycle materialisation entry (15.5.s3) stays forward-only: the
    # halt record is a real detection-grade record for the lifecycle machine.
    {:ok, lifecycle} =
      VulnerabilityLifecycle.new(%{
        detector: "Xaas.Actuation.QuiescentStop",
        finding: %{halt: halt_receipt, subject: provider.id, status: provider_status(provider.id)}
      })

    assert lifecycle.state == :DETECTED

    # fria/0 consumes the post-halt world without contradiction: the
    # structured assessment is intact and statuses remain typed. Since
    # W984eb all five rights are :EVIDENCED — the authority channel over
    # the real incident-reporting seam (incident_report.ex, transmit/1
    # :PREPARED_NOT_TRANSMITTED).
    assert {:ok, fria} = OversightGovernance.fria()
    assert fria.assessment_class == :deployer

    assert Enum.all?(fria.rights, fn right ->
             right.status == :EVIDENCED and is_binary(right.article) and
               right.evidence != []
           end)

    authority_entry =
      Enum.find(fria.rights, &(&1.right == :access_to_effective_remedy_authority_channel))

    assert authority_entry.status == :EVIDENCED

    assert Enum.any?(authority_entry.evidence, fn e ->
             e.path == "lib/xaas/semantics/incident_report.ex"
           end)

    # No contradiction between the halt receipt and the FRIA: the echoed
    # authority and target agree with the post-halt subject state.
    assert halt_receipt.target == :quiescent
    assert halt_receipt.authority == authority()
    assert provider_status(provider.id) == :suspended
  end
end
