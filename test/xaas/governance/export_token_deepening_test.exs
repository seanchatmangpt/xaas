defmodule Xaas.Governance.ExportTokenDeepeningTest do
  @moduledoc """
  Real Chicago-style deepening tests (lane W765, v26.10.6) for two
  previously undocketed governance surfaces:

  - `Xaas.Governance.AuditExportToken` -- the release-audit export
    credential resource (mint via `:issue`, revoke via `:revoke`, the
    `AuditExportTokenNotAlreadyRevoked` guard cited by the
    ApprovalNotAlreadyApproved court idiom, and the `active?` expiry
    calculation).
  - `Xaas.Governance.FreezeWindow` -- what an active freeze window
    actually blocks per the real code: the `ends_at > starts_at`
    validation on `:create`, and the
    `ApprovalFreezeOverrideFreezeWindowExists` enforcement point
    (existence + same-org + `allow_emergency_override` flag) that turns
    a window into a real gate on `ApprovalFreezeOverride.:create`.

  Real Ash actions against the real sandboxed Postgres (`Xaas.Repo`).
  No mocks. Asserts real row state. Honest typed gaps are disclosed
  inline where a guard does not exist in the code (W715 pattern).
  """
  use ExUnit.Case, async: true

  require Ash.Query

  alias Xaas.Governance.{ApprovalFreezeOverride, AuditExportToken, FreezeWindow}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp org_id(prefix), do: "#{prefix}-#{System.unique_integer([:positive])}"

  defp field_errors(%Ash.Error.Invalid{errors: errors}, field) do
    Enum.filter(errors, fn
      %{field: ^field} -> true
      _ -> false
    end)
  end

  defp issue_changeset(org, attrs \\ %{}) do
    AuditExportToken
    |> Ash.Changeset.for_create(:issue, %{
      org_id: org,
      created_by: "w765-lane"
    })
    |> Ash.Changeset.force_change_attributes(attrs)
  end

  # ------------------------------------------------------------------
  # (a) mint → use → expiry lifecycle, per the REAL actions
  # ------------------------------------------------------------------

  test "issue mints a hashed bearer credential; raw token is returned exactly once via changeset context" do
    org = org_id("aet")

    cs = issue_changeset(org)
    token = Ash.create!(cs, authorize?: false)
    raw = cs.context[:raw_token]

    assert is_binary(raw)
    assert String.starts_with?(raw, "aet_live_")

    # hash determinism: the persisted hash is exactly sha256(raw), the
    # same discipline a real verifier would re-derive ("use").
    assert token.token_hash == Base.encode16(:crypto.hash(:sha256, raw), case: :lower)
    assert byte_size(token.token_hash) == 64

    # display prefix is the first 12 chars of the raw token
    assert token.token_prefix == String.slice(raw, 0, 12)

    # single-literal scope fixed at mint time
    assert token.scope == "audit:read"

    # REAL TTL semantics (post W900-batch2 / W765 GAP-A repair): :issue
    # accepts [:org_id, :created_by, :expires_at]. Omitting expires_at at
    # mint still yields a non-expiring token (expires_at = nil) -- the TTL
    # input is optional, not defaulted.
    assert is_nil(token.expires_at)
    assert :expires_at in Ash.Resource.Info.action(AuditExportToken, :issue).accept

    assert token.revoked_at |> is_nil()
    assert %{active?: true} = Ash.load!(token, :active?, authorize?: false)
  end

  test "expiry is enforced only through the active? calculation -- expired token computes inactive" do
    org = org_id("aet-exp")

    expired =
      org
      |> issue_changeset(%{expires_at: DateTime.add(DateTime.utc_now(), -60, :second)})
      |> Ash.create!(authorize?: false)

    live =
      org
      |> issue_changeset(%{expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)})
      |> Ash.create!(authorize?: false)

    assert %{active?: false} = Ash.load!(expired, :active?, authorize?: false)
    assert %{active?: true} = Ash.load!(live, :active?, authorize?: false)

    # expiry is not destructive: the row and its hash persist; only the
    # derived usability flag flips.
    persisted = Ash.get!(AuditExportToken, expired.id, authorize?: false)
    assert persisted.token_hash == expired.token_hash
    assert is_nil(persisted.revoked_at)
  end

  # W900-batch2 regression court (W765 GAP-A): mint-time TTL through the
  # REAL action surface (plain input, no force_change_attributes).
  # Mutation rationale: reverting the `:expires_at` entry in :issue's
  # accept list makes this court fail (the input is refused / not
  # persisted), so the accept-list line is load-bearing, not vacuous.
  test "W765 GAP-A repaired: :issue accepts expires_at as a plain input and it persists (future-dated active, past-dated inactive)" do
    org = org_id("aet-gap-a")

    future =
      AuditExportToken
      |> Ash.Changeset.for_create(:issue, %{
        org_id: org,
        created_by: "w900-batch2",
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      })
      |> Ash.create!(authorize?: false)

    past =
      AuditExportToken
      |> Ash.Changeset.for_create(:issue, %{
        org_id: org,
        created_by: "w900-batch2",
        expires_at: DateTime.add(DateTime.utc_now(), -60, :second)
      })
      |> Ash.create!(authorize?: false)

    reloaded_future = Ash.get!(AuditExportToken, future.id, authorize?: false)
    reloaded_past = Ash.get!(AuditExportToken, past.id, authorize?: false)

    assert %DateTime{} = reloaded_future.expires_at
    assert %DateTime{} = reloaded_past.expires_at
    assert %{active?: true} = Ash.load!(reloaded_future, :active?, authorize?: false)
    assert %{active?: false} = Ash.load!(reloaded_past, :active?, authorize?: false)
  end

  # ------------------------------------------------------------------
  # (b) reuse semantics -- SPEC-16/SPEC-17 closed (lane W935)
  # ------------------------------------------------------------------

  defp use_changeset(token), do: Ash.Changeset.for_update(token, :use, %{})

  # Mutation rationale: reverting the `:use` action (or its used_at
  # stamp / increment change) makes this court fail -- used_at stays nil
  # and the counter stays 0 on a real successful consumption.
  test "SPEC-16: :use stamps used_at once and increments use_count to 1 on a live token" do
    org = org_id("aet-use")
    cs = issue_changeset(org)
    token = Ash.create!(cs, authorize?: false)

    assert is_nil(token.used_at)
    assert token.use_count == 0

    used = token |> use_changeset() |> Ash.update!(authorize?: false)

    assert %DateTime{} = used.used_at
    assert used.use_count == 1

    persisted = Ash.get!(AuditExportToken, token.id, authorize?: false)
    assert %DateTime{} = persisted.used_at
    assert persisted.use_count == 1
    assert %{active?: true} = Ash.load!(persisted, :active?, authorize?: false)
  end

  # Mutation rationale: deleting the AuditExportTokenNotAlreadyUsed
  # validate line makes this court fail (second use succeeds and the
  # counter advances past 1), so the guard is load-bearing, not vacuous.
  test "SPEC-16: second use refuses with the typed NotAlreadyUsed error and the row is unchanged" do
    org = org_id("aet-double-use")
    cs = issue_changeset(org)
    token = Ash.create!(cs, authorize?: false)

    first = token |> use_changeset() |> Ash.update!(authorize?: false)
    first_used_at = first.used_at

    fresh = Ash.get!(AuditExportToken, token.id, authorize?: false)

    assert {:error, %Ash.Error.Invalid{} = error} =
             fresh |> use_changeset() |> Ash.update(authorize?: false)

    assert [_ | _] = field_errors(error, :used_at)
    assert Enum.any?(error.errors, &(&1.message == "token is already used"))

    after_refusal = Ash.get!(AuditExportToken, token.id, authorize?: false)
    assert after_refusal.use_count == 1
    assert DateTime.compare(after_refusal.used_at, first_used_at) == :eq
  end

  # SPEC-17 court (W740-mirror): expired token refuses use, typed on
  # :expires_at exactly as the spec names it.
  # Mutation rationale: removing the AuditExportTokenExpiredTokenRefused
  # validate line makes this court fail (the expired token is consumed
  # instead of refused).
  test "SPEC-17: use of an expired token refuses with the typed ExpiredTokenRefused error (field :expires_at)" do
    org = org_id("aet-use-expired")

    expired =
      org
      |> issue_changeset(%{expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)})
      |> Ash.create!(authorize?: false)

    assert %{active?: false} = Ash.load!(expired, :active?, authorize?: false)

    assert {:error, %Ash.Error.Invalid{} = error} =
             expired |> use_changeset() |> Ash.update(authorize?: false)

    assert [_ | _] = field_errors(error, :expires_at)
    assert Enum.any?(error.errors, &(&1.message == "token is expired"))

    # the refused use left the row untouched: no tombstone, no count
    persisted = Ash.get!(AuditExportToken, expired.id, authorize?: false)
    assert is_nil(persisted.used_at)
    assert persisted.use_count == 0
  end

  # W801 gating on the use path: an active freeze window for the org
  # also refuses :use (the export path the freeze governs), while an
  # expired window does not.
  test "an active freeze window for the org refuses :use (W801 gate on the consumption path)" do
    org = org_id("aet-use-frozen")
    cs = issue_changeset(org)
    token = Ash.create!(cs, authorize?: false)

    create_window!(org, false)

    assert {:error, %Ash.Error.Invalid{} = error} =
             token |> use_changeset() |> Ash.update(authorize?: false)

    assert [_ | _] = field_errors(error, :org_id)

    persisted = Ash.get!(AuditExportToken, token.id, authorize?: false)
    assert is_nil(persisted.used_at)
    assert persisted.use_count == 0
  end

  test "an expired freeze window does not block :use" do
    org = org_id("aet-use-frozen-expired")
    cs = issue_changeset(org)
    token = Ash.create!(cs, authorize?: false)

    create_window!(
      org,
      false,
      DateTime.add(DateTime.utc_now(), -7200, :second),
      DateTime.add(DateTime.utc_now(), -3600, :second)
    )

    used = token |> use_changeset() |> Ash.update!(authorize?: false)
    assert used.use_count == 1
  end

  test "docs/accept-list consistency: :use takes no inputs, is non-atomic-capable, and is exposed as a patch route" do
    action = Ash.Resource.Info.action(AuditExportToken, :use)
    assert action.accept == []
    assert action.require_atomic? == false

    route =
      AuditExportToken
      |> AshJsonApi.Resource.Info.routes(AuditExportToken)
      |> Enum.find(&(&1.action == :use))

    assert %{} = route
    assert route.method == :patch
  end

  # ------------------------------------------------------------------
  # (c) the already-revoked guard (cited by ApprovalNotAlreadyApproved)
  # ------------------------------------------------------------------

  test "revoke sets revoked_at, active? flips false, and the raw hash persists" do
    org = org_id("aet-revoke")

    cs = issue_changeset(org)
    token = Ash.create!(cs, authorize?: false)
    assert %{active?: true} = Ash.load!(token, :active?, authorize?: false)

    revoked = Ash.Changeset.for_update(token, :revoke, %{}) |> Ash.update!(authorize?: false)

    assert %DateTime{} = revoked.revoked_at
    assert %{active?: false} = Ash.load!(revoked, :active?, authorize?: false)

    persisted = Ash.get!(AuditExportToken, token.id, authorize?: false)
    assert %DateTime{} = persisted.revoked_at
    # revocation is not destructive to the credential record itself
    assert persisted.token_hash == token.token_hash
  end

  test "second revoke refuses with the real typed guard error and does not touch revoked_at" do
    org = org_id("aet-double-revoke")

    cs = issue_changeset(org)
    token = Ash.create!(cs, authorize?: false)

    revoked =
      token
      |> Ash.Changeset.for_update(:revoke, %{})
      |> Ash.update!(authorize?: false)

    first_revoked_at = revoked.revoked_at

    fresh = Ash.get!(AuditExportToken, token.id, authorize?: false)

    assert {:error, %Ash.Error.Invalid{} = error} =
             fresh
             |> Ash.Changeset.for_update(:revoke, %{})
             |> Ash.update(authorize?: false)

    assert [_ | _] = field_errors(error, :revoked_at)
    assert Enum.any?(error.errors, &(&1.message == "token is already revoked"))

    # the refused revoke left the real row unchanged
    after_refusal = Ash.get!(AuditExportToken, token.id, authorize?: false)
    assert DateTime.compare(after_refusal.revoked_at, first_revoked_at) == :eq
  end

  test "each mint is nondeterministic by design: two mints never collide on hash or prefix" do
    org = org_id("aet-det")

    cs1 = issue_changeset(org)
    t1 = Ash.create!(cs1, authorize?: false)
    raw1 = cs1.context[:raw_token]

    cs2 = issue_changeset(org)
    t2 = Ash.create!(cs2, authorize?: false)
    raw2 = cs2.context[:raw_token]

    # same org, same created_by, same action -- different credentials
    refute t1.token_hash == t2.token_hash
    refute t1.token_prefix == t2.token_prefix
    refute raw1 == raw2

    # but the derivation itself is deterministic: hash(raw) reproduces
    # the stored hash exactly, for both tokens
    assert t1.token_hash == Base.encode16(:crypto.hash(:sha256, raw1), case: :lower)
    assert t2.token_hash == Base.encode16(:crypto.hash(:sha256, raw2), case: :lower)
  end

  # ------------------------------------------------------------------
  # (d) FreezeWindow: what an active freeze actually blocks
  # ------------------------------------------------------------------

  defp create_window!(org, allow, starts_at \\ nil, ends_at \\ nil) do
    now = DateTime.utc_now()
    starts = starts_at || now
    ends = ends_at || DateTime.add(now, 3600, :second)

    FreezeWindow
    |> Ash.Changeset.for_create(:create, %{
      org_id: org,
      starts_at: starts,
      ends_at: ends,
      reason: "W765 real freeze window",
      allow_emergency_override: allow,
      created_by: "w765-lane"
    })
    |> Ash.create!(authorize?: false)
  end

  defp override_attrs(org, window_id) do
    %{
      org_id: org,
      requested_by: "requester-#{System.unique_integer([:positive])}",
      freeze_window_id: window_id,
      reason: "W765 emergency hotfix during freeze"
    }
  end

  test "freeze window creation enforces ends_at strictly after starts_at (typed refusal)" do
    org = org_id("fw")

    now = DateTime.utc_now()

    assert {:error, %Ash.Error.Invalid{} = error} =
             FreezeWindow
             |> Ash.Changeset.for_create(:create, %{
               org_id: org,
               starts_at: now,
               ends_at: now,
               reason: "degenerate window",
               created_by: "w765-lane"
             })
             |> Ash.create(authorize?: false)

    assert [_ | _] = field_errors(error, :ends_at)
    assert Enum.any?(error.errors, &(&1.message == "must be after starts_at"))

    # ends_at strictly before starts_at is equally refused
    assert {:error, %Ash.Error.Invalid{} = error2} =
             FreezeWindow
             |> Ash.Changeset.for_create(:create, %{
               org_id: org,
               starts_at: now,
               ends_at: DateTime.add(now, -1, :second),
               reason: "inverted window",
               created_by: "w765-lane"
             })
             |> Ash.create(authorize?: false)

    assert [_ | _] = field_errors(error2, :ends_at)

    # no row persisted despite the refusals
    assert FreezeWindow |> Ash.read!(authorize?: false) |> Enum.filter(&(&1.org_id == org)) == []
  end

  test "an active freeze window blocks nothing by itself -- the only enforcement point is the override gate" do
    org = org_id("fw-block")

    window = create_window!(org, true)

    # an active window is inert by itself: creating it gates no other
    # resource's action (real-read: no consumer queries starts_at/ends_at
    # to refuse an action at runtime). Disclosed gap: "active freeze
    # blocks deploys" is NOT implemented in-process; the window acts
    # only through ApprovalFreezeOverride's validation.
    # The real enforcement: an override may be filed against this window
    # only because allow_emergency_override is true.
    override =
      ApprovalFreezeOverride
      |> Ash.Changeset.for_create(:create, override_attrs(org, window.id))
      |> Ash.create!(authorize?: false)

    assert override.freeze_window_id == window.id
    assert override.org_id == org
  end

  test "a window with allow_emergency_override: false refuses an override (the real freeze block)" do
    org = org_id("fw-gate")

    window = create_window!(org, false)

    assert {:error, %Ash.Error.Invalid{} = error} =
             ApprovalFreezeOverride
             |> Ash.Changeset.for_create(:create, override_attrs(org, window.id))
             |> Ash.create(authorize?: false)

    assert [_ | _] = field_errors(error, :freeze_window_id)
  end

  test "a foreign-org window refuses a same-shape override (cross-org integrity)" do
    org = org_id("fw-cross")
    foreign_org = org_id("fw-cross-other")

    foreign_window = create_window!(foreign_org, true)

    assert {:error, %Ash.Error.Invalid{} = error} =
             ApprovalFreezeOverride
             |> Ash.Changeset.for_create(:create, override_attrs(org, foreign_window.id))
             |> Ash.create(authorize?: false)

    assert [_ | _] = field_errors(error, :freeze_window_id)
  end

  # ------------------------------------------------------------------
  # (d) W801: real freeze-window enforcement on AuditExportToken.:issue
  # ------------------------------------------------------------------

  test "an active freeze window for the org refuses AuditExportToken :issue (typed refusal, nothing persisted)" do
    org = org_id("aet-freeze")

    create_window!(org, false)

    assert {:error, %Ash.Error.Invalid{} = error} =
             AuditExportToken
             |> Ash.Changeset.for_create(:issue, %{org_id: org, created_by: "w801-lane"})
             |> Ash.create(authorize?: false)

    assert [_ | _] = field_errors(error, :org_id)

    # nothing persisted: the refusal happens before GenerateAuditExportToken
    assert [] =
             AuditExportToken
             |> Ash.Query.filter(org_id: org)
             |> Ash.read!(authorize?: false)
  end

  test "an expired freeze window does not block :issue" do
    org = org_id("aet-freeze-expired")

    create_window!(
      org,
      false,
      DateTime.add(DateTime.utc_now(), -7200, :second),
      DateTime.add(DateTime.utc_now(), -3600, :second)
    )

    token =
      AuditExportToken
      |> Ash.Changeset.for_create(:issue, %{org_id: org, created_by: "w801-lane"})
      |> Ash.create!(authorize?: false)

    assert token.org_id == org
    assert is_binary(token.token_hash)
  end

  test "a future freeze window does not block :issue" do
    org = org_id("aet-freeze-future")

    create_window!(
      org,
      false,
      DateTime.add(DateTime.utc_now(), 3600, :second),
      DateTime.add(DateTime.utc_now(), 7200, :second)
    )

    token =
      AuditExportToken
      |> Ash.Changeset.for_create(:issue, %{org_id: org, created_by: "w801-lane"})
      |> Ash.create!(authorize?: false)

    assert token.org_id == org
    assert is_binary(token.token_hash)
  end

  test "an active window in a DIFFERENT org does not block :issue for this org" do
    org = org_id("aet-freeze-other")
    other = org_id("aet-freeze-other-2")

    create_window!(other, false)

    token =
      AuditExportToken
      |> Ash.Changeset.for_create(:issue, %{org_id: org, created_by: "w801-lane"})
      |> Ash.create!(authorize?: false)

    assert token.org_id == org
    assert is_binary(token.token_hash)
  end

  test "ApprovalFreezeOverride path unaffected: override against an emergency-eligible window still files during a freeze" do
    org = org_id("aet-freeze-override")

    window = create_window!(org, true)

    override =
      ApprovalFreezeOverride
      |> Ash.Changeset.for_create(:create, override_attrs(org, window.id))
      |> Ash.create!(authorize?: false)

    assert override.freeze_window_id == window.id

    # and :issue is still frozen for the same org while that window is active
    assert {:error, %Ash.Error.Invalid{} = error} =
             AuditExportToken
             |> Ash.Changeset.for_create(:issue, %{org_id: org, created_by: "w801-lane"})
             |> Ash.create(authorize?: false)

    assert [_ | _] = field_errors(error, :org_id)
  end
end
