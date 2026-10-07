defmodule XaasWeb.WitnessLiveTest do
  @moduledoc """
  Coverage for `XaasWeb.WitnessLive` (route proposed at /witness).

  Courts mount the LiveView against real `Xaas.Witness.CertifiedReceipt`
  rows seeded through the real `:ingest` Ash action inside the real Ecto
  sandbox: the page renders the seeded subjects, the verified column
  reflects the real write-once verification state, and the empty case
  renders the typed empty row instead of crashing.
  """

  use XaasWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Xaas.Repo
  alias Xaas.Witness.CertifiedReceipt

  # Xaas.Repo runs in :manual sandbox mode and ConnCase only owns a
  # Xaas.LegacyRepo connection; the LiveView process reads Xaas.Repo at
  # mount, so share the test's checked-out sandbox with it (same pattern
  # as ocel_live_server_chain_test / a2a avatar tests; async: false).
  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    :ok
  end

  defp ingest_receipt!(attrs) do
    attrs =
      Enum.into(attrs, %{
        subject: "test-subject-#{:erlang.unique_integer([:positive])}",
        payload_hash_hex: String.duplicate("ab", 32),
        algorithm: :es256,
        signature_hex: String.duplicate("cd", 32),
        verifying_key_hex: String.duplicate("ef", 32)
      })

    {:ok, receipt} = Ash.create(CertifiedReceipt, attrs, action: :ingest)

    receipt
  end

  test "renders real seeded receipt rows", %{conn: conn} do
    receipt = ingest_receipt!(subject: "sha256:deadbeef-w1-court")

    {:ok, view, _html} = live(conn, "/witness")

    assert has_element?(view, "[data-testid='witness-receipts-table']")
    assert has_element?(view, "[data-testid='witness-receipt-row']")
    assert has_element?(view, "[data-testid='witness-receipt-subject']", receipt.subject)
    assert has_element?(view, "[data-testid='witness-receipt-algorithm']", "es256")
    assert has_element?(view, "[data-testid='witness-receipt-verified']", "no")
  end

  test "renders the verified state of a verified receipt", %{conn: conn} do
    receipt = ingest_receipt!(subject: "sha256:verified-w1-court")

    {:ok, _} = Ash.update(receipt, %{}, action: :record_verification)

    {:ok, view, _html} = live(conn, "/witness")

    assert has_element?(view, "[data-testid='witness-receipt-subject']", receipt.subject)
    assert has_element?(view, "[data-testid='witness-receipt-verified']", "yes")
  end

  test "renders the typed empty state when no receipts exist", %{conn: conn} do
    # Prior tests' seeded rows (and e2e-w55 rows) are visible through the
    # shared sandbox at mount; clear within the sandbox so the empty branch
    # is genuinely exercised.
    Repo.delete_all(CertifiedReceipt)

    {:ok, view, _html} = live(conn, "/witness")

    assert has_element?(view, "[data-testid='witness-empty-row']")
    refute has_element?(view, "[data-testid='witness-receipt-row']")
  end
end
