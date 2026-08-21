# ---
# Excerpted from "Engineering Elixir Applications",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/beamops for more book information.
# ---
# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Real Xaas.* dev fixture chain -- see Xaas.DevSeeds's own moduledoc for
# the full real spec (one Org, one Subscription, one Ledger.Account, one
# pending ApprovalBackupRetentionChange). Idempotent: safe to re-run.
fixtures = Xaas.DevSeeds.run()

IO.puts("""
Seeded real Xaas.* dev fixtures:
  org:                #{fixtures.org.name} (slug: #{fixtures.org.slug})
  subscription:        #{fixtures.subscription.tier} / #{fixtures.subscription.status}
  ledger account:       #{fixtures.ledger_account.identifier}
  pending approval:     Xaas.Governance.ApprovalBackupRetentionChange \
#{fixtures.pending_approval.id} (#{fixtures.pending_approval.requested_retention_days} days, \
#{fixtures.pending_approval.tier} tier)

To smoke-test the real atomic Ledger-credit path end-to-end, approve the
pending row by hand from IEx or a one-off `mix run`:

    Xaas.DevSeeds.approve_seeded_pending!()
""")
