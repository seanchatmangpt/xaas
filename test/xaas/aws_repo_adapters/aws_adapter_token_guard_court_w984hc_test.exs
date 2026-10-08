defmodule Xaas.AwsRepoAdapters.AwsAdapterTokenGuardCourtW984hcTest do
  @moduledoc """
  W984hc — token-path status guard court for `Xaas.AwsRepo.AwsAdapter`.

  Closes the residue W984gu disclosed: `get_aws_token/0` accepted any status
  (Req returns `{:ok, resp}` for any status), so a 500 on the IMDSv2 token PUT
  flowed back as `{:ok, "..."}` error-body. This court drives a real
  Plug/Cowboy listener (Chicago-style: real transport, zero mocks) and asserts
  the typed error on the token path while the 200 happy path stays green.

  Harness copied-per-convention from
  `aws_adapter_local_harness_court_w984fy_test.exs` (shared harness file was
  possibly mid-commit by another lane).
  """

  use ExUnit.Case, async: false

  alias Xaas.AwsRepo.AwsAdapter

  @moduletag :w984hc

  defmodule TokenHarnessRouter do
    use Plug.Router

    plug(Plug.Logger)
    plug(:match)
    plug(:dispatch)

    defp token_scenario,
      do: :persistent_term.get({__MODULE__, :token_scenario}, :ok)

    put "/latest/api/token" do
      case token_scenario() do
        :ok -> send_resp(conn, 200, "LOCAL-TOKEN")
        :token_500 -> send_resp(conn, 500, "boom-token")
      end
    end

    get "/latest/meta-data/instance-id" do
      send_resp(conn, 200, "i-0w984hcLOCAL")
    end

    match _ do
      send_resp(conn, 200, "ok")
    end
  end

  setup do
    {:ok, _} =
      Plug.Cowboy.http(TokenHarnessRouter, [],
        port: 0,
        ref: __MODULE__.TokenHarnessRef
      )

    port = :ranch.get_port(__MODULE__.TokenHarnessRef)
    base = "http://127.0.0.1:#{port}"

    old_base = Application.get_env(:xaas, AwsAdapter)
    Application.put_env(:xaas, AwsAdapter, base_url: base)

    on_exit(fn ->
      Plug.Cowboy.shutdown(__MODULE__.TokenHarnessRef)

      case old_base do
        nil -> Application.delete_env(:xaas, AwsAdapter)
        env -> Application.put_env(:xaas, AwsAdapter, env)
      end
    end)

    {:ok, port: port, base: base}
  end

  describe "get_aws_token guard via get_self_instance_id/0 (real IMDSv2 over HTTP)" do
    test "200 token stays green: round-trip yields the instance id" do
      set_token_scenario(:ok)

      assert {:ok, "i-0w984hcLOCAL"} = AwsAdapter.get_self_instance_id()
    end

    test "real 500 on the token path is a typed error (W984hc guard)" do
      set_token_scenario(:token_500)

      assert {:error,
              "Failed to retrieve self instance id, error: " <>
                "\"Failed to retrieve AWS token, error: unexpected_status_500\""} =
               AwsAdapter.get_self_instance_id()
    end
  end

  defp set_token_scenario(s),
    do: :persistent_term.put({TokenHarnessRouter, :token_scenario}, s)
end
