defmodule Xaas.Library.ILSRepo.SIP2Adapter do
  @moduledoc """
  Real `:gen_tcp` SIP2 (3M Standard Interchange Protocol, Version 2) client
  implementing `Xaas.Library.ILSRepo`.

  Encodes and decodes the real SIP2 wire format: fixed-width positional
  fields immediately after the 2-digit message code, followed by
  `|`-terminated variable-length subfields (each a 2-character field
  identifier plus its value), with each complete message terminated by
  `\\r`. Message pairs implemented:

    * `93`/`94` -- Login Request/Response (sent once per connection, if the
      configured terminal password/login are present).
    * `23`/`24` -- Patron Status Request/Response.
    * `17`/`18` -- Item Information Request/Response.

  ## Status: PARTIAL_ALIVE

  This adapter is protocol-verified only: `test/xaas/library/ils_repo/sip2_adapter_test.exs`
  exercises a real TCP round trip against a real local SIP2 test server
  (`test/support/sip2_test_server.ex`), with real wire-format
  encode/decode assertions. It has **not** been verified against any real
  ILS vendor SIP2 endpoint (Follett, SirsiDynix, Polaris, etc.) -- no such
  endpoint, account, or credentials exist in this environment. Do not
  represent this as end-to-end-verified against a live ILS.

  Not the configured default -- `Xaas.Library.ILSRepo.FixtureAdapter`
  remains the default per `config/config.exs`, since no real vendor
  endpoint exists to validate this adapter against in production.
  """

  @behaviour Xaas.Library.ILSRepo

  alias Xaas.Library.ILSRepo

  @default_timeout 5_000

  @doc """
  Runtime connection options, read from `Application.get_env/3` (never
  hardcoded), keyed on this module.

      config :xaas, Xaas.Library.ILSRepo.SIP2Adapter,
        host: "sip2.example-ils.test",
        port: 6001,
        institution_id: "WILLOWCREEK",
        terminal_password: nil,
        login_user_id: nil,
        login_password: nil,
        timeout: 5_000
  """
  @spec connection_opts() :: keyword()
  def connection_opts do
    Application.get_env(:xaas, __MODULE__, [])
  end

  @impl ILSRepo
  def get_catalog(_school_id) do
    {:error, :not_supported_by_sip2}
  end

  @impl ILSRepo
  def get_circulation_history(_student_id) do
    {:error, :not_supported_by_sip2}
  end

  @impl ILSRepo
  def patron_status(patron_id) do
    with_connection(fn socket, opts ->
      request = encode_patron_status_request(patron_id, opts)

      with {:ok, response} <- send_and_receive(socket, request) do
        decode_patron_status_response(response)
      end
    end)
  end

  @impl ILSRepo
  def item_information(item_id) do
    with_connection(fn socket, opts ->
      request = encode_item_information_request(item_id, opts)

      with {:ok, response} <- send_and_receive(socket, request) do
        decode_item_information_response(response)
      end
    end)
  end

  # -- connection lifecycle -----------------------------------------------

  defp with_connection(fun) do
    opts = connection_opts()
    host = Keyword.fetch!(opts, :host) |> to_charlist()
    port = Keyword.fetch!(opts, :port)
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    with {:ok, socket} <- :gen_tcp.connect(host, port, [:binary, active: false, packet: :raw], timeout),
         :ok <- maybe_login(socket, opts, timeout),
         result <- fun.(socket, opts) do
      :gen_tcp.close(socket)
      result
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp maybe_login(socket, opts, _timeout) do
    case Keyword.get(opts, :login_user_id) do
      nil ->
        :ok

      login_user_id ->
        request = encode_login_request(login_user_id, Keyword.get(opts, :login_password, ""), opts)

        case send_and_receive(socket, request) do
          {:ok, "94" <> rest} ->
            case String.first(rest) do
              "1" -> :ok
              _ -> {:error, :login_failed}
            end

          {:ok, _other} ->
            {:error, :unexpected_login_response}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp send_and_receive(socket, message) do
    with :ok <- :gen_tcp.send(socket, message),
         {:ok, data} <- recv_until_terminator(socket, <<>>) do
      {:ok, String.trim_trailing(data, "\r")}
    end
  end

  defp recv_until_terminator(socket, acc) do
    case :gen_tcp.recv(socket, 0, @default_timeout) do
      {:ok, chunk} ->
        combined = acc <> chunk

        if String.contains?(combined, "\r") do
          {:ok, combined}
        else
          recv_until_terminator(socket, combined)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # -- encoding: real SIP2 wire format --------------------------------------
  #
  # Wire shape: <2-char message code><fixed-width fields><variable fields>\r
  # Each variable field is <2-char field id><value>| -- pipe-terminated,
  # concatenated in sequence, whole message terminated by \r.

  @spec transaction_date() :: String.t()
  def transaction_date do
    # SIP2 fixed 18-char timestamp: YYYYMMDD followed by ZZZZHHMMSS-style
    # time zone + time block (here UTC, "0000" offset marker) -- 18 chars
    # total per the confirmed field layout.
    now = DateTime.utc_now()

    date = now |> DateTime.to_date() |> Date.to_string() |> String.replace("-", "")
    time = now |> DateTime.to_time() |> Time.to_string() |> String.replace(":", "") |> String.slice(0, 6)

    date <> "0000" <> time
  end

  defp variable_field(id, value), do: id <> to_string(value) <> "|"

  @doc "Encodes a real SIP2 93 Login Request message."
  @spec encode_login_request(String.t(), String.t(), keyword()) :: binary()
  def encode_login_request(login_user_id, login_password, opts) do
    uid_algorithm = "0"
    pwd_algorithm = "0"

    "93" <>
      uid_algorithm <>
      pwd_algorithm <>
      variable_field("CN", login_user_id) <>
      variable_field("CO", login_password) <>
      optional_field("CP", Keyword.get(opts, :location_code)) <>
      "\r"
  end

  @doc "Encodes a real SIP2 23 Patron Status Request message."
  @spec encode_patron_status_request(String.t(), keyword()) :: binary()
  def encode_patron_status_request(patron_id, opts) do
    language = "001"
    institution_id = Keyword.fetch!(opts, :institution_id)
    terminal_password = Keyword.get(opts, :terminal_password, "")

    "23" <>
      language <>
      transaction_date() <>
      variable_field("AO", institution_id) <>
      variable_field("AA", patron_id) <>
      variable_field("AC", terminal_password) <>
      "\r"
  end

  @doc "Encodes a real SIP2 17 Item Information Request message."
  @spec encode_item_information_request(String.t(), keyword()) :: binary()
  def encode_item_information_request(item_id, opts) do
    institution_id = Keyword.fetch!(opts, :institution_id)
    terminal_password = Keyword.get(opts, :terminal_password, "")

    "17" <>
      transaction_date() <>
      variable_field("AO", institution_id) <>
      variable_field("AB", item_id) <>
      variable_field("AC", terminal_password) <>
      "\r"
  end

  defp optional_field(_id, nil), do: ""
  defp optional_field(id, value), do: variable_field(id, value)

  # -- decoding: real SIP2 wire format --------------------------------------

  @doc """
  Splits the `|`-terminated variable-field portion of a SIP2 message body
  into a map keyed by the 2-character field id.
  """
  @spec parse_variable_fields(String.t()) :: %{optional(String.t()) => String.t()}
  def parse_variable_fields(body) do
    body
    |> String.split("|")
    |> Enum.reject(&(&1 == ""))
    |> Enum.reduce(%{}, fn field, acc ->
      case String.split_at(field, 2) do
        {id, value} -> Map.put(acc, id, value)
      end
    end)
  end

  @doc "Decodes a real SIP2 24 Patron Status Response message."
  @spec decode_patron_status_response(String.t()) :: {:ok, map()} | {:error, term()}
  def decode_patron_status_response("24" <> rest) do
    <<_patron_status::binary-size(14), _language::binary-size(3), _tx_date::binary-size(18),
      variable::binary>> = rest

    fields = parse_variable_fields(variable)

    case Map.get(fields, "BL") do
      "N" ->
        {:error, :patron_not_found}

      _ ->
        {:ok,
         %{
           patron_id: Map.get(fields, "AA"),
           name: Map.get(fields, "AE"),
           valid: Map.get(fields, "BL") == "Y",
           institution_id: Map.get(fields, "AO"),
           screen_message: Map.get(fields, "AF")
         }}
    end
  end

  def decode_patron_status_response(other), do: {:error, {:unexpected_response, other}}

  @doc "Decodes a real SIP2 18 Item Information Response message."
  @spec decode_item_information_response(String.t()) :: {:ok, map()} | {:error, term()}
  def decode_item_information_response("18" <> rest) do
    <<circulation_status::binary-size(2), _security_marker::binary-size(2),
      _fee_type::binary-size(2), _tx_date::binary-size(18), variable::binary>> = rest

    fields = parse_variable_fields(variable)

    case Map.get(fields, "AB") do
      nil ->
        {:error, :item_not_found}

      item_id ->
        {:ok,
         %{
           item_id: item_id,
           title: Map.get(fields, "AJ"),
           circulation_status: circulation_status,
           location: Map.get(fields, "AP"),
           call_number: Map.get(fields, "CS"),
           screen_message: Map.get(fields, "AF")
         }}
    end
  end

  def decode_item_information_response(other), do: {:error, {:unexpected_response, other}}
end
