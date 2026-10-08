defmodule Xaas.Governance.W984dr2AuditExportTokenFreezeCourtTest do
  @moduledoc """
  Lane W984dr2 depth court (v26.10.6 governance burn-down), second of
  the two state-bearing unclaimed validations:
  `Xaas.Governance.Validations.AuditExportTokenNoActiveFreezeWindow`
  (71 lines) -- the freeze gate on `Xaas.Governance.AuditExportToken`'s
  `:issue` and `:use` actions: while an org has an active
  `Xaas.Governance.FreezeWindow` (starts_at <= now <= ends_at), new
  audit-export bearer credentials are refused for that org, and
  consumption (`:use`) is gated identically while `:revoke` stays
  available by design (killing credentials is not what a freeze
  governs).

  Indirect-exercise census: `freeze_window_active_gate_test.exs` and
  the export-token deepening tests touch the freeze gate only
  incidentally; no direct court pins the temporal boundary semantics
  (future window, ended window) or the issue/use/revoke triage through
  the live actions. This court fills that gap through the real action
  surface over real sandboxed Postgres. No mocks.

  Per-test mutation rationale is in each test's comment.
  """

  use ExUnit.Case, async: true

  alias Xaas.Governance.AuditExportToken
  alias Xaas.Governance.FreezeWindow

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp org, do: "w984dr2-freeze-#{System.unique_integer([:positive])}"

  defp window!(org_id, starts_at, ends_at) do
    FreezeWindow
    |> Ash.Changeset.for_create(:create, %{
      org_id: org_id,
      starts_at: starts_at,
      ends_at: ends_at,
      reason: "w984dr2 court window",
      allow_emergency_override: false,
      created_by: "w984dr2-lane"
    })
    |> Ash.create!(authorize?: false)
  end

  defp active_window!(org_id) do
    now = DateTime.utc_now()
    window!(org_id, DateTime.add(now, -600, :second), DateTime.add(now, 3600, :second))
  end

  defp issue(org_id) do
    AuditExportToken
    |> Ash.Changeset.for_create(:issue, %{
      org_id: org_id,
      created_by: "w984dr2-minter",
      expires_at:
        DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:microsecond)
    })
    |> Ash.create(authorize?: false)
  end

  defp issue!(org_id) do
    assert {:ok, token} = issue(org_id)
    token
  end

  defp use_token(token) do
    token
    |> Ash.Changeset.for_update(:use, %{})
    |> Ash.update(authorize?: false)
  end

  defp revoke(token) do
    token
    |> Ash.Changeset.for_update(:revoke, %{})
    |> Ash.update(authorize?: false)
  end

  # ------------------------------------------------------------------
  # (1) Baseline: no freeze window -> :issue mints a real token with
  # generator-set prefix/hash. Mutation: make the validation refuse
  # unconditionally -- this test fails (over-blocking regression).
  # ------------------------------------------------------------------
  test "issue mints a real token when no freeze window exists" do
    o = org()
    assert {:ok, token} = issue(o)

    assert token.org_id == o
    assert token.token_prefix != nil
    assert token.token_hash != nil
    assert token.scope == "audit:read"
  end

  # ------------------------------------------------------------------
  # (2) Active window -> :issue refused with the real typed message,
  # naming the real persisted window id. Mutation: map the
  # `{:ok, [window | _]}` clause to :ok -- a mint during a live
  # freeze would then be admitted.
  # ------------------------------------------------------------------
  test "issue refused during an active freeze window" do
    o = org()
    w = active_window!(o)

    assert {:error, %Ash.Error.Invalid{} = err} = issue(o)
    assert Exception.message(err) =~ "active change-freeze window"
    assert Exception.message(err) =~ w.id

    # Non-vacuity: real persisted window, re-read from Postgres.
    assert {:ok, _} = Ash.get(FreezeWindow, w.id, authorize?: false)
  end

  # ------------------------------------------------------------------
  # (3) Boundary: a FUTURE window (starts_at > now) does not block
  # :issue. Mutation: drop `starts_at <= ^now` from the filter -- a
  # not-yet-started window would block mints.
  # ------------------------------------------------------------------
  test "boundary: future window does not block issue" do
    o = org()
    now = DateTime.utc_now()
    window!(o, DateTime.add(now, 600, :second), DateTime.add(now, 1200, :second))

    assert {:ok, _} = issue(o)
  end

  # ------------------------------------------------------------------
  # (4) Boundary: an already-ENDED window does not block :issue.
  # Mutation: relax the filter to "window exists for org" -- both (3)
  # and (4) fail; relaxing to `ends_at >= ^now` only -- (3) fails.
  # ------------------------------------------------------------------
  test "boundary: ended window does not block issue" do
    o = org()
    now = DateTime.utc_now()
    window!(o, DateTime.add(now, -3600, :second), DateTime.add(now, -600, :second))

    assert {:ok, _} = issue(o)
  end

  # ------------------------------------------------------------------
  # (5) Triage: during an active freeze, :use is refused (the
  # validation is wired on :use too) while :revoke stays available by
  # design. Mutations: unwire the validation from :use (consumption
  # during freeze admitted) or wire it onto :revoke (revocation during
  # freeze refused -- kills the disclosed :revoke carve-out).
  # ------------------------------------------------------------------
  test "during freeze: use refused, revoke stays available" do
    o2 = org()
    token2 = issue!(o2)
    active_window!(o2)

    assert {:error, %Ash.Error.Invalid{}} = use_token(token2)

    assert {:ok, revoked} = revoke(token2)
    assert revoked.revoked_at != nil
  end
end
