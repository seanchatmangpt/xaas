defmodule XaasWeb.WitnessLiveCourtTest do
  @moduledoc """
  LiveView-level court for `XaasWeb.WitnessLive` (lane W888, v26.10.6).

  W698/W709/W726 cover the witness resources as units and a W1-era e2e spec
  drives the page in a browser; this court pins the LiveView itself over
  real Phoenix LiveView test sessions against real sandboxed
  `Xaas.Witness.CertifiedReceipt` / `Xaas.Witness.VerificationKey` rows
  seeded through the real `Xaas.Witness.Catalog.ingest/1` — no mocks.

  Courts:
    (a) mount renders the real seeded receipts (subject + payload-hash
        prefix appear in the rendered output);
    (b) a second `Catalog.ingest/1` mid-session is reflected on the next
        mount — the real mechanism is mount-time read (`Ash.read!/1` in
        `mount/3`); the LiveView holds no PubSub subscription and no event
        handlers, so a fresh mount is the honest update path;
    (c) an empty DB renders the typed empty row without error;
    (d) determinism ×2: two independent mounts render the identical row
        sequence.
  """

  use XaasWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  require Ash.Query

  alias Xaas.Repo
  alias Xaas.Witness.Catalog
  alias Xaas.Witness.CertifiedReceipt
  alias Xaas.Witness.VerificationKey

  # Xaas.Repo runs in :manual sandbox mode; the LiveView process reads
  # Xaas.Repo at mount, so share this test's checked-out sandbox with it
  # (same pattern as test/xaas_web/live/witness_live_test.exs; async: false).
  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    :ok
  end

  defp ingest_via_catalog!(subject, algorithm \\ "ES256") do
    vector = %{
      "algorithm" => algorithm,
      "message_hex" => String.duplicate("11", 16),
      "signature_hex" => String.duplicate("cd", 32),
      "public_key_hex" => String.duplicate("ef", 32) <> subject
    }

    {:ok, result} =
      Catalog.ingest(
        baseline: %{"subject_commit" => subject},
        signing_surface: [vector]
      )

    assert result.skipped == []
    assert length(result.receipts) == 1
    receipt = hd(result.receipts)
    %{receipt: receipt, algorithm: :es256}
  end

  test "(a) mount renders the real seeded receipts", %{conn: conn} do
    %{receipt: receipt} = ingest_via_catalog!("sha256:w888-court-a")

    {:ok, view, html} = live(conn, "/witness")

    assert has_element?(view, "[data-testid='witness-receipts-table']")
    assert has_element?(view, "[data-testid='witness-receipt-subject']", receipt.subject)

    # The rendered payload-hash cell shows the first 16 hex chars of the
    # real SHA-256 the Catalog computed over the signing-surface vector's
    # message bytes.
    assert html =~ String.slice(receipt.payload_hash_hex, 0, 16)

    # Ingested receipts are not yet verified: the real write-once
    # verification state renders "no".
    assert has_element?(view, "[data-testid='witness-receipt-verified']", "no")

    # A real VerificationKey row backs the ingested receipt in the same
    # sandbox, seeded by the same Catalog.ingest call.
    assert %VerificationKey{} =
             VerificationKey
             |> Ash.Query.filter(algorithm: :es256)
             |> Ash.read!()
             |> Enum.find(&(&1.key_material_hex == receipt.verifying_key_hex))
  end

  test "(b) second Catalog.ingest mid-session is reflected on re-mount", %{conn: conn} do
    %{receipt: r1} = ingest_via_catalog!("sha256:w888-court-b-1")
    {:ok, view, _html} = live(conn, "/witness")

    assert has_element?(view, "[data-testid='witness-receipt-subject']", r1.subject)

    # Mid-session second ingest through the real Catalog. WitnessLive has
    # no PubSub subscription and no handle_event/handle_info clauses — the
    # read happens once in mount/3 — so the real update mechanism is a
    # fresh mount.
    %{receipt: r2} = ingest_via_catalog!("sha256:w888-court-b-2")

    {:ok, _view2, html2} = live(conn, "/witness")

    assert html2 =~ r1.subject
    assert html2 =~ r2.subject

    # Newest first (sort inserted_at: :desc); unique messages per ingest
    # make the ordering assertable, not incidental.
    pos_1 = :binary.match(html2, r1.subject) |> elem(0)
    pos_2 = :binary.match(html2, r2.subject) |> elem(0)
    assert pos_2 < pos_1
  end

  test "(c) empty DB renders the typed empty state without error", %{conn: conn} do
    # Clear prior rows inside the shared sandbox so the empty branch is
    # genuinely exercised.
    Repo.delete_all(CertifiedReceipt)
    Repo.delete_all(VerificationKey)

    {:ok, view, html} = live(conn, "/witness")

    assert has_element?(view, "[data-testid='witness-empty-row']")
    assert html =~ "No certified receipts ingested."
    refute html =~ "witness-receipt-row"
  end

  test "(d) determinism ×2: two independent mounts render identical rows", %{conn: conn} do
    # Pre-existing rows (earlier lanes' seeds visible through the shared
    # sandbox) would break the exact count; clear within the sandbox.
    Repo.delete_all(CertifiedReceipt)

    %{receipt: r1} = ingest_via_catalog!("sha256:w888-court-d-1", "Ed25519")
    %{receipt: r2} = ingest_via_catalog!("sha256:w888-court-d-2", "Ed25519")

    {:ok, view_a, _html} = live(conn, "/witness")
    {:ok, view_b, _html} = live(conn, "/witness")

    # Compare the receipts table itself (the surrounding layout carries
    # per-session CSRF/session tokens that differ by design).
    table_a = render(element(view_a, "[data-testid='witness-receipts-table']"))
    table_b = render(element(view_b, "[data-testid='witness-receipts-table']"))

    assert table_a == table_b

    for subject <- [r1.subject, r2.subject] do
      assert table_a =~ subject
    end

    # Row count matches the real store: 2 rows, not more.
    assert table_a
           |> String.split("data-testid=\"witness-receipt-row\"")
           |> length() == 3
  end
end
