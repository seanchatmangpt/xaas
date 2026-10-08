defmodule Xaas.Deepening.Art267WorkerNotificationLivenessTest do
  @moduledoc """
  Lane W982z — evidenced-line deepening wave 2, corpus line **26.7**
  (Art. 26(7): "Before putting into service or using a high-risk AI system
  at the workplace, deployers who are employers shall inform workers'
  representatives and the affected workers that they will be subject to
  the use of the high-risk AI system.").

  `oversight_governance_test.exs` (w537) courts only the STRUCTURE of
  `worker_notification/0` (paths exist, shape, determinism). The uncovered
  property is LIVENESS: the notification record IS the receipt corpus +
  OCEL event stream, so a real consequential transition must produce a
  real, machine-readable, court-conformant OCEL 2.0 event in the real
  shared log — before the system is used.

  Mutation rationale: if `Xaas.Telemetry.OcelAshEmitter` stops writing
  real events (handler detached, fail-safe law swallowing every append,
  or the log path changes under `worker_notification/0`'s citation), the
  liveness + conformance courts here fail while the structural courts in
  `oversight_governance_test.exs` (path existence, shape, determinism)
  still pass — catching a notification record that exists as data but is
  never written in fact.

  Chicago discipline: real Ash actions over real sandboxed Postgres, the
  real attached telemetry handler, the real shared ndjson on disk — no
  mocks, no fabricated events.
  """

  use Xaas.DataCase, async: false

  # 26.7 is an evidenced corpus line (w537) — eu_ai_act census.
  @moduletag :eu_ai_act

  alias Xaas.Marketplace.Provider
  alias Xaas.Telemetry.OcelAshEmitter
  alias Xaas.Ultracode.Ocel.Validator

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    # Scope this file's reads to its own writes: the shared OCEL log is
    # appended to by every real Ash action in the suite (see
    # ocel_ash_emitter_test.exs's disclosed fixture-scoping setup).
    log_path = OcelAshEmitter.log_path()
    File.mkdir_p!(Path.dirname(log_path))
    File.write!(log_path, "")

    :ok
  end

  defp raw_ocel_lines do
    OcelAshEmitter.log_path()
    |> File.read!()
    |> String.split("\n", trim: true)
  end

  defp event_of(line_doc), do: hd(line_doc["ocel:events"])

  defp actuation_lines(lines) do
    Enum.filter(lines, fn line ->
      event = event_of(line)
      event["attributes"]["action"] == "actuate_status"
    end)
  end

  test "a real consequential transition writes a real, conformant OCEL 2.0 notification event" do
    provider = Xaas.Generator.create_provider!(%{name: "W982z Provider", org_id: "org-w982z"})

    count_before = length(raw_ocel_lines())

    assert {:ok, result} =
             Xaas.Actuation.run(
               Provider,
               :actuate_status,
               %{status: :active},
               subject_id: provider.id,
               idempotency_key: "w982z-267-#{System.unique_integer([:positive])}",
               authorize?: false,
               authority: %{kind: "test_authority", source: "w982z_art_26_7"}
             )

    assert %{status: :succeeded, input_hash: ih, result_hash: rh} = result.receipt
    assert ih && rh

    lines = raw_ocel_lines() |> Enum.drop(count_before) |> Enum.map(&Jason.decode!/1)
    assert lines != [], "no OCEL event was appended for the real actuation"

    [line] = actuation_lines(lines)

    # The worker-visible record of "subject to the use of the system":
    # a machine-readable event naming the exact action on the exact class.
    event = event_of(line)
    assert event["type"] == "provider.actuate_status"
    assert event["attributes"]["action"] == "actuate_status"
    assert event["attributes"]["outcome"] == "ok"
    assert event["attributes"]["resource"] == "Xaas.Marketplace.Provider"
    assert event["attributes"]["duration_ms"] >= 0
    assert is_binary(event["id"]) and event["id"] != ""
    assert {:ok, %DateTime{}, 0} = DateTime.from_iso8601(event["time"])

    # The record is the operator's evidence of participation structure:
    # the class-level resource object relationship is present.
    assert %{"objectId" => "provider", "qualifier" => "provider"} in event["relationships"]

    # Machine-readable format: the line is individually conformant per the
    # project's real OCEL 2.0 conformance court.
    assert {:ok, _report} = Validator.validate(line)
  end

  test "a real policy-denied transition is recorded with a distinguishable error outcome" do
    # A real Ash.Policy.Authorizer denial (Book create with no actor — the
    # disclosed real-minimal failure that reaches the telemetry span; see
    # ocel_ash_emitter_test.exs for why attribute-validation failures do
    # NOT reach it). The affected-workers record must distinguish a
    # transition that was refused from one that happened.
    alias Xaas.Library.Book
    alias Xaas.Accounts.User

    actor =
      Ash.Seed.seed!(User, %{
        email: "w982z-267-#{System.unique_integer([:positive])}@example.com"
      })

    count_before = length(raw_ocel_lines())

    # The denied create itself (with a resolved actor, it succeeds — this
    # also witnesses the transition that DID happen, for contrast).
    {:ok, _book} =
      Book
      |> Ash.Changeset.for_create(
        :create,
        %{
          title: "W982z Notification Fixture",
          author: "Test Author",
          isbn: "W982Z-#{System.unique_integer([:positive])}",
          grade_level: Decimal.new("3"),
          genres: ["Fiction"],
          formats: ["hardcover"],
          available_copies: 0,
          total_copies: 1
        },
        actor: actor
      )
      |> Ash.create()

    assert {:error, %Ash.Error.Forbidden{}} =
             Book
             |> Ash.Changeset.for_create(
               :create,
               %{
                 title: "W982z Notification Fixture (forbidden)",
                 author: "Test Author",
                 isbn: "W982Z-FORBIDDEN-#{System.unique_integer([:positive])}",
                 grade_level: Decimal.new("3"),
                 genres: ["Fiction"],
                 formats: ["hardcover"],
                 available_copies: 0,
                 total_copies: 1
               },
               actor: nil
             )
             |> Ash.create()

    lines = raw_ocel_lines() |> Enum.drop(count_before) |> Enum.map(&Jason.decode!/1)
    outcomes = lines |> Enum.map(&event_of/1) |> Enum.map(& &1["attributes"]["outcome"])

    assert Enum.count(outcomes, &(&1 == "ok")) >= 2
    assert "error" in outcomes,
           "the real policy denial produced no error-outcome notification event: #{inspect(outcomes)}"
  end

  test "the notification record is deterministic on re-read and bound to the cited emitter" do
    assert {:ok, wn} = Xaas.Semantics.OversightGovernance.worker_notification()
    assert wn.notification_record.emitter.module == Xaas.Telemetry.OcelAshEmitter

    provider = Xaas.Generator.create_provider!(%{name: "W982z Det Provider", org_id: "org-w982z"})
    count_before = length(raw_ocel_lines())

    assert {:ok, _} =
             Xaas.Actuation.run(
               Provider,
               :actuate_status,
               %{status: :suspended},
               subject_id: provider.id,
               idempotency_key: "w982z-267-det-#{System.unique_integer([:positive])}",
               authorize?: false,
               authority: %{kind: "test_authority", source: "w982z_art_26_7_det"}
             )

    lines1 =
      raw_ocel_lines() |> Enum.drop(count_before) |> Enum.map(&Jason.decode!/1)

    lines2 =
      raw_ocel_lines() |> Enum.drop(count_before) |> Enum.map(&Jason.decode!/1)

    assert lines1 == lines2, "the notification record is not stable on re-read"
    assert lines1 != []

    # Every line this test captured validates individually — the record the
    # workers' representatives would read is court-conformant, not noise.
    Enum.each(lines1, fn line -> assert {:ok, _} = Validator.validate(line) end)
  end
end
