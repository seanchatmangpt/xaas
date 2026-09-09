# ---
# Excerpted from "Engineering Elixir Applications",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/beamops for more book information.
# ---
# Real, fixed test-only token for KanbanWeb.Plugs.RequireInternalApiToken --
# not a production secret (test env only), needed so real ConnCase tests
# against /internal-api and /api can authenticate for real rather than
# disabling the real gate for tests.
System.put_env("INTERNAL_API_TOKEN", "test-only-internal-api-token")
# Real, fixed test-only secret for KanbanWeb.StripeWebhookController's
# Stripe.Webhook.construct_event/3 signature verification -- not a
# production secret (test env only).
System.put_env("STRIPE_WEBHOOK_SECRET", "whsec_test_only_secret")

ExUnit.start()
# Real, concurrent-connection-pool-hungry stress tests are excluded by
# default -- run explicitly with `mix test --include stress`.
# Real tests against a live-deployed kind pod (test/e2e/) are excluded by
# default too -- they need a real `kubectl port-forward` to kind-xaas
# already running; run explicitly with `mix test --include kind`.
# The CASTLE cross-repo court is also excluded from the ordinary suite: it
# requires a binary built from the exact admitted CASTLE source subject.
# `.github/workflows/castle-paas-bridge.yml` supplies that subject and runs
# `mix test --include castle_kernel test/xaas/castle_bridge_test.exs`.
ExUnit.configure(exclude: [:stress, :kind, :castle_kernel])
Ecto.Adapters.SQL.Sandbox.mode(Kanban.Repo, :manual)
# ash-migration Phase 3: real, separate AshPostgres.Repo -- needed for any
# real Chicago-style test that touches Xaas.* Ash resources via the
# sandbox (Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo) in test setup).
Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, :manual)
