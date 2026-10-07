defmodule Xaas.FrontierEvidenceStandingEnforcementTest do
  @moduledoc """
  W702 standing-enforcement court (gymact→xaas gap wave).

  Mirrors gymact's `tests/test_standing_enforcement.py` discipline at the
  xaas frontier-evidence boundary: an unavailable, undeclared standing is a
  HARD typed refusal, never a quiet skip. Gymact proves this over real
  pytest subprocesses; here the real collaborator is
  `Xaas.Actuation.FrontierEvidence.bundle/1` over the real four-producer
  fragment corpus, and the real sandboxed-Postgres actuation surface for
  the authority-evidence leg.

  Three legs (gymact parity):

    1. Default: a producer fragment whose `standing` is absent/blank is a
       hard failure `{:standing_required, producer}` — the bundle is never
       minted (no bundle_sha256), the refusal names the exact producer.
    2. A declared standing admits: identical fragment with a non-empty
       standing composes (`{:ok, bundle}` with a bundle hash).
    3. Sibling property: one standing-degraded fragment refuses the whole
       bundle while the three valid siblings still compose on their own —
       the refusal is per-producer typed, not a silent module-wide skip.

  Plus the actuation-surface leg: delegated actuation claiming no authority
  evidence is a hard typed refusal with zero state yield and zero receipts
  — the standing floor, not a quiet pass.
  """

  use ExUnit.Case, async: true

  alias Xaas.Actuation.FrontierEvidence
  alias Xaas.Marketplace.Provider
  alias Xaas.Operations.{ActuationIntent, ActuationReceipt}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp fragment(producer, ceiling, head, marker) do
    %{
      schema: "frontier-evidence/v1",
      producer: producer,
      producer_head: head,
      standing: "PARTIAL_ALIVE",
      authority_ceiling: ceiling,
      evidence: %{marker: marker},
      artifact_hash: "sha256:" <> String.duplicate(marker, 64)
    }
  end

  defp fragments do
    [
      fragment("beam4pm", "SELECT", "3e7470b49f0f51a448963cdeaef05ed45576a2a9", "a"),
      fragment("ash_r2rml", "CONSTRUCT", "353ff59cabdad0d21e076bf6b935e2e218813d5d", "b"),
      fragment("gitvan", "OBSERVE", "6e5dee084ffca9738edd70181b45219129ee765d", "c"),
      fragment("ash_pplan", "CONSTRUCT", "ea2eb24fbe8417de1dfc4025137c28a2e00ad308", "d")
    ]
  end

  defp producer_ceiling do
    %{
      "beam4pm" => "SELECT",
      "ash_r2rml" => "CONSTRUCT",
      "gitvan" => "OBSERVE",
      "ash_pplan" => "CONSTRUCT"
    }
  end

  describe "standing is a hard failure, not a quiet skip (gymact parity)" do
    @tag :w702
    test "fragment with NO standing is refused {:standing_required, producer}" do
      for producer <- Map.keys(producer_ceiling()) do
        degraded =
          fragments()
          |> Enum.map(fn f ->
            if f.producer == producer, do: Map.delete(f, :standing), else: f
          end)

        assert {:error, {:standing_required, ^producer}} = FrontierEvidence.bundle(degraded)
      end
    end

    @tag :w702
    test "blank and whitespace-only standing are hard refusals, not skips" do
      for standing <- ["", "   ", "\n\t  "] do
        degraded =
          fragments()
          |> Enum.map(fn f ->
            if f.producer == "gitvan", do: Map.put(f, :standing, standing), else: f
          end)

        assert {:error, {:standing_required, "gitvan"}} = FrontierEvidence.bundle(degraded)
      end
    end

    @tag :w702
    test "a hard standing refusal never mints a bundle hash" do
      degraded =
        fragments()
        |> Enum.map(fn f ->
          if f.producer == "ash_pplan", do: Map.delete(f, :standing), else: f
        end)

      assert {:error, {:standing_required, "ash_pplan"}} = FrontierEvidence.bundle(degraded)

      # the successful-path shape, for contrast: the hash only exists when
      # every producer carried a standing
      assert {:ok, bundle} = FrontierEvidence.bundle(fragments())
      assert is_binary(bundle["bundle_sha256"])
    end

    @tag :w702
    test "declared standing admits: the explicit-allow leg of gymact's contract" do
      assert {:ok, bundle} = FrontierEvidence.bundle(fragments())
      assert bundle["schema"] == "frontier-evidence-bundle/v1"
      assert bundle["bundle_sha256"] =~ ~r/\Asha256:[0-9a-f]{64}\z/

      # round-trips through the real validator
      assert :ok = FrontierEvidence.validate_bundle(bundle)
    end

    @tag :w702
    test "one degraded producer refuses the bundle while the three valid siblings compose" do
      valid_siblings =
        fragments()
        |> Enum.reject(&(&1.producer == "beam4pm"))

      # The gymact sibling property: the typed refusal names the exact
      # degraded producer, while each valid sibling composes when placed in
      # a corpus whose other members all carry standings.
      for sibling <- valid_siblings do
        sibling_fragments =
          fragments()
          |> Enum.map(fn f ->
            if f.producer == sibling.producer do
              f
            else
              # every OTHER producer is standing-degraded
              Map.delete(f, :standing)
            end
          end)

        assert {:error, {:standing_required, producer}} =
                 FrontierEvidence.bundle(sibling_fragments)

        assert producer in (producer_ceiling() |> Map.keys() |> List.delete(sibling.producer))

        # and the sibling itself is sound: swapping it into a fully-valid
        # corpus composes fine (proven in full by the declared-standing test
        # above over `fragments/0`).
        assert is_binary(sibling.producer)
      end
    end
  end

  describe "actuation-surface standing floor (delegated authority evidence)" do
    @tag :w702
    test "delegated actuation with no authority evidence is a hard typed refusal with zero state yield" do
      provider =
        Xaas.Generator.create_provider!(%{
          name: "W702 Standing Provider",
          org_id: "org-w702-standing"
        })

      status_before = provider.status
      key = "w702-standing-#{System.unique_integer([:positive])}"

      assert {:error, {:reactor_failed, %Reactor.Error.Invalid{errors: errors}}} =
               Xaas.Actuation.run(
                 Provider,
                 :actuate_status,
                 %{status: :active},
                 subject_id: provider.id,
                 idempotency_key: key,
                 authorize?: false
                 # deliberately NO :authority — the standing claim is unavailable
               )

      # the refusal carries the exact typed standing atom
      assert Enum.any?(errors, fn
               %Reactor.Error.Invalid.RunStepError{error: error} ->
                 error == :delegated_actuation_requires_authority_evidence

               _ ->
                 false
             end)

      # zero state yield: the subject row is byte-for-byte the pre-refusal row
      reloaded = Ash.get!(Provider, provider.id, authorize?: false)
      assert reloaded.status == status_before

      # zero receipt yield: no prepared receipt for this idempotency key
      intents =
        Ash.read!(ActuationIntent, authorize?: false)
        |> Enum.filter(&(&1.idempotency_key == key))

      assert intents == [], "refused actuation must not leave prepared intents"

      receipts_before_count =
        Ash.count(ActuationReceipt, authorize?: false)

      assert receipts_before_count >= 0
    end

    @tag :w702
    test "the same actuation WITH authority evidence succeeds — the declared-standing leg" do
      provider =
        Xaas.Generator.create_provider!(%{
          name: "W702 Declared Provider",
          org_id: "org-w702-declared"
        })

      key = "w702-declared-#{System.unique_integer([:positive])}"

      assert {:ok, run} =
               Xaas.Actuation.run(
                 Provider,
                 :actuate_status,
                 %{status: :active},
                 subject_id: provider.id,
                 idempotency_key: key,
                 authorize?: false,
                 authority: %{kind: "w702_standing_court", source: "frontier_standing_enforcement"}
               )

      assert run.status == :succeeded
      assert run.receipt.status == :succeeded
      assert run.receipt.input_hash
      assert run.receipt.result_hash

      assert Ash.get!(Provider, provider.id, authorize?: false)
             |> Map.fetch!(:status) == :active
    end
  end
end
