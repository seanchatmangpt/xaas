defmodule XaasWeb.FabricController do
  @moduledoc """
  Bounded runtime fabric (`/internal-api/fabric`, protocol `xaas-fabric/1`) --
  the outbound-only surface a remote client (chatgpt-cloud-elixir
  `mix xaas_runtime.fabric`) drives:

      GET  /probe                          capabilities + protocol + long-poll bound
      POST /admit                          {"capabilities": [...]} -> admitted / refused
      POST /runs                           idempotent submit (org-scoped token only)
      GET  /epochs/:epoch_id/receipts      bounded long-poll (wait_ms <= 25000)
      POST /actuate                        403 REFUSED(authority_ceiling:actuate)

  Behind `RequireInternalApiToken` like every `/internal-api` route. Each action
  first admits its own capability through `Xaas.Tunnel.Capabilities`; `actuate`
  is refused by authority ceiling in every state. Execution itself stays on the
  provider-pull seam (`/internal-api/execution/mcp` claim_next / close_candidate);
  this scope adds no MCP verb and leaves the zcode plugin projection unchanged.

  HANDWRITTEN.md: UNSUPPORTED(generator-capability) -- no admitted pack renders a
  Phoenix JSON scope from the tunnel ontology.
  """

  use XaasWeb, :controller

  alias Xaas.Accounts.Org
  alias Xaas.Tunnel.{Capabilities, Fabric, Receipt, Submit}
  alias Xaas.Ultracode.Epoch

  @poll_interval_ms 500
  @standing_outcomes ~w(alive partial_alive blocked build_broken unsupported refused)a

  def probe(conn, _params) do
    with :ok <- gate(conn, "fabric.probe") do
      org_scoped? = match?(%Org{}, conn.assigns[:current_org])

      body = %{
        "protocol" => Fabric.protocol(),
        "capabilities" => Capabilities.allowlist(),
        "refused" => Map.new(Capabilities.refused(), fn {k, v} -> {k, Atom.to_string(v)} end),
        "long_poll_max_ms" => Fabric.long_poll_max_ms(),
        "org_scoped?" => org_scoped?
      }

      body =
        if org_scoped?,
          do: body,
          else: Map.put(body, "blocked", %{"run.submit" => "BLOCKED(org_scoped_token_required)"})

      json(conn, body)
    end
  end

  def admit(conn, params) when is_map(params) do
    with :ok <- gate(conn, "fabric.probe") do
      %{admitted: admitted, refused: refused} = Capabilities.admit_set(params["capabilities"])

      json(conn, %{
        "admitted" => admitted,
        "refused" => Enum.map(refused, fn {verb, reason} -> [verb, Atom.to_string(reason)] end)
      })
    end
  end

  def submit(conn, params) do
    with :ok <- gate(conn, "run.submit"),
         {:ok, org} <- org(conn) do
      case Submit.submit(org, params) do
        {:ok, %{run: run, epoch: epoch, replay?: replay?}} ->
          conn
          |> put_status(if replay?, do: 200, else: 201)
          |> json(%{
            "run_id" => run.id,
            "epoch_id" => epoch.id,
            "exact_subject" => epoch.exact_subject,
            "replay" => replay?
          })

        {:error, :idempotency_key_required} ->
          refused(conn, 422, "idempotency_key_required")

        {:error, reason} ->
          XaasWeb.ExecutionFabricController.create_run_error(conn, reason)
      end
    end
  end

  def receipts(conn, %{"epoch_id" => epoch_id} = params) do
    with :ok <- gate(conn, "epoch.receipts"),
         {:ok, org} <- org(conn),
         {:ok, epoch} <- visible_epoch(conn, org, epoch_id) do
      deadline = System.monotonic_time(:millisecond) + Fabric.wait_ms(params["wait_ms"])
      poll(conn, epoch, params["after"], deadline)
    end
  end

  def actuate(conn, _params) do
    {:refused, {reason, verb}} = Capabilities.admit("actuate")
    refused(conn, 403, "#{reason}:#{verb}")
  end

  # --- long-poll -------------------------------------------------------------

  defp poll(conn, %Epoch{id: id} = epoch, after_digest, deadline) do
    sealed = sealed_receipts(id)
    cursor = sealed |> List.first() |> then(&(&1 && &1["digest"]))

    cond do
      sealed != [] and cursor != after_digest ->
        json(conn, %{
          "epoch_id" => id,
          "state" => "sealed",
          "receipts" => sealed,
          "cursor" => cursor
        })

      System.monotonic_time(:millisecond) >= deadline ->
        conn
        |> put_resp_header("x-fabric-state", state_name(epoch))
        |> send_resp(204, "")

      true ->
        Process.sleep(
          min(@poll_interval_ms, max(deadline - System.monotonic_time(:millisecond), 0))
        )

        poll(conn, reload(epoch), after_digest, deadline)
    end
  end

  # Newest standing-family receipt first; heartbeat receipts are not standing.
  defp sealed_receipts(epoch_id) do
    case Xaas.Ultracode.Receipt.for_epoch(epoch_id) do
      {:ok, receipts} ->
        receipts
        |> Enum.filter(&(&1.outcome in @standing_outcomes))
        |> Enum.sort_by(& &1.sealed_at, {:desc, DateTime})
        |> Enum.map(fn r ->
          wire = Receipt.from_ultracode(r)
          %{"receipt" => wire, "digest" => Receipt.digest(wire)}
        end)

      {:error, _} ->
        []
    end
  end

  defp reload(%Epoch{id: id} = epoch) do
    case Ash.get(Epoch, id, action: :read_unscoped, authorize?: false) do
      {:ok, %Epoch{} = fresh} -> fresh
      _ -> epoch
    end
  end

  defp state_name(%Epoch{state: :running, leased_to: who}) when not is_nil(who), do: "leased"
  defp state_name(%Epoch{state: state}), do: Atom.to_string(state)

  # --- gates -----------------------------------------------------------------

  defp gate(conn, verb) do
    case Capabilities.admit(verb) do
      :ok -> :ok
      {:refused, {reason, v}} -> refused(conn, 403, "#{reason}:#{v}")
    end
  end

  defp org(conn) do
    case conn.assigns[:current_org] do
      %Org{} = org ->
        {:ok, org}

      _ ->
        conn
        |> put_status(403)
        |> json(%{"standing" => "BLOCKED", "reason" => "org_scoped_token_required"})
    end
  end

  defp visible_epoch(conn, %Org{id: org_id}, epoch_id) do
    with {:ok, uuid} <- Ecto.UUID.cast(epoch_id),
         {:ok, %Epoch{} = epoch} <- Ash.get(Epoch, uuid, tenant: org_id, authorize?: false) do
      {:ok, epoch}
    else
      :error ->
        refused(conn, 400, "invalid_epoch_id")

      _ ->
        json(put_status(conn, 404), %{"standing" => "BLOCKED", "reason" => "epoch_not_visible"})
    end
  end

  defp refused(conn, status, reason) do
    conn
    |> put_status(status)
    |> json(%{"standing" => "REFUSED", "reason" => reason})
  end
end
