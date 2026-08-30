defmodule Xaas.Telemetry.OcelAshEmitterTest do
  @moduledoc """
  Real Chicago-style coverage for `Xaas.Telemetry.OcelAshEmitter`'s
  `declared_relationship_types` vmap enrichment: real `:telemetry` events
  from a real Ash action against a real resource with a real declared
  `belongs_to` relationship (`Xaas.Marketplace.ApprovalProviderStatusChange
  belongs_to :provider`), read back from the real OCEL log file. No
  mocking of Ash, telemetry, or file I/O.
  """
  use ExUnit.Case, async: false

  alias Xaas.Marketplace.{ApprovalProviderStatusChange, Provider}
  alias Xaas.Telemetry.OcelAshEmitter

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create_provider!(org_id) do
    Provider
    |> Ash.Changeset.for_create(:create, %{
      name: "Emitter Test Provider",
      slug: "provider-emitter-#{System.unique_integer([:positive])}",
      org_id: org_id
    })
    |> Ash.create!(authorize?: false)
  end

  test "a real action on a resource with a real declared belongs_to relationship emits its type in vmap, not as a fabricated omap object" do
    org_id = "org-emitter-test-#{System.unique_integer([:positive])}"
    provider = create_provider!(org_id)

    ApprovalProviderStatusChange
    |> Ash.Changeset.for_create(:create, %{
      org_id: org_id,
      provider_id: provider.id,
      requested_by: "requester-emitter-test",
      requested_status: :active
    })
    |> Ash.create!(authorize?: false)

    real_event =
      OcelAshEmitter.log_path()
      |> File.stream!()
      |> Enum.map(&Jason.decode!/1)
      |> Enum.reverse()
      |> Enum.find(fn %{"ocel:activity" => activity} ->
        activity == "approval_provider_status_change.create"
      end)

    refute is_nil(real_event),
           "expected a real approval_provider_status_change.create OCEL event in the real log"

    declared = real_event["ocel:vmap"]["declared_relationship_types"]

    assert is_list(declared)
    assert Enum.any?(declared, &String.starts_with?(&1, "provider:belongs_to->"))

    # The declared-relationship enrichment lives in vmap only -- it must
    # never leak into ocel:omap as if it were confirmed instance
    # participation (the real, disclosed limit: Ash's :stop telemetry
    # metadata carries no changeset/result, so no instance-level FK value
    # is available to this module at all).
    refute Enum.any?(real_event["ocel:omap"], &String.contains?(&1, "belongs_to"))
  end
end
