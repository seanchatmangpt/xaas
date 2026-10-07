defmodule XaasWeb.WitnessLive do
  # Coordinator seam — proposed router.ex line (do NOT commit router.ex in this lane;
  # the coordinator owns router.ex). Add inside the `scope "/", XaasWeb do
  # pipe_through(:browser)` block, next to the other public browser LiveViews:
  #
  #   live("/witness", WitnessLive)
  #
  @moduledoc """
  Read-only certified-receipt witness surface over `Xaas.Witness` (lane W1,
  v26.10.6 fleet convergence).

  Lists `Xaas.Witness.CertifiedReceipt` rows via a real read-only Ash read
  (`Ash.Query` sort, `Ash.read!/1`). No mutations, no forms, no events: the
  LiveView holds no write path at all. The resource's policy floor is
  preserved untouched: `:read` is the only generally-authorized action and
  every mutating action remains behind its existing typed gates.
  """

  use XaasWeb, :live_view

  alias Xaas.Witness.CertifiedReceipt

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:receipts, list_receipts())
      |> assign(:page_title, "Witness — Certified Receipts")

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-6xl min-h-screen bg-slate-950 text-slate-100 p-6 space-y-6">
      <header>
        <h1 class="text-2xl font-bold">Certified Receipts</h1>
        <p class="text-slate-400 text-sm mt-1">Read-only certified-receipt witness surface.</p>
      </header>
      <p>Read-only certified-receipt witness surface (lane W1).</p>

      <table data-testid="witness-receipts-table">
        <thead>
          <tr>
            <th>Subject</th>
            <th>Algorithm</th>
            <th>Payload hash</th>
            <th>Signature</th>
            <th>Verified</th>
            <th>Ingested at</th>
          </tr>
        </thead>
        <tbody>
          <%= if @receipts == [] do %>
            <tr data-testid="witness-empty-row">
              <td colspan="6">No certified receipts ingested.</td>
            </tr>
          <% else %>
            <%= for receipt <- @receipts do %>
              <tr data-testid="witness-receipt-row">
                <td data-testid="witness-receipt-subject">{receipt.subject}</td>
                <td data-testid="witness-receipt-algorithm">{receipt.algorithm}</td>
                <td>{String.slice(receipt.payload_hash_hex, 0, 16)}</td>
                <td>{String.slice(receipt.signature_hex, 0, 16)}…</td>
                <td data-testid="witness-receipt-verified">
                  {if receipt.verified, do: "yes", else: "no"}
                </td>
                <td>{Calendar.strftime(receipt.inserted_at, "%Y-%m-%d %H:%M:%S UTC")}</td>
              </tr>
            <% end %>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  defp list_receipts do
    CertifiedReceipt
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read!()
  end
end
