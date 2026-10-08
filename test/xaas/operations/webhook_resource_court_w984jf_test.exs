defmodule Xaas.Operations.WebhookResourceCourtW984jfTest do
  @moduledoc """
  Lane W984jf unclaimed-family probe: `Xaas.Platform.Webhook` resource/action
  layer (the `:create` verb was typed COVERED by W984ie; this court targets
  the residue the census found genuinely unexercised):

  - `update :update` (url / event_types / secret / enabled lifecycle) --
    no test in test/ ever calls it (grep census: only `for_create` and the
    delivery `:deliver`/`:record_attempt` actions are exercised).
  - `destroy :destroy` -- likewise never called against Webhook.
  - create-level `allow_nil?(false)` enforcement on org_id/url/secret.
  - the deny-always policy floor on the non-create verbs (W984bq only
    proved the refusal for `:create`).
  - secret rotation through `:update` re-encrypts at rest (cloak
    round-trip on the update path).

  Chicago-style: real sandboxed Postgres, real Ash actions, zero mocks.
  `authorize?: false` is the lawful fixture path here because the
  resource's own policy is deny-always with no bypass (proved for
  `:create` in platform_depth_w984bq; re-proved for :update/:destroy
  below) -- the state-bearing branches live behind that fixture gate.
  """

  use ExUnit.Case, async: true

  require Ash.Query

  alias Xaas.Platform.Webhook

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp uniq(prefix), do: "#{prefix}-#{System.unique_integer([:positive])}"

  defp create_hook!(attrs \\ %{}) do
    Webhook
    |> Ash.Changeset.for_create(
      :create,
      Map.merge(
        %{
          org_id: uniq("org"),
          url: "https://receiver.example/#{uniq("hook")}",
          event_types: ["order.created"],
          secret: "hmac-" <> uniq("secret"),
          enabled: true
        },
        attrs
      )
    )
    |> Ash.create!(authorize?: false)
  end

  # ------------------------------------------------------------------
  # (1) update :update -- enable/disable lifecycle round-trips
  # Mutation rationale: `enabled` has allow_nil?(false) + default(true);
  # nothing in test/ ever drives :update, so a regression that drops
  # `:enabled` from the accept list (or breaks the update persist) would
  # pass the entire existing suite.
  # ------------------------------------------------------------------
  test "(1) :update toggles enabled both directions and persists" do
    hook = create_hook!()
    assert hook.enabled == true

    disabled =
      hook
      |> Ash.Changeset.for_update(:update, %{enabled: false}, authorize?: false)
      |> Ash.update!()

    assert disabled.enabled == false

    reloaded = Ash.get!(Webhook, hook.id, authorize?: false)
    assert reloaded.enabled == false

    reenabled =
      reloaded
      |> Ash.Changeset.for_update(:update, %{enabled: true}, authorize?: false)
      |> Ash.update!()

    assert reenabled.enabled == true
    assert Ash.get!(Webhook, hook.id, authorize?: false).enabled == true
  end

  # ------------------------------------------------------------------
  # (2) update :update -- url rotation + event_types rewrite
  # Mutation rationale: url/event_types are accepted on update only;
  # killing the accept list entry or the persist must fail this test.
  # ------------------------------------------------------------------
  test "(2) :update rotates url and rewrites event_types" do
    hook = create_hook!(%{event_types: ["order.created"]})

    new_url = "https://receiver2.example/#{uniq("rot")}"

    updated =
      hook
      |> Ash.Changeset.for_update(
        :update,
        %{url: new_url, event_types: ["invoice.paid", "order.refunded"]},
        authorize?: false
      )
      |> Ash.update!()

    assert updated.url == new_url
    assert updated.event_types == ["invoice.paid", "order.refunded"]

    reloaded = Ash.get!(Webhook, hook.id, authorize?: false)
    assert reloaded.url == new_url
    assert Enum.sort(reloaded.event_types) == ["invoice.paid", "order.refunded"]
    # org_id is NOT accepted on :update -- an attempt to move orgs must be rejected
    assert_raise(Ash.Error.Invalid, fn ->
      hook
      |> Ash.Changeset.for_update(:update, %{org_id: uniq("other-org")}, authorize?: false)
      |> Ash.update!()
    end)
  end

  # ------------------------------------------------------------------
  # (3) secret rotation through :update re-encrypts at rest
  # Mutation rationale: cloak applies to update too; dropping the cloak
  # on the update path (or storing plaintext) is caught only here.
  # ------------------------------------------------------------------
  test "(3) secret rotation via :update stores ciphertext, not plaintext, and decrypts to the new secret" do
    known_secret = "initial-" <> uniq("hmac")
    hook = create_hook!(%{secret: known_secret})
    old_secret = known_secret

    # baseline: initial secret encrypted at rest
    %{rows: [row0]} =
      Ecto.Adapters.SQL.query!(Xaas.Repo, "SELECT encrypted_secret FROM platform_webhooks WHERE id = $1", [
        Ecto.UUID.dump!(hook.id)
      ])

    assert [enc0] = row0
    assert is_binary(enc0) and enc0 != ""
    refute String.contains?(enc0, old_secret)

    new_secret = "rotated-" <> uniq("hmac")


    updated =
      hook
      |> Ash.Changeset.for_update(:update, %{secret: new_secret}, authorize?: false)
      |> Ash.update!()

    %{rows: [row1]} =
      Ecto.Adapters.SQL.query!(Xaas.Repo, "SELECT encrypted_secret FROM platform_webhooks WHERE id = $1", [
        Ecto.UUID.dump!(hook.id)
      ])

    assert [enc1] = row1
    assert is_binary(enc1) and enc1 != ""
    refute String.contains?(enc1, new_secret)
    refute String.contains?(enc1, old_secret)
    refute inspect(updated) |> String.contains?(new_secret)

    reloaded = Ash.get!(Webhook, hook.id, authorize?: false)
    reloaded_secret = Map.get(reloaded, :secret)

    if is_binary(reloaded_secret) do
      assert reloaded_secret == new_secret
    else
      decrypted =
        Ash.load!(reloaded, :secret, authorize?: false)
        |> Map.get(:secret)

      assert decrypted == new_secret
    end
  end

  # ------------------------------------------------------------------
  # (4) destroy :destroy removes the row
  # Mutation rationale: the primary destroy is JSON:API-exposed; nothing
  # in test/ ever calls it, so a broken destroy (or one that silently
  # leaves the row) passes the existing suite.
  # ------------------------------------------------------------------
  test "(4) :destroy removes the webhook row" do
    hook = create_hook!()

    assert :ok = Ash.destroy!(hook, authorize?: false)

    refute match?({:ok, _}, Ash.get(Webhook, hook.id, authorize?: false))
    assert Webhook |> Ash.Query.filter(org_id: hook.org_id) |> Ash.count!(authorize?: false) == 0
  end

  # ------------------------------------------------------------------
  # (5) create-level required attributes are enforced
  # Mutation rationale: allow_nil?(false) on org_id/url/secret is real
  # state-bearing validation; no test asserts it is load-bearing.
  # ------------------------------------------------------------------
  test "(5) :create refuses nil org_id, nil url, and nil secret" do
    for attr <- [:org_id, :url, :secret] do
      assert_raise(Ash.Error.Invalid, fn ->
        Webhook
        |> Ash.Changeset.for_create(:create, Map.delete(base_attrs(), attr), authorize?: false)
        |> Ash.create!()
      end)
    end

    # event_types has default([]) -- omission (not nil) falls to the
    # default and lands.
    hook =
    hook =
      Webhook
      |> Ash.Changeset.for_create(:create, Map.delete(base_attrs(), :event_types), authorize?: false)
      |> Ash.create!()

    assert hook.event_types == []
  end

  # ------------------------------------------------------------------
  # (6) policy floor on the non-create verbs
  # Mutation rationale: W984bq proved deny-always only for :create. If
  # someone adds an unauthorized bypass for :update/:destroy/:read, no
  # existing test fails.
  # ------------------------------------------------------------------
  test "(6) deny-always policy refuses :update, :destroy, and :read for every actor shape" do
    actors = [
      %{org_id: uniq("org")},
      Xaas.SystemAuthority.new(:internal_api)
    ]

    hook = create_hook!()

    for actor <- actors do
      assert_raise(Ash.Error.Forbidden, fn ->
        hook
        |> Ash.Changeset.for_update(:update, %{enabled: false}, actor: actor, authorize?: true)
        |> Ash.update!()
      end)

      assert_raise(Ash.Error.Forbidden, fn ->
        Ash.destroy!(hook, actor: actor, authorize?: true)
      end)

      # reads are filtered (not forbidden) under a deny policy: the
      # authorized read returns an empty list, never the row.
      assert [] ==
               Ash.read!(Webhook |> Ash.Query.filter(org_id: hook.org_id),
                 actor: actor,
                 authorize?: true
               )
    end

    # refused verbs left the row untouched
    assert Ash.get!(Webhook, hook.id, authorize?: false).enabled == true
  end

  defp base_attrs do
    %{
      org_id: uniq("org"),
      url: "https://receiver.example/#{uniq("base")}",
      event_types: ["order.created"],
      secret: "hmac-" <> uniq("secret"),
      enabled: true
    }
  end
end
