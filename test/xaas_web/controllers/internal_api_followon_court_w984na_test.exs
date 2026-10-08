defmodule XaasWeb.Controllers.InternalApiFollowonCourtW984naTest do
  @moduledoc """
  Lane W984na — follow-on court for the 6 same-class JSON:API paths W984lv
  left UNKNOWN (`docs/sjira/v26.10.6/plans/w984lv-probe.md`):

  - `Xaas.Operations.RouteCastleRun`              GET index/read (read-only)
  - `Xaas.Operations.RouteCastleSchedule`         GET index/read (read-only)
  - `Xaas.Operations.RouteCastleSunset`           GET index/read (read-only)
  - `Xaas.Operations.CastleVerbInventoryComponents`      GET index/read (read-only)
  - `Xaas.Operations.CastleVerbFortune5Requirements`     GET index/read (read-only)
  - `Xaas.Operations.ApprovalK8sFaultRemediateSuggest`   GET index/read + POST create + PATCH approve

  Real Chicago-style: real HTTP through the main router's AshJsonApi
  catch-all forward (`XaasWeb.InternalApiRouter`), real bearer token, real
  Ash actions / real sandboxed Postgres rows, zero mocks. Each test names
  the mutant class it kills.

  Disclosed deviation from W984lv's fail-closed-403-create idiom: the
  `/internal-api` forward scope runs `:set_internal_api_system_actor`
  (`lib/xaas_web/router.ex`), and `approval_k8s_fault_remediate_suggest`
  is in that plug's path-segment set with a `bypass action(:create) do
  authorize_if(Xaas.Checks.SystemActor)` carve-out — so a valid-token POST
  on this tier is genuinely ADMITTED (201), not a 403. The fail-closed
  surface on this resource is therefore courted where it actually lives:
  (1) the maker-checker approve validation (self-approval → 422) and
  (2) the 401 token floor on the write route.
  """

  use XaasWeb.ConnCase

  alias Xaas.Operations.{
    ApprovalK8sFaultRemediateSuggest,
    CastleVerbFortune5Requirements,
    CastleVerbInventoryComponents,
    RouteCastleRun,
    RouteCastleSchedule,
    RouteCastleSunset
  }

  alias Xaas.Repo

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp with_internal_api_token(conn) do
    put_req_header(conn, "authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
  end

  defp json_api_conn(conn) do
    conn
    |> put_req_header("accept", "application/vnd.api+json")
    |> put_req_header("content-type", "application/vnd.api+json")
  end

  # Read-only projections have no Ash create action; a real Postgres row
  # via the real repo struct path is the real state, not a double of
  # anything (same idiom as W984lv's projection_row!/1).
  defp projection_row!(schema, extra \\ %{}) do
    struct!(schema, %{id: Ecto.UUID.generate(), requested_by: "w984na-probe"})
    |> Map.merge(extra)
    |> Repo.insert!()
  end

  # --- read-only castle projections (index + read + 404 each) ---

  test "a. route_castle_run index+read+404 over the wire — kills the mutant dropping route_castle_run from the catch-all",
       %{conn: conn} do
    row = projection_row!(RouteCastleRun)

    index_body =
      conn
      |> with_internal_api_token()
      |> json_api_conn()
      |> get("/internal-api/route_castle_run")
      |> json_response(200)

    assert Enum.any?(index_body["data"], &(&1["id"] == row.id))

    read_body =
      conn
      |> with_internal_api_token()
      |> json_api_conn()
      |> get("/internal-api/route_castle_run/#{row.id}")
      |> json_response(200)

    assert read_body["data"]["id"] == row.id
    assert read_body["data"]["type"] == "route_castle_run"
    # requested_by is not public? on this projection, so JSON:API omits it
    # from rendered attributes -- attributes exist but are empty map shape.
    assert is_map(read_body["data"]["attributes"])

    conn
    |> with_internal_api_token()
    |> json_api_conn()
    |> get("/internal-api/route_castle_run/#{Ecto.UUID.generate()}")
    |> json_response(404)
  end

  test "b. route_castle_schedule index+read+404 — kills the mutant dropping route_castle_schedule from the catch-all",
       %{conn: conn} do
    row = projection_row!(RouteCastleSchedule)

    index_body =
      conn
      |> with_internal_api_token()
      |> json_api_conn()
      |> get("/internal-api/route_castle_schedule")
      |> json_response(200)

    assert Enum.any?(index_body["data"], &(&1["id"] == row.id))

    read_body =
      conn
      |> with_internal_api_token()
      |> json_api_conn()
      |> get("/internal-api/route_castle_schedule/#{row.id}")
      |> json_response(200)

    assert read_body["data"]["id"] == row.id

    conn
    |> with_internal_api_token()
    |> json_api_conn()
      |> get("/internal-api/route_castle_schedule/#{Ecto.UUID.generate()}")
      |> json_response(404)
  end

  test "c. route_castle_sunset index+read+404 — kills the mutant dropping route_castle_sunset from the catch-all",
       %{conn: conn} do
    row = projection_row!(RouteCastleSunset)

    index_body =
      conn
      |> with_internal_api_token()
      |> json_api_conn()
      |> get("/internal-api/route_castle_sunset")
      |> json_response(200)

    assert Enum.any?(index_body["data"], &(&1["id"] == row.id))

    read_body =
      conn
      |> with_internal_api_token()
      |> json_api_conn()
      |> get("/internal-api/route_castle_sunset/#{row.id}")
      |> json_response(200)

    assert read_body["data"]["id"] == row.id

    conn
    |> with_internal_api_token()
    |> json_api_conn()
    |> get("/internal-api/route_castle_sunset/#{Ecto.UUID.generate()}")
    |> json_response(404)
  end

  test "d. castle_verb_inventory_components index+read+404 — kills the mutant dropping that read surface",
       %{conn: conn} do
    row = projection_row!(CastleVerbInventoryComponents)

    index_body =
      conn
      |> with_internal_api_token()
      |> json_api_conn()
      |> get("/internal-api/castle_verb_inventory_components")
      |> json_response(200)

    assert Enum.any?(index_body["data"], &(&1["id"] == row.id))

    read_body =
      conn
      |> with_internal_api_token()
      |> json_api_conn()
      |> get("/internal-api/castle_verb_inventory_components/#{row.id}")
      |> json_response(200)

    assert read_body["data"]["id"] == row.id

    conn
    |> with_internal_api_token()
    |> json_api_conn()
    |> get("/internal-api/castle_verb_inventory_components/#{Ecto.UUID.generate()}")
    |> json_response(404)
  end

  test "e. castle_verb_fortune5_requirements index+read+404 — kills the mutant dropping that read surface",
       %{conn: conn} do
    row = projection_row!(CastleVerbFortune5Requirements)

    index_body =
      conn
      |> with_internal_api_token()
      |> json_api_conn()
      |> get("/internal-api/castle_verb_fortune5_requirements")
      |> json_response(200)

    assert Enum.any?(index_body["data"], &(&1["id"] == row.id))

    read_body =
      conn
      |> with_internal_api_token()
      |> json_api_conn()
      |> get("/internal-api/castle_verb_fortune5_requirements/#{row.id}")
      |> json_response(200)

    assert read_body["data"]["id"] == row.id

    conn
    |> with_internal_api_token()
    |> json_api_conn()
    |> get("/internal-api/castle_verb_fortune5_requirements/#{Ecto.UUID.generate()}")
    |> json_response(404)
  end

  # --- approval_k8s_fault_remediate_suggest (read + real write surface) ---

  test "f. approval_k8s_fault_remediate_suggest index+read+404 with public attrs — kills the mutant dropping that read surface",
       %{conn: conn} do
    row =
      ApprovalK8sFaultRemediateSuggest
      |> Ash.Changeset.for_create(
        :create,
        %{requested_by: "w984na-maker", approved_by: "w984na-checker"}
      )
      |> Ash.create!(authorize?: false)

    index_body =
      conn
      |> with_internal_api_token()
      |> json_api_conn()
      |> get("/internal-api/approval_k8s_fault_remediate_suggest")
      |> json_response(200)

    assert Enum.any?(index_body["data"], &(&1["id"] == row.id))

    read_body =
      conn
      |> with_internal_api_token()
      |> json_api_conn()
      |> get("/internal-api/approval_k8s_fault_remediate_suggest/#{row.id}")
      |> json_response(200)

    assert read_body["data"]["id"] == row.id
    assert read_body["data"]["attributes"]["requested_by"] == "w984na-maker"
    assert read_body["data"]["attributes"]["approved_by"] == "w984na-checker"

    conn
    |> with_internal_api_token()
    |> json_api_conn()
    |> get("/internal-api/approval_k8s_fault_remediate_suggest/#{Ecto.UUID.generate()}")
    |> json_response(404)
  end

  test "g. valid-token POST create on approval_k8s_fault_remediate_suggest is admitted (SystemActor) — kills the mutant breaking the XAAS-2602 carve-out on this tier",
       %{conn: conn} do
    body =
      conn
      |> with_internal_api_token()
      |> json_api_conn()
      |> post("/internal-api/approval_k8s_fault_remediate_suggest", %{
        "data" => %{
          "type" => "approval_k8s_fault_remediate_suggest",
          "attributes" => %{
            "requested_by" => "w984na-wire-maker",
            "approved_by" => "w984na-wire-checker"
          }
        }
      })
      |> json_response(201)

    assert body["data"]["attributes"]["requested_by"] == "w984na-wire-maker"

    # The row really persisted (real Postgres read, not just the response).
    assert Repo.get!(ApprovalK8sFaultRemediateSuggest, body["data"]["id"]).requested_by ==
             "w984na-wire-maker"
  end

  test "h. PATCH approve with self-approval is fail-closed 400 (maker-checker RequiresApprover validation; same wire status as the /api sibling court) — kills the mutant removing the self-approval validation",
       %{conn: conn} do
    row =
      ApprovalK8sFaultRemediateSuggest
      |> Ash.Changeset.for_create(
        :create,
        %{requested_by: "w984na-self", approved_by: nil}
      )
      |> Ash.create!(authorize?: false)

    conn =
      conn
      |> with_internal_api_token()
      |> json_api_conn()
      |> patch("/internal-api/approval_k8s_fault_remediate_suggest/#{row.id}", %{
        "data" => %{
          "type" => "approval_k8s_fault_remediate_suggest",
          "id" => row.id,
          "attributes" => %{"approved_by" => "w984na-self"}
        }
      })

    assert conn.status == 400
    # real Postgres state: the self-approval did not persist
    assert Repo.get!(ApprovalK8sFaultRemediateSuggest, row.id).approved_by == nil
  end

  # --- provenance closing test (W984nu, closes W984nl's surviving M4) ---

  test "j. valid token but NON-system provenance on approval_k8s_fault_remediate_suggest create is fail-closed 403 — kills W984nl's surviving M4 compound (plug arm drop + :create bypass widened to always())",
       %{conn: conn} do
    # The court's admission-provenance discriminator: the carve-out plug
    # (`XaasWeb.Plugs.SetInternalApiSystemActor`) only mints
    # `Xaas.SystemAuthority.new(:internal_api)` when NO actor is already on
    # the conn. Presetting a NON-system actor makes the plug a no-op, so the
    # request reaches `:create` WITHOUT the SystemActor provenance. Under the
    # real policy (`authorize_if({Xaas.Checks.SystemActor, []})`) this is
    # fail-closed 403; under W984nl's M4 compound (segment dropped from the
    # plug AND the `:create` bypass widened to `authorize_if(always())`) the
    # same request is admitted 201 — the mutant class is now killed.
    impostor = %{"w984nu_non_system_actor" => true}

    conn
    |> with_internal_api_token()
    |> json_api_conn()
    |> Ash.PlugHelpers.set_actor(impostor)
    |> post("/internal-api/approval_k8s_fault_remediate_suggest", %{
      "data" => %{
        "type" => "approval_k8s_fault_remediate_suggest",
        "attributes" => %{
          "requested_by" => "w984nu-impostor",
          "approved_by" => "w984nu-impostor-checker"
        }
      }
    })
    |> json_response(403)

    # Provenance assertion: the impostor's row must NOT have persisted.
    refute Repo.exists?(
             ApprovalK8sFaultRemediateSuggest
             |> Ash.Query.filter(requested_by == "w984nu-impostor")
           )

    # Same fail-closed surface for a SYSTEM actor of the WRONG service: the
    # exact-subject mapping requires :internal_api for this :create.
    wrong_service = Xaas.SystemAuthority.new(:webhook_dispatcher)

    conn
    |> with_internal_api_token()
    |> json_api_conn()
    |> Ash.PlugHelpers.set_actor(wrong_service)
    |> post("/internal-api/approval_k8s_fault_remediate_suggest", %{
      "data" => %{
        "type" => "approval_k8s_fault_remediate_suggest",
        "attributes" => %{
          "requested_by" => "w984nu-wrong-service",
          "approved_by" => "w984nu-wrong-service-checker"
        }
      }
    })
    |> json_response(403)

    refute Repo.exists?(
             ApprovalK8sFaultRemediateSuggest
             |> Ash.Query.filter(requested_by == "w984nu-wrong-service")
           )
  end

  # --- auth floor over the newly-courted paths ---

  test "i. no bearer on the newly-courted paths (reads AND create) is 401 — kills the mutant exempting these paths from the token floor",
       %{conn: conn} do
    for path <- [
          "/internal-api/route_castle_run",
          "/internal-api/route_castle_schedule",
          "/internal-api/route_castle_sunset",
          "/internal-api/castle_verb_inventory_components",
          "/internal-api/castle_verb_fortune5_requirements",
          "/internal-api/approval_k8s_fault_remediate_suggest"
        ] do
      conn
      |> json_api_conn()
      |> get(path)
      |> json_response(401)
    end

    # The write route carries the same floor.
    conn
    |> json_api_conn()
    |> post("/internal-api/approval_k8s_fault_remediate_suggest", %{
      "data" => %{
        "type" => "approval_k8s_fault_remediate_suggest",
        "attributes" => %{"requested_by" => "x", "approved_by" => "y"}
      }
    })
    |> json_response(401)
  end
end
