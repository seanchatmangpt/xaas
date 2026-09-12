defmodule Xaas.Test.SIP2TestServer do
  @moduledoc """
  Real TCP server speaking the real SIP2 wire format, used only in test to
  give `Xaas.Library.ILSRepo.SIP2Adapter` a real socket to round-trip
  against. Not a mock of `ILSRepo` -- it never implements the `ILSRepo`
  behaviour and knows nothing about it; it only understands raw SIP2
  request/response bytes on the wire, the same way a real ILS vendor's
  SIP2 endpoint would.

  Handles message codes `93` (Login), `23` (Patron Status Request), and
  `17` (Item Information Request), responding with real `94`/`24`/`18`
  SIP2 wire-format messages built from a small seeded fixture.
  """

  @known_patron "MAYA-R-001"
  @known_item "BK-1001"

  @doc """
  Starts a real `:gen_tcp` listen socket on an OS-assigned ephemeral port
  and spawns a real accept loop. Returns `{:ok, port}`.
  """
  @spec start() :: {:ok, :inet.port_number()}
  def start do
    {:ok, listen_socket} =
      :gen_tcp.listen(0, [:binary, packet: :raw, active: false, reuseaddr: true])

    {:ok, port} = :inet.port(listen_socket)

    spawn_link(fn -> accept_loop(listen_socket) end)

    {:ok, port}
  end

  defp accept_loop(listen_socket) do
    case :gen_tcp.accept(listen_socket) do
      {:ok, client_socket} ->
        spawn(fn -> serve(client_socket) end)
        accept_loop(listen_socket)

      {:error, :closed} ->
        :ok
    end
  end

  defp serve(socket) do
    case recv_message(socket, <<>>) do
      {:ok, message} ->
        case handle_message(message) do
          {:reply, response} ->
            :gen_tcp.send(socket, response)
            serve(socket)

          :close ->
            :gen_tcp.close(socket)
        end

      {:error, _reason} ->
        :gen_tcp.close(socket)
    end
  end

  defp recv_message(socket, acc) do
    case :gen_tcp.recv(socket, 0, 5_000) do
      {:ok, chunk} ->
        combined = acc <> chunk

        if String.contains?(combined, "\r") do
          [message, _rest] = String.split(combined, "\r", parts: 2)
          {:ok, message}
        else
          recv_message(socket, combined)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle_message("93" <> _rest) do
    # Login response: fixed 1-char ok flag ("1" == success)
    {:reply, "941\r"}
  end

  defp handle_message("23" <> rest) do
    fields = parse_variable_fields(rest)
    patron_id = Map.get(fields, "AA")

    # SIP2 patron status fixed field is exactly 14 characters.
    patron_status_ok = "Y  Y" <> String.duplicate(" ", 10)
    patron_status_missing = "Y  N" <> String.duplicate(" ", 10)

    if patron_id == @known_patron do
      {:reply,
       "24" <>
         patron_status_ok <>
         "001" <>
         transaction_date() <>
         "AO" <>
         Map.get(fields, "AO", "TESTLIB") <>
         "|AA" <>
         patron_id <>
         "|AE" <>
         "Maya R." <>
         "|BLY|AFOK|\r"}
    else
      {:reply,
       "24" <>
         patron_status_missing <>
         "001" <>
         transaction_date() <>
         "AO" <>
         Map.get(fields, "AO", "TESTLIB") <>
         "|AA" <>
         to_string(patron_id) <>
         "|BLN|\r"}
    end
  end

  defp handle_message("17" <> rest) do
    fields = parse_variable_fields(rest)
    item_id = Map.get(fields, "AB")

    if item_id == @known_item do
      {:reply,
       "18" <>
         "03" <>
         "02" <>
         "01" <>
         transaction_date() <>
         "AO" <>
         Map.get(fields, "AO", "TESTLIB") <>
         "|AB" <>
         item_id <>
         "|AJThe Salt Road Cipher|APMain Branch|CS813.6 OKO|AFOK|\r"}
    else
      {:reply, "18" <> "01" <> "00" <> "00" <> transaction_date() <> "AOTESTLIB|\r"}
    end
  end

  defp handle_message(_other), do: :close

  defp parse_variable_fields(body) do
    body
    |> String.split("|")
    |> Enum.reject(&(&1 == ""))
    |> Enum.reduce(%{}, fn field, acc ->
      case String.split_at(field, 2) do
        {id, value} -> Map.put(acc, id, value)
      end
    end)
  end

  defp transaction_date do
    now = DateTime.utc_now()
    date = now |> DateTime.to_date() |> Date.to_string() |> String.replace("-", "")

    time =
      now |> DateTime.to_time() |> Time.to_string() |> String.replace(":", "") |> String.slice(0, 6)

    date <> "0000" <> time
  end
end
