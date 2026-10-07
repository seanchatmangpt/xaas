defmodule Xaas.Governance.SecurityResourcesDeepeningTest do
  @moduledoc """
  Lane W769 (v26.10.6) deepening court for the two previously-undocketed
  governance security resources:

  - `Xaas.Governance.InternalApiToken` +
    `Xaas.Governance.InternalApiTokenAuth` -- the rotation-capable bearer
    credential for `/internal-api/*`: mint (`:issue`, raw token returned
    exactly once via never-persisted metadata), hash-before-persistence
    discipline, `verify/1` fail-closed lookup, revocation (typed
    already-revoked guard), and expiry semantics.
  - `Xaas.Governance.PentestFinding` -- the ported platform-console
    finding lifecycle: file (`:create`, always `:open`) -> remediate
    (ungated `:remediate`), with the terminal `resolved`/`accepted_risk`
    transition deliberately absent as a direct action (maker-checker only,
    via `Xaas.Governance.ApprovalPentestFindingResolve`).

  Real Chicago-style: real Ash actions on the real sandboxed Postgres
  (`Xaas.Repo`), real plug invocation for the env-var floor pin, no
  mocks. Honest typed gaps disclosed inline (W715 pattern).
  """

  use ExUnit.Case, async: true

  import Ecto.Query, only: [from: 2]

  alias Xaas.Governance.InternalApiToken
  alias Xaas.Governance.InternalApiTokenAuth
  alias Xaas.Governance.PentestFinding

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp expected_hash(raw), do: :crypto.hash(:sha256, raw) |> Base.encode16(case: :lower)

  defp mint!(created_by \\ "w769-lane", expires_at \\ nil) do
    assert {:ok, raw, token} = InternalApiTokenAuth.issue(created_by, expires_at)
    {raw, token}
  end

  # ==================================================================
  # (a) mint -> validate lifecycle, per the REAL actions
  # ==================================================================

  test "issue mints an iat_live_ raw token; persisted row carries only the hash, never the raw value" do
    {raw, token} = mint!("sean-cli")

    assert String.starts_with?(raw, InternalApiTokenAuth.prefix())
    assert byte_size(raw) > byte_size(InternalApiTokenAuth.prefix())

    # Real hashing discipline: SHA-256, lowercase hex, of exactly the raw
    # value returned. Plaintext storage would show up right here as the
    # persisted token_hash equaling the raw token.
    assert token.token_hash == expected_hash(raw)
    assert token.token_hash != raw
    assert byte_size(token.token_hash) == 64

    # Display prefix: first 12 chars of the raw token, distinct attribute.
    assert token.token_prefix == binary_part(raw, 0, InternalApiTokenAuth.display_prefix_len())
    assert token.token_prefix != token.token_hash

    # Raw value exists only as ephemeral metadata on the returned result,
    # never as a persisted attribute: a fresh read of the same row has no
    # raw token anywhere on it.
    reloaded = Ash.get!(InternalApiToken, token.id, authorize?: false)
    assert reloaded.token_hash == expected_hash(raw)
    assert Ash.Resource.get_metadata(reloaded, :raw_token) == nil
    refute Map.get(reloaded, :raw_token)

    assert token.created_by == "sean-cli"
    assert token.revoked_at == nil
    assert token.org_id == nil
  end

  test "verify/1 round-trips the exact raw token and fails closed on everything else" do
    {raw, _token} = mint!()

    assert {:ok, %InternalApiToken{}} = InternalApiTokenAuth.verify(raw)

    # Near-misses: different raw values fail closed.
    assert InternalApiTokenAuth.verify(raw <> "x") == :error
    assert InternalApiTokenAuth.verify("iat_live_entirely-wrong") == :error
    assert InternalApiTokenAuth.verify("") == :error
    assert InternalApiTokenAuth.verify(nil) == :error
    assert InternalApiTokenAuth.verify(42) == :error
  end

  test "revoke sets revoked_at, verify/1 then rejects the raw token; double revoke is a typed error" do
    {raw, token} = mint!()
    assert {:ok, %InternalApiToken{}} = InternalApiTokenAuth.verify(raw)

    before = DateTime.utc_now()
    {:ok, revoked} = InternalApiTokenAuth.revoke(token)
    assert %DateTime{} = revoked.revoked_at
    assert DateTime.compare(revoked.revoked_at, before) in [:gt, :eq]

    # The exact raw value that verified a moment ago is now dead.
    assert InternalApiTokenAuth.verify(raw) == :error

    # Row keeps its hash (auditable); only the liveness flipped.
    reloaded = Ash.get!(InternalApiToken, token.id, authorize?: false)
    assert reloaded.token_hash == expected_hash(raw)
    assert %DateTime{} = reloaded.revoked_at

    # Idempotency guard: revoking an already-revoked token is a typed
    # validation failure naming the field and the real message.
    assert {:error, %Ash.Error.Invalid{} = error} = InternalApiTokenAuth.revoke(revoked)

    assert Enum.any?(error.errors, fn e ->
             match?(%{field: :revoked_at}, e) or
               (is_binary(e.message) and String.contains?(e.message, "already revoked"))
           end)
  end

  # ==================================================================
  # (b) expiry semantics per the real code
  # ==================================================================

  test "past expires_at fails verify/1 and the active? calculation; future expiry stays active" do
    # Expired-at-mint.
    {raw, token} = mint!("w769-expired", DateTime.add(DateTime.utc_now(), -3600, :second))
    assert InternalApiTokenAuth.verify(raw) == :error
    assert token.expires_at != nil

    reloaded = Ash.get!(InternalApiToken, token.id, authorize?: false)

    # The declared `active?` calculation agrees with verify/1's own
    # active?/1 (revoked_at nil AND (expires_at nil OR expires_at > now)).
    assert Ash.load!(reloaded, :active?, authorize?: false).active? == false

    # Future expiry is live now.
    {:ok, raw2, token2} =
      InternalApiTokenAuth.issue("w769-future", DateTime.add(DateTime.utc_now(), 3600, :second))

    assert {:ok, %InternalApiToken{}} = InternalApiTokenAuth.verify(raw2)
    assert Ash.load!(token2, :active?, authorize?: false).active? == true

    # Revocation cuts off an unexpired token too (either liveness killer).
    {:ok, _} = InternalApiTokenAuth.revoke(token2)
    assert InternalApiTokenAuth.verify(raw2) == :error
  end

  test "nil expires_at means no expiry: verify/1 stays ok until explicit revocation" do
    {raw, token} = mint!("w769-no-expiry")
    assert token.expires_at == nil
    assert {:ok, %InternalApiToken{}} = InternalApiTokenAuth.verify(raw)
    assert Ash.load!(token, :active?, authorize?: false).active? == true
  end

  # ==================================================================
  # (c) PentestFinding lifecycle per its REAL actions
  # ==================================================================

  defp unique(tag), do: "#{tag}-#{System.unique_integer([:positive])}"

  defp file_finding!(attrs \\ %{}) do
    default = %{
      org_id: unique("org"),
      engagement_id: unique("engagement"),
      severity: :high,
      title: "Stored XSS in export view",
      description: "Real finding body.",
      filed_by: "pentester@example.com"
    }

    PentestFinding
    |> Ash.Changeset.for_create(:create, Map.merge(default, attrs))
    |> Ash.create!(authorize?: false)
  end

  test "create files a finding always as :open, with the real ported payload" do
    finding =
      file_finding!(%{
        severity: :critical,
        title: "Authz bypass on admin surface",
        org_id: unique("org")
      })

    assert finding.status == :open
    assert finding.severity == :critical
    assert finding.title == "Authz bypass on admin surface"
    assert is_binary(finding.engagement_id)
    assert is_binary(finding.filed_by)

    persisted = Ash.get!(PentestFinding, finding.id, authorize?: false)
    assert persisted.status == :open
  end

  test "remediate moves open -> remediation_in_progress; is not repeatable (typed validation)" do
    finding = file_finding!()

    updated =
      finding
      |> Ash.Changeset.for_update(:remediate, %{})
      |> Ash.update!(authorize?: false)

    assert updated.status == :remediation_in_progress

    persisted = Ash.get!(PentestFinding, finding.id, authorize?: false)
    assert persisted.status == :remediation_in_progress

    # The real validate attribute_equals(:status, :open) refuses a second
    # remediate with the real message.
    assert {:error, %Ash.Error.Invalid{} = error} =
             persisted
             |> Ash.Changeset.for_update(:remediate, %{})
             |> Ash.update()

    assert Enum.any?(error.errors, fn e ->
             is_binary(e.message) and
               String.contains?(e.message, "finding must be open to move to remediation_in_progress")
           end)
  end

  test "honest gap pin: no direct terminal action exists on the resource; enum has terminal states, actions do not" do
    action_names =
      PentestFinding
      |> Ash.Resource.Info.actions()
      |> Enum.map(& &1.name)

    # :remediate is the only update action; nothing on the resource sets
    # :resolved or :accepted_risk -- that transition is maker-checker only
    # (Xaas.Governance.ApprovalPentestFindingResolve), by design.
    assert :remediate in action_names
    refute :resolve in action_names
    refute :accept in action_names

    update_actions = PentestFinding |> Ash.Resource.Info.actions() |> Enum.filter(&(&1.type == :update))
    assert update_actions |> Enum.map(& &1.name) == [:remediate]

    # The enum still declares the terminal states (they exist in the wire
    # vocabulary); the resource surface just never writes them directly.
    status_values = Xaas.Governance.Types.PentestFindingStatus.values()
    assert :resolved in status_values
    assert :accepted_risk in status_values

    # The maker-checker seam is wired as a real relationship.
    rel = Ash.Resource.Info.relationship(PentestFinding, :resolve_approvals)
    assert rel.destination == Xaas.Governance.ApprovalPentestFindingResolve
    assert rel.destination_attribute == :finding_id
  end

  test "deny-by-default floor holds at the resource boundary: non-matching actor org cannot create or remediate" do
    org = unique("org")
    finding = file_finding!(%{org_id: org})

    attacker = %{org_id: unique("attacker-org")}

    assert {:error, %Ash.Error.Forbidden{}} =
             PentestFinding
             |> Ash.Changeset.for_create(:create, %{
               org_id: unique("victim"),
               engagement_id: unique("engagement"),
               severity: :medium,
               title: "forged",
               filed_by: "attacker"
             })
             |> Ash.create(authorize?: true, actor: attacker)

    assert {:error, %Ash.Error.Forbidden{}} =
             finding
             |> Ash.Changeset.for_update(:remediate, %{})
             |> Ash.update(authorize?: true, actor: attacker)

    # Matching org passes (real bypass path, real actor match).
    assert {:ok, _} =
             finding
             |> Ash.Changeset.for_update(:remediate, %{})
             |> Ash.update(authorize?: true, actor: %{org_id: org})

    # Read is open by bypass (matches the real policy block).
    assert {:ok, _} = Ash.read(PentestFinding, authorize?: true, actor: attacker)
  end

  # ==================================================================
  # (d) what these resources do NOT enforce vs the env-var floor
  # ==================================================================

  describe "(d) env-var floor separation" do
    # Same idiom as require_internal_api_token_deepening_test.exs: the env
    # var is process-wide; restore the real value in on_exit.
    defp with_env(nil, fun), do: swap_env(:absent, fun)
    defp with_env(value, fun) when is_binary(value), do: swap_env(value, fun)

    defp swap_env(new_value, fun) do
      previous = System.get_env("INTERNAL_API_TOKEN")

      if new_value == :absent do
        System.delete_env("INTERNAL_API_TOKEN")
      else
        System.put_env("INTERNAL_API_TOKEN", new_value)
      end

      on_exit(fn ->
        if previous, do: System.put_env("INTERNAL_API_TOKEN", previous),
          else: System.delete_env("INTERNAL_API_TOKEN")
      end)

      fun.()
    end

    defp plug_call(bearer) do
      conn =
        Plug.Test.conn(:get, "/internal-api/health")
        |> Plug.Conn.put_req_header("authorization", "Bearer #{bearer}")

      XaasWeb.Plugs.RequireInternalApiToken.call(conn, nil)
    end

    test "a DB-backed token authenticates the real plug with NO env var set (additive, not a replacement)" do
      {raw, token} = mint!("w769-plug-live")

      with_env(nil, fn ->
        conn = plug_call(raw)
        # Passed the floor: no 401/503 halted response, assign attached.
        refute conn.halted
        assert conn.assigns[:current_org] == token.org_id
        assert conn.assigns[:current_org] == nil
      end)
    end

    test "revoked DB token does NOT pass, even though it is a real row; env fallback still owns the floor" do
      {raw, token} = mint!("w769-revoked-row")
      {:ok, _} = InternalApiTokenAuth.revoke(token)

      with_env("w769-env-floor-secret", fn ->
        # The revoked DB raw value is dead: plug falls through to env.
        conn = plug_call(raw)
        assert conn.halted
        assert conn.status == 401

        # The env value itself still passes -- the flat env-var floor is
        # untouched by any of this resource's state.
        conn2 = plug_call("w769-env-floor-secret")
        refute conn2.halted
        assert conn2.assigns[:current_org] == nil
      end)
    end

    test "fail-closed floor: no env var and no matching DB row is a 503 misconfiguration" do
      with_env(nil, fn ->
        conn = plug_call("iat_live_no-such-row")
        assert conn.halted
        assert conn.status == 503
      end)
    end
  end

  # ==================================================================
  # (e) determinism
  # ==================================================================

  test "two mints never collide; hash derivation is deterministic over the raw value" do
    {raw1, t1} = mint!("w769-det-1")
    {raw2, t2} = mint!("w769-det-1")

    assert raw1 != raw2
    assert t1.token_hash != t2.token_hash
    assert t1.id != t2.id

    # Same function, same input, same output -- the hash is a pure
    # function of the raw token (this is exactly what verify/1 relies on).
    assert expected_hash(raw1) == t1.token_hash
    assert expected_hash(raw1) == expected_hash(raw1)

    # Same created_by label mints independent rows -- per-caller labels do
    # not dedupe.
    assert t1.created_by == t2.created_by
  end

  test "pentest lifecycle is deterministic: same input state always yields the same transition outcome" do
    f1 = file_finding!()
    f2 = file_finding!()

    assert f1.status == :open
    assert f2.status == :open

    r1 = f1 |> Ash.Changeset.for_update(:remediate, %{}) |> Ash.update!(authorize?: false)
    r2 = f2 |> Ash.Changeset.for_update(:remediate, %{}) |> Ash.update!(authorize?: false)

    assert r1.status == :remediation_in_progress
    assert r2.status == :remediation_in_progress

    # And the guard rejects the identical illegal transition identically.
    for f <- [r1, r2] do
      assert {:error, %Ash.Error.Invalid{}} =
               f |> Ash.Changeset.for_update(:remediate, %{}) |> Ash.update()
    end
  end

  # ==================================================================
  # (f) org binding on issue/3 (W812) -- resolve_org_id/1's real
  # branches: struct, slug, id fallback, and the typed org_not_found.
  # Distinct from W743's ResolveOrgActor header-path courts (that plug
  # keys on a client-asserted X-Org-Id; this is the token-mint path
  # binding an authenticated operator credential to a real org row).
  # ==================================================================

  describe "(f) org binding on issue/3 (W812)" do
    alias Xaas.Accounts.Org

    defp real_org! do
      Org
      |> Ash.Changeset.for_create(:create, %{
        name: "W812 Org #{System.unique_integer([:positive])}",
        slug: "w812-org-#{System.unique_integer([:positive])}"
      })
      |> Ash.create!(authorize?: false)
    end

    test "issue/3 with a real %Org{} struct binds the token to that org's real id" do
      org = real_org!()

      assert {:ok, _raw, token} = InternalApiTokenAuth.issue("w812-struct", nil, org)
      assert token.org_id == org.id

      reloaded = Ash.get!(InternalApiToken, token.id, authorize?: false)
      assert reloaded.org_id == org.id
    end

    test "issue/3 with a real slug resolves the real Org row; verify/1 + the real plug surface the loaded org" do
      org = real_org!()

      assert {:ok, raw, token} = InternalApiTokenAuth.issue("w812-slug", nil, org.slug)
      assert token.org_id == org.id

      assert {:ok, %InternalApiToken{}} = InternalApiTokenAuth.verify(raw)

      # The plug's resolve_org/1 loads the real row, never just the id
      # (its own moduledoc pins this), and attaches it as current_org.
      conn =
        Plug.Test.conn(:get, "/internal-api/health")
        |> Plug.Conn.put_req_header("authorization", "Bearer #{raw}")

      with_env(nil, fn ->
        conn = XaasWeb.Plugs.RequireInternalApiToken.call(conn, nil)
        refute conn.halted
        assert %Org{id: loaded_id} = conn.assigns[:current_org]
        assert loaded_id == org.id
      end)
    end

    test "issue/3 with the org's own id (uuid fallback path) also resolves" do
      org = real_org!()

      assert {:ok, _raw, token} = InternalApiTokenAuth.issue("w812-uuid", nil, org.id)
      assert token.org_id == org.id
    end

    test "unknown slug AND unknown uuid binary are both the real typed {:org_not_found, identifier} error" do
      unknown_slug = "w812-no-such-org-#{System.unique_integer([:positive])}"
      assert {:error, {:org_not_found, ^unknown_slug}} =
               InternalApiTokenAuth.issue("w812-missing-slug", nil, unknown_slug)

      unknown_uuid = Ecto.UUID.generate()
      assert {:error, {:org_not_found, ^unknown_uuid}} =
               InternalApiTokenAuth.issue("w812-missing-uuid", nil, unknown_uuid)
    end

    test "struct path with a dangling org row: the DB's real FK is the backstop resolve_org_id/1's blind trust of %Org{} structs" do
      # resolve_org_id/1's %Org{} clause trusts the struct's id with no
      # lookup. The real FK (internal_api_tokens_org_id Ash-managed) is the
      # actual backstop: the write itself is refused, typed, at :org_id.
      org = real_org!()

      {:ok, raw_uuid} = Ecto.UUID.dump(org.id)
      {count, _} = Xaas.Repo.delete_all(from(o in "orgs", where: o.id == ^raw_uuid))
      assert count == 1

      assert {:error, %Ash.Error.Invalid{} = error} =
               InternalApiTokenAuth.issue("w812-dangling-struct", nil, org)

      assert Enum.any?(error.errors, fn e ->
               match?(%{field: :org_id, message: "does not exist"}, e)
             end)
    end

    test "an org referenced by a live token cannot be deleted: the real FK restrict is the invariant, so the plug's {:error, _} -> nil downgrade branch is structurally unreachable" do
      org = real_org!()
      {:ok, raw, _token} = InternalApiTokenAuth.issue("w812-fk-invariant", nil, org.slug)

      {:ok, raw_uuid} = Ecto.UUID.dump(org.id)
      raised =
        assert_raise Postgrex.Error, fn ->
          Xaas.Repo.delete_all(from(o in "orgs", where: o.id == ^raw_uuid))
        end

      assert %Postgrex.Error{postgres: %{constraint: "internal_api_tokens_org_id_fkey"}} = raised

      # The invariant holds end-to-end: the token still verifies and the
      # plug still loads the real org row into current_org.
      assert {:ok, %InternalApiToken{org_id: bound_org_id}} = InternalApiTokenAuth.verify(raw)
      assert bound_org_id == org.id

      with_env(nil, fn ->
        conn =
          Plug.Test.conn(:get, "/internal-api/health")
          |> Plug.Conn.put_req_header("authorization", "Bearer #{raw}")
          |> XaasWeb.Plugs.RequireInternalApiToken.call(nil)

        assert %Org{id: loaded_id} = conn.assigns[:current_org]
        assert loaded_id == org.id
        refute conn.halted
      end)
    end
  end
end
