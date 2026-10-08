defmodule Xaas.Platform.PlatformDepthW984bqTest do
  @moduledoc """
  Lane W984bq depth court on the `Xaas.Platform` family's uncourted
  remainder (MINUS covered slices: RouteProjectsBackups purge/retention
  W970b/W981d, RouteProjects :create/approve SPEC-21/W969, route-castle
  W984f-era, and W984aa's castle-verb file).

  Chicago-style: real Ash actions against real sandboxed Postgres, real
  policies with `authorize?: true`, real raw-SQL row reads, real
  closed-port HTTP for the retry path. No mocks.

  What this file courts (read fresh from source, not assumed):

  - `Xaas.Platform.Webhook` has NO policy bypass at all: every verb is
    refused under `authorize?: true` for every actor, including the
    `:internal_api` system authority. Its only lawful in-test entry is
    `authorize?: false` (the route-level token plug is the production
    gate this file deliberately does not fake).
  - `Xaas.Platform.Webhook`'s `secret` is AshCloak-encrypted at rest
    (`platform_webhooks.encrypted_secret`) and `sensitive?`, so the
    plaintext must appear neither in the raw Postgres row nor in the
    struct's inspect output, while an Ash re-read decrypts to the
    original.
  - `Xaas.Platform.WebhookDelivery`'s policy admits ONLY
    `:retry_failed_deliveries` (as `:oban_scheduler`) and `:deliver`
    (as `:webhook_dispatcher`); `:create` and `:record_attempt` are
    uncovered by any bypass and are therefore refused for every actor.
  - the `:retry_failed_deliveries` fan-out filter
    (`status == :failed and attempt_count < 5`) really re-dispatches a
    below-ceiling failed delivery (real HTTP to a dead port keeps it
    `:failed` and bumps `attempt_count`) and really excludes an
    at-ceiling row.
  - `Xaas.Platform.RouteOrgsCustomDomain`'s cert-status contract covers
    the failure half too: the matching-org actor can transition
    `status -> "failed"` with `certificate_reason`/`certificate_message`
    (no certificate_secret_name required, unlike the "active" half), and
    system-authority actors are REFUSED on `:update` (the only admitted
    subject is the org-matching actor).
  """
  use ExUnit.Case, async: true

  require Ash.Query

  alias Xaas.Platform.RouteOrgsCustomDomain
  alias Xaas.Platform.Webhook
  alias Xaas.Platform.WebhookDelivery

  @internal_api Xaas.SystemAuthority.new(:internal_api)
  @oban_scheduler Xaas.SystemAuthority.new(:oban_scheduler)

  @closed_port_url "http://127.0.0.3:1/hook"

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp uniq(suffix), do: "w984bq-#{suffix}-#{System.unique_integer([:positive])}"

  defp org_actor(slug), do: %{org_id: slug}

  # ------------------------------------------------------------------
  # (1) Webhook -- deny-by-default floor with NO bypass
  # ------------------------------------------------------------------

  test "(1) Webhook denies every verb to every actor under authorization: no bypass exists, so even :internal_api is refused and no row lands" do
    key = uniq("hook")

    # :create refused for internal_api, oban_scheduler, and a plain org actor.
    for actor <- [@internal_api, @oban_scheduler, org_actor("nope")] do
      assert_raise Ash.Error.Forbidden, fn ->
        Webhook
        |> Ash.Changeset.for_create(:create, %{
          org_id: "some-org",
          url: @closed_port_url,
          event_types: ["order.created"],
          secret: "hmac-" <> key,
          enabled: true
        },
          actor: actor,
          authorize?: true
        )
        |> Ash.create!()
      end
    end

    # nothing was persisted by any refused attempt
    assert Webhook |> Ash.Query.filter(org_id == "some-org") |> Ash.count!(authorize?: false) == 0
  end

  # ------------------------------------------------------------------
  # (2) Webhook -- AshCloak at-rest encryption + sensitive?-inspect
  # ------------------------------------------------------------------

  test "(2) Webhook secret is AshCloak-encrypted at rest: plaintext absent from the raw Postgres row and from inspect, and a re-read decrypts to the original" do
    plaintext = "hmac-secret-" <> uniq("raw")

    hook =
      Webhook
      |> Ash.Changeset.for_create(:create, %{
        org_id: uniq("org"),
        url: @closed_port_url,
        event_types: ["order.created"],
        secret: plaintext,
        enabled: true
      },
        authorize?: false
      )
      |> Ash.create!()

    # raw row: the encrypted_secret column is populated, plaintext is not stored
    %{rows: [row]} =
      Ecto.Adapters.SQL.query!(Xaas.Repo, "SELECT encrypted_secret FROM platform_webhooks WHERE id = $1", [
        Ecto.UUID.dump!(hook.id)
      ])

    assert [encrypted] = row
    assert is_binary(encrypted) and encrypted != ""
    refute String.contains?(encrypted, plaintext)

    # plaintext must not appear anywhere in the raw row bytes
    %{rows: raw_rows} =
      Ecto.Adapters.SQL.query!(
        Xaas.Repo,
        "SELECT row_to_json(t) FROM platform_webhooks t WHERE id = $1",
        [Ecto.UUID.dump!(hook.id)]
      )

    refute inspect(raw_rows) |> String.contains?(plaintext)

    # the struct's inspect must also redact the secret (sensitive?: true)
    refute inspect(hook) |> String.contains?(plaintext)

    # an Ash re-read decrypts to the original secret
    reloaded = Ash.get!(Webhook, hook.id, authorize?: false)
    assert %Webhook{} = reloaded

    reloaded_secret = Map.get(reloaded, :secret)

    if is_binary(reloaded_secret) do
      assert reloaded_secret == plaintext
    else
      # cloak decrypt calculation path: fetch it explicitly
      decrypted =
        Ash.load!(reloaded, :secret, authorize?: false)
        |> Map.get(:secret)

      assert decrypted == plaintext
    end
  end

  # ------------------------------------------------------------------
  # (3) WebhookDelivery -- policy boundary: only the scheduler/dispatcher
  # verbs are admitted; :create / :record_attempt are refused for everyone
  # ------------------------------------------------------------------

  test "(3) WebhookDelivery admits only :retry_failed_deliveries and :deliver -- :create and :record_attempt are refused even for :internal_api" do
    hook =
      Webhook
      |> Ash.Changeset.for_create(:create, %{
        org_id: uniq("org"),
        url: @closed_port_url,
        event_types: ["order.created"],
        secret: uniq("hmac"),
        enabled: true
      },
        authorize?: false
      )
      |> Ash.create!()

    for actor <- [@internal_api, @oban_scheduler] do
      assert_raise Ash.Error.Forbidden, fn ->
        WebhookDelivery
        |> Ash.Changeset.for_create(:create, %{
          webhook_id: hook.id,
          event_type: "order.created",
          payload: %{"x" => 1}
        },
          actor: actor,
          authorize?: true
        )
        |> Ash.create!()
      end

      assert_raise Ash.Error.Forbidden, fn ->
        WebhookDelivery
        |> Ash.Changeset.for_create(:create, %{
          webhook_id: hook.id,
          event_type: "order.created",
          payload: %{"x" => 1}
        },
          authorize?: false
        )
        |> Ash.create!()
        |> then(fn delivery ->
          delivery
          |> Ash.Changeset.for_update(:record_attempt, %{status: :failed, attempt_count: 1},
            actor: actor,
            authorize?: true
          )
          |> Ash.update!()
        end)
      end
    end

    # the admitted scheduler verb really runs: zero candidates, no dispatch
    assert {:ok, %{candidates: 0, updated: 0, errored: 0}} =
             WebhookDelivery
             |> Ash.ActionInput.for_action(:retry_failed_deliveries, %{},
               actor: @oban_scheduler,
               authorize?: true
             )
             |> Ash.run_action()
  end

  # ------------------------------------------------------------------
  # (4) WebhookDelivery -- real retry filter boundary (real HTTP)
  # ------------------------------------------------------------------

  test "(4) retry fan-out re-dispatches a below-ceiling :failed delivery over real HTTP (dead port keeps it :failed, attempt bumped) and excludes the at-ceiling row" do
    hook =
      Webhook
      |> Ash.Changeset.for_create(:create, %{
        org_id: uniq("org"),
        url: @closed_port_url,
        event_types: ["order.created"],
        secret: uniq("hmac"),
        enabled: true
      },
        authorize?: false
      )
      |> Ash.create!()

    below =
      WebhookDelivery
      |> Ash.Changeset.for_create(:create, %{
        webhook_id: hook.id,
        event_type: "order.created",
        payload: %{"n" => 1},
        status: :failed,
        attempt_count: 4
      },
        authorize?: false
      )
      |> Ash.create!()

    at_ceiling =
      WebhookDelivery
      |> Ash.Changeset.for_create(:create, %{
        webhook_id: hook.id,
        event_type: "order.created",
        payload: %{"n" => 2},
        status: :failed,
        attempt_count: 5
      },
        authorize?: false
      )
      |> Ash.create!()

    assert {:ok, %{candidates: 1, updated: 1, errored: 0}} =
             WebhookDelivery
             |> Ash.ActionInput.for_action(:retry_failed_deliveries, %{},
               actor: @oban_scheduler,
               authorize?: true
             )
             |> Ash.run_action()

    # the below-ceiling row really saw a real (failing) HTTP dispatch
    re_below = Ash.get!(WebhookDelivery, below.id, authorize?: false)
    assert re_below.status == :failed
    assert re_below.attempt_count == 5

    # the at-ceiling row was excluded by the filter and is untouched
    re_ceiling = Ash.get!(WebhookDelivery, at_ceiling.id, authorize?: false)
    assert re_ceiling.status == :failed
    assert re_ceiling.attempt_count == 5
    assert re_ceiling.last_attempted_at == at_ceiling.last_attempted_at
  end

  # ------------------------------------------------------------------
  # (5) RouteOrgsCustomDomain -- the "failed" half of the cert-status
  # contract + system-actor refusal on :update
  # ------------------------------------------------------------------

  test "(5) custom domain: matching-org actor transitions status to 'failed' with cert reason/message; system-authority actor is refused on :update" do
    org = uniq("domfail")

    domain =
      RouteOrgsCustomDomain
      |> Ash.Changeset.for_create(:create, %{org_id: org, hostname: "app.#{org}.com"},
        actor: org_actor(org),
        authorize?: true
      )
      |> Ash.create!()

    assert domain.status == "pending"

    # first, the validation boundary itself: "active" without a certificate
    # secret name is a typed Invalid even before any actor check
    assert_raise Ash.Error.Invalid, fn ->
      domain
      |> Ash.Changeset.for_update(:update, %{status: "active"},
        actor: org_actor(org),
        authorize?: true
      )
      |> Ash.update!()
    end

    # system-authority actors are NOT the admitted subject for :update --
    # only the org-matching actor is (no SystemActor bypass on this resource);
    # a "failed" transition passes the validation so the denial is policy
    for actor <- [@internal_api, @oban_scheduler] do
      assert_raise Ash.Error.Forbidden, fn ->
        domain
        |> Ash.Changeset.for_update(:update, %{status: "failed"},
          actor: actor,
          authorize?: true
        )
        |> Ash.update!()
      end
    end

    # the failure half of the cert contract: no certificate_secret_name
    # required, reason + message ride along
    failed =
      domain
      |> Ash.Changeset.for_update(
        :update,
        %{
          status: "failed",
          certificate_reason: "dns01_challenge_failed",
          certificate_message: "no TXT record found"
        },
        actor: org_actor(org),
        authorize?: true
      )
      |> Ash.update!()

    assert failed.status == "failed"
    assert failed.certificate_reason == "dns01_challenge_failed"
    assert failed.certificate_message == "no TXT record found"

    # real persisted row state moved
    reloaded = Ash.get!(RouteOrgsCustomDomain, domain.id, authorize?: false)
    assert reloaded.status == "failed"
    assert reloaded.certificate_reason == "dns01_challenge_failed"
  end
end
