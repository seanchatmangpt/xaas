# ---
# Excerpted from "Engineering Elixir Applications",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/beamops for more book information.
# ---
# Real, fixed test-only token for XaasWeb.Plugs.RequireInternalApiToken --
# not a production secret (test env only), needed so real ConnCase tests
# against /internal-api and /api can authenticate for real rather than
# disabling the real gate for tests.
System.put_env("INTERNAL_API_TOKEN", "test-only-internal-api-token")
# Real, fixed test-only secret for XaasWeb.StripeWebhookController's
# Stripe.Webhook.construct_event/3 signature verification -- not a
# production secret (test env only).
System.put_env("STRIPE_WEBHOOK_SECRET", "whsec_test_only_secret")

ExUnit.start()
# Real, concurrent-connection-pool-hungry stress tests are excluded by
# default -- run explicitly with `mix test --include stress`.
# Real tests against a live-deployed kind pod (test/e2e/) are excluded by
# default too -- they need a real `kubectl port-forward` to kind-xaas
# already running; run explicitly with `mix test --include kind`.
# Real tests that depend on a sibling ex4pm checkout being present on this
# machine (test/xaas/ontology/ex4pm_staleness_test.exs) are excluded by
# default too, so the default `mix test` never depends on that sibling
# repo; run explicitly with `mix test --include external`.
ExUnit.configure(exclude: [:stress, :kind, :requires_cnv_deploy, :external])
Ecto.Adapters.SQL.Sandbox.mode(Xaas.LegacyRepo, :manual)
# ash-migration Phase 3: real, separate AshPostgres.Repo -- needed for any
# real Chicago-style test that touches Xaas.* Ash resources via the
# sandbox (Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo) in test setup).
Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, :manual)

# Ensure Phoenix.PubSub is running for Ash PubSub notifiers
unless Process.whereis(Xaas.PubSub) do
  {:ok, _} = Phoenix.PubSub.Supervisor.start_link(name: Xaas.PubSub)
end

