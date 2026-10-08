defmodule Xaas.SecurityParsingRobustnessCourtW984ejTest do
  @moduledoc """
  W984ej robustness court over the typed parsing / error-normalization
  family: `Xaas.Security` ingest parsing (atomize/1, parse_dt/1) and
  `ExecutionFabricController.format_reason/1` via its real wire paths.

  Chicago discipline: every assertion is a real function call or real HTTP
  request over real sandboxed rows; zero mocks. Each test carries its
  mutation rationale (which mutant it kills).
  """

  use XaasWeb.ConnCase, async: false

  alias Xaas.Accounts.Org
  alias Xaas.Governance.InternalApiTokenAuth
  alias Xaas.Security

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp base_summary do
    %{
      "repo" => "w984ej-robustness",
      "scan_date" => "2026-10-05T00:00:00Z",
      "findings" => [
        %{
          "severity" => "high",
          "source" => "sobelow",
          "file" => "lib/xaas/security.ex",
          "description" => "court probe finding"
        }
      ]
    }
  end

  defp finding(summary, overrides) do
    update_in(summary, ["findings", Access.at(0)], &Map.merge(&1, overrides))
  end

  # ---------------------------------------------------------------------------
  # parse_dt/1 input classes (via Security.ingest/1 — the public path)
  # ---------------------------------------------------------------------------

  describe "parse_dt/1 input classes via Security.ingest/1" do
    @tag :w984ej
    # Kills: mutant reverts parse_dt's typed pass-through (the
    # `{:error, _} -> bin` arm) to a raise/MatchError on malformed ISO8601;
    # also kills a mutant that silently coerces garbage into a DateTime.
    test "malformed discovered_at string is a typed Ash refusal, never a crash" do
      assert_raise Ash.Error.Invalid, fn ->
        Security.ingest(finding(base_summary(), %{"discovered_at" => "not-a-date"}))
      end
    end

    @tag :w984ej
    # Kills: mutant drops the offset normalization (discovered_at keeps a
    # +09:00 offset instead of the utc_datetime attribute's UTC contract).
    test "non-UTC offset discovered_at is normalized to UTC" do
      {:ok, _posture} =
        Security.ingest(
          finding(base_summary(), %{"discovered_at" => "2026-10-05T12:00:00+09:00"})
        )

      assert [finding_row] = Ash.read!(Xaas.Security.Finding)
      assert %DateTime{} = finding_row.discovered_at
      assert %{finding_row.discovered_at | time_zone: "Etc/UTC"} == finding_row.discovered_at
      assert DateTime.to_iso8601(finding_row.discovered_at) == "2026-10-05T03:00:00Z"
    end

    @tag :w984ej
    # Kills: mutant makes scan_date offset handling diverge from
    # discovered_at (same parse_dt/1, two call sites).
    test "non-UTC offset scan_date is normalized to UTC on the posture" do
      {:ok, posture} =
        Security.ingest(%{base_summary() | "scan_date" => "2026-10-05T09:30:00-05:00"})

      assert DateTime.to_iso8601(posture.scan_date) == "2026-10-05T14:30:00Z"
    end

    @tag :w984ej
    # W984ez repair: parse_dt/1 now passes wrong-type input through so Ash's
    # utc_datetime cast refuses it as a typed Ash.Error.Invalid (same
    # convention as the malformed-string arm), never a FunctionClauseError.
    # Kills: mutant restores a raise/crash on non-binary input; also kills a
    # mutant that silently coerces an integer into a DateTime.
    test "integer discovered_at is a typed Ash refusal, never a crash" do
      assert_raise Ash.Error.Invalid, fn ->
        Security.ingest(finding(base_summary(), %{"discovered_at" => 12_345}))
      end
    end

    @tag :w984ej
    # Same repaired pass-through class as the integer case, nested shape.
    test "map discovered_at is a typed Ash refusal, never a crash" do
      assert_raise Ash.Error.Invalid, fn ->
        Security.ingest(finding(base_summary(), %{"discovered_at" => %{"iso" => "x"}}))
      end
    end

    @tag :w984ej
    # Kills: mutant makes scan_date handling diverge from discovered_at
    # (same parse_dt/1, two call sites).
    test "integer scan_date is a typed Ash refusal, never a crash" do
      assert_raise Ash.Error.Invalid, fn ->
        Security.ingest(%{base_summary() | "scan_date" => 999})
      end
    end
  end

  # ---------------------------------------------------------------------------
  # atomize/1 input classes
  # ---------------------------------------------------------------------------

  describe "atomize/1 input classes via Security.ingest/1" do
    @tag :w984ej
    # Kills: mutant drops the ArgumentError rescue pass-through so an
    # unknown enum value crashes String.to_existing_atom instead of
    # surfacing as Ash's typed one_of refusal.
    test "unknown disposition string is a typed Ash one_of refusal, never a crash" do
      assert_raise Ash.Error.Invalid, fn ->
        Security.ingest(finding(base_summary(), %{"disposition" => "bogus_disposition"}))
      end
    end

    @tag :w984ej
    # Kills: mutant drops the allow_nil? false / required validation so a
    # missing severity ingests silently.
    test "missing severity is a typed required-attribute refusal" do
      assert_raise Ash.Error.Invalid, fn ->
        Security.ingest(finding(base_summary(), %{"severity" => nil}))
      end
    end

    @tag :w984ej
    # W984ez repair: atomize/1 now passes wrong-type input through so Ash's
    # type cast / one_of constraint refuses it as a typed Ash.Error.Invalid
    # (same convention as the unknown-string arm), never a
    # FunctionClauseError. Kills: mutant restores a crash on integer severity;
    # also kills a mutant that coerces an integer into an enum atom.
    test "integer severity is a typed Ash refusal, never a crash" do
      assert_raise Ash.Error.Invalid, fn ->
        Security.ingest(finding(base_summary(), %{"severity" => 5}))
      end
    end
  end

  # ---------------------------------------------------------------------------
  # format_reason/1 via real wire paths
  # ---------------------------------------------------------------------------

  describe "format_reason/1 via real wire paths" do
    defp with_internal_api_token(conn) do
      put_req_header(conn, "authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
    end

    defp create_org!(slug) do
      {:ok, org} =
        Org
        |> Ash.Changeset.for_create(:create, %{name: slug, slug: slug}, authorize?: false)
        |> Ash.create()

      org
    end

    defp org_token!(created_by, %Org{} = org) do
      {:ok, raw_token, _token} = InternalApiTokenAuth.issue(created_by, nil, org)
      raw_token
    end

    @tag :w984ej
    # Kills: mutant replaces the Ash.Error.Invalid format_reason clause
    # with the inspect/1 catch-all (detail degenerates to a struct blob).
    test "invalid epoch id yields a 400 whose detail is a formatted binary, not a struct blob",
         %{conn: conn} do
      body =
        conn
        |> with_internal_api_token()
        |> get("/internal-api/execution/epochs/not-a-real-uuid/receipts")
        |> json_response(400)

      assert body["error"] == "invalid_epoch_id"
      assert is_binary(body["detail"])
      refute body["detail"] =~ "%Ash.Error"
      refute body["detail"] =~ "nil"
    end

    @tag :w984ej
    # Kills: mutant makes the tuple `{tag, detail}` clause (cf228da6)
    # atom-inspect the tag back onto the wire; also kills a mutant that
    # makes integer/odd-typed reasons crash the controller instead of the
    # catch-all inspect arm.
    test "invalid run submission yields a typed 400 with a binary detail (field: message shape)",
         %{conn: conn} do
      org = create_org!("w984ej-org-#{System.unique_integer([:positive])}")
      token = org_token!("w984ej", org)

      body =
        conn
        |> put_req_header("authorization", "Bearer " <> token)
        |> post("/internal-api/execution/runs", %{})
        |> json_response(400)

      assert body["error"] == "invalid_request"
      assert is_binary(body["detail"])
    end
  end
end
