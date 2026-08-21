defmodule Xaas.Governance.FreezeWindowTest do
  @moduledoc """
  Real Chicago-style tests: real Ash actions against the real sandboxed
  Postgres (Xaas.Repo). No mocking. Proves the real AshIam read-bypass
  pilot extended onto `Xaas.Governance.FreezeWindow` this session (see
  that resource's own moduledoc) -- `:read` is now IAM-gated via
  `AshIam.Check`, replacing the previous open `authorize_if always()`
  bypass. `:create`/`:destroy` remain on their existing `authorize_if
  always()` bypasses, unchanged by this pass.
  """
  use ExUnit.Case, async: true

  alias Xaas.Governance.FreezeWindow

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create!(org_id_prefix) do
    now = DateTime.utc_now()

    FreezeWindow
    |> Ash.Changeset.for_create(:create, %{
      org_id: "#{org_id_prefix}-#{System.unique_integer([:positive])}",
      starts_at: now,
      ends_at: DateTime.add(now, 3600, :second),
      reason: "Real freeze window under test",
      created_by: "test-actor"
    })
    |> Ash.create!(authorize?: false)
  end

  test "a real freeze window can be created and read back via authorize?: false" do
    fw = create!("acme")
    assert fw.reason == "Real freeze window under test"

    persisted = FreezeWindow |> Ash.get!(fw.id, authorize?: false)
    assert persisted.org_id == fw.org_id
  end

  test "an actor with a real Allow statement can read via the real AshIam.Check policy" do
    fw = create!("readable")

    actor = %{
      iam_policy: %{
        "Statement" => [
          %{"Effect" => "Allow", "Action" => ["read"], "Resource" => ["xaas:freeze_window:*"]}
        ]
      }
    }

    results = FreezeWindow |> Ash.read!(actor: actor)
    assert Enum.any?(results, &(&1.id == fw.id))
  end

  test "an actor with no real iam_policy is really denied read -- not silently allowed" do
    fw = create!("hidden")

    results = FreezeWindow |> Ash.read!(actor: %{})
    refute Enum.any?(results, &(&1.id == fw.id))
  end

  test "an actor whose Allow statement names a different freeze window cannot read this one" do
    visible = create!("visible")
    other = create!("other")

    scoped_actor = %{
      iam_policy: %{
        "Statement" => [
          %{"Effect" => "Allow", "Action" => ["read"], "Resource" => ["xaas:freeze_window:#{visible.id}"]}
        ]
      }
    }

    results = FreezeWindow |> Ash.read!(actor: scoped_actor)
    assert Enum.any?(results, &(&1.id == visible.id))
    refute Enum.any?(results, &(&1.id == other.id))
  end

  test "a real caller can still create a freeze window (create bypass unchanged)" do
    fw = create!("create-ok")
    assert fw.org_id =~ "create-ok"
  end
end
