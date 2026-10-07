defmodule Xaas.Operations.CapabilityLivenessDeepeningTest do
  @moduledoc """
  W750 — composed-court deepening of the capability-liveness ALIVE-receipt
  machinery (`Xaas.Operations.CapabilityLivenessReceipt`,
  `Xaas.Operations.CapabilityLivenessRegressions`, and the real
  /internal-api routes). Chicago-style: real sandboxed Postgres rows, real
  Ash :ingest/:read actions, real HTTP through the token floor. No mocks.

  Asserts the REAL contract, including where the doctrine's standing
  vocabulary (ALIVE requires observed execution; receipts go stale) is NOT
  mechanically enforced — those gaps are asserted as real current behavior
  and typed in docs/sjira/v26.10.6/plans/w750-liveness-deepening.md.
  """

  use XaasWeb.ConnCase

  import Ecto.Query

  alias Xaas.Operations.CapabilityLivenessReceipt
  alias Xaas.Operations.CapabilityLivenessRegressions

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp ingest!(attrs) do
    CapabilityLivenessReceipt
    |> Ash.Changeset.for_create(:ingest, attrs)
    |> Ash.create!(authorize?: false)
  end

  defp base_attrs(overrides) do
    Map.merge(
      %{
        capability: "weaver.w750.check",
        authority: "otel-weaver-v2",
        status: "ALIVE",
        executed: true,
        exit_code: 0,
        subject: "git:w750-#{System.unique_integer([:positive])}"
      },
      Map.new(overrides)
    )
  end

  defp get_rows(conn, capability) do
    conn
    |> put_req_header("authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
    |> put_req_header("accept", "application/vnd.api+json")
    |> get("/internal-api/capability_liveness_receipts?filter[capability]=#{capability}")
    |> json_response(200)
  end

  # (a) A receipt created via the real ingest path is readable through the
  # real token-gated internal-api JSON:API route — full round trip.
  test "real ingest is round-trippable through the real token-gated route" do
    receipt = ingest!(base_attrs([]))

    body = get_rows(build_conn(), receipt.capability)
    assert [row] = body["data"]
    assert row["id"] == receipt.id
    assert row["type"] == "capability_liveness_receipts"
    attrs = row["attributes"]
    assert attrs["capability"] == receipt.capability
    assert attrs["authority"] == "otel-weaver-v2"
    assert attrs["status"] == "ALIVE"
    assert attrs["executed"] == true
    assert attrs["exit_code"] == 0
    assert attrs["subject"] == receipt.subject
  end

  test "route rejects a missing token before any row data is exposed" do
    receipt = ingest!(base_attrs([]))

    resp =
      build_conn()
      |> put_req_header("accept", "application/vnd.api+json")
      |> get("/internal-api/capability_liveness_receipts?filter[capability]=#{receipt.capability}")

    assert resp.status == 401
    refute resp.resp_body =~ receipt.capability
  end

  # (b) ALIVE requires observed execution — mechanically enforced since W768:
  # `status == "ALIVE"` with `executed != true` refuses typed
  # (ALIVE_WITHOUT_EXECUTION) at :ingest, and no row is persisted.
  test "ALIVE with executed:false refuses typed and persists no row" do
    cap = "weaver.w768.alive-gate"

    assert_raise Ash.Error.Invalid, ~r/ALIVE_WITHOUT_EXECUTION/, fn ->
      ingest!(base_attrs(capability: cap, executed: false, exit_code: nil))
    end

    rows =
      CapabilityLivenessReceipt
      |> Ash.read!(authorize?: false)
      |> Enum.filter(&(&1.capability == cap))

    assert rows == []
  end

  test "a fabricated status value refuses typed (INVALID_STATUS_VOCABULARY)" do
    cap = "weaver.w768.vocab-gate"

    assert_raise Ash.Error.Invalid, ~r/INVALID_STATUS_VOCABULARY/, fn ->
      ingest!(base_attrs(capability: cap, status: "TOTALLY-FABRICATED-STANDING"))
    end

    rows =
      CapabilityLivenessReceipt
      |> Ash.read!(authorize?: false)
      |> Enum.filter(&(&1.capability == cap))

    assert rows == []
  end

  test "non-ALIVE standing statuses are unaffected by the gate — even with executed:false" do
    for status <- ["REFUTED", "BLOCKED", "UNKNOWN"] do
      receipt =
        ingest!(base_attrs(status: status, executed: false, exit_code: 1))

      assert receipt.status == status
      assert receipt.executed == false
    end
  end

  # (c) TTL/staleness — REAL contract: there is no TTL. A receipt backdated
  # far into the past is still served as-is through the route; the only
  # "staleness" machinery that exists is (1) idempotent re-ingest (upsert)
  # overwriting status for the same capability+subject, and (2) detect/1's
  # regression rule (latest non-ALIVE after a prior ALIVE, ordered by
  # inserted_at).
  test "no TTL: a backdated receipt is still served verbatim — staleness is not enforced" do
    receipt = ingest!(base_attrs([]))

    backdated = DateTime.add(DateTime.utc_now(), -365 * 24 * 3600, :second)

    {1, _} =
      from(r in CapabilityLivenessReceipt, where: r.id == ^receipt.id)
      |> Xaas.Repo.update_all(set: [inserted_at: backdated])

    body = get_rows(build_conn(), receipt.capability)
    assert [row] = body["data"]
    assert row["attributes"]["status"] == "ALIVE"

    # Regression detector also does not treat age as staleness: a lone
    # year-old ALIVE row yields no regression.
    regressions =
      CapabilityLivenessRegressions.detect()
      |> Enum.filter(&(&1.capability == receipt.capability))

    assert regressions == []
  end

  test "refresh semantics: re-ingest of the same capability+subject overwrites status in place" do
    receipt = ingest!(base_attrs([]))

    _refreshed =
      ingest!(
        base_attrs(
          capability: receipt.capability,
          subject: receipt.subject,
          status: "REFUTED",
          exit_code: 1,
          detail: "re-ingested after a real failing run"
        )
      )

    rows =
      CapabilityLivenessReceipt
      |> Ash.read!(authorize?: false)
      |> Enum.filter(&(&1.capability == receipt.capability))

    assert length(rows) == 1
    assert hd(rows).id == receipt.id
    assert hd(rows).status == "REFUTED"
    assert hd(rows).detail == "re-ingested after a real failing run"

    # And the refresh flips the regression detector: latest non-ALIVE
    # after a prior ALIVE (same row, overwritten) — but note the upsert
    # destroys the prior-ALIVE history, so detect/1 sees only one row and
    # reports NO regression. That is the real, pinned behavior.
    regressions =
      CapabilityLivenessRegressions.detect()
      |> Enum.filter(&(&1.capability == receipt.capability))

    assert regressions == []
  end

  test "regression detection fires only for a real ALIVE-then-non-ALIVE sequence across distinct subjects" do
    cap = "weaver.w750.regression"

    ingest!(base_attrs(capability: cap, status: "ALIVE", subject: "git:w750-was"))
    # Ensure strictly-later inserted_at for the second (same-ms hazard).
    :timer.sleep(2)
    ingest!(base_attrs(capability: cap, status: "BLOCKED", exit_code: 2, subject: "git:w750-now"))

    regressions =
      CapabilityLivenessRegressions.detect()
      |> Enum.filter(&(&1.capability == cap))

    assert [
             %{
               capability: ^cap,
               was: %{status: "ALIVE", subject: "git:w750-was"},
               now: %{status: "BLOCKED", subject: "git:w750-now"}
             }
           ] = regressions
  end

  # (d) Determinism: identical ingests plus repeated reads (DB and HTTP)
  # yield byte-stable results; the upsert identity makes re-running the
  # live-check a no-op, not an append.
  test "determinism: repeated ingest+read cycles converge to one stable row, identically served" do
    receipt = ingest!(base_attrs([]))

    for _ <- 1..3,
        do:
          ingest!(
            base_attrs(
              capability: receipt.capability,
              subject: receipt.subject
            )
          )

    rows =
      CapabilityLivenessReceipt
      |> Ash.read!(authorize?: false)
      |> Enum.filter(&(&1.capability == receipt.capability))

    assert length(rows) == 1
    assert hd(rows).id == receipt.id

    first = get_rows(build_conn(), receipt.capability)

    second =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
      |> put_req_header("accept", "application/vnd.api+json")
      |> get("/internal-api/capability_liveness_receipts?filter[capability]=#{receipt.capability}")
      |> json_response(200)

    assert first == second
    assert [%{}] = first["data"]
  end
end
