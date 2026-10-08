defmodule Xaas.AwsRepoAdapters.AwsAdapterLocalHarnessCourtW984fyTest do
  @moduledoc """
  W984fy — local protocol harness court for `Xaas.AwsRepo.AwsAdapter`.

  Chicago-style: a real Plug/Cowboy HTTP listener (real collaborator, zero
  mocks) speaks the two protocol surfaces the adapter actually uses:

    1. CloudWatch GetMetricStatistics (ExAws query protocol, port from
       `:ex_aws` `:monitoring` service config — a real config-driven seam,
       no code faked).
    2. EC2 IMDSv2 token + instance-id (URL seam made lawful this session:
       runtime.exs already configured `base_url` but the adapter read a
       compile-time `@base_url`, so the config was dead. The adapter now
       reads `base_url` from app env at call time, IMDS default preserved).

  Covered branches: parsed success, empty datapoints, non-200, malformed
  XML, connection refused (both pubs).
  """

  use ExUnit.Case, async: false

  alias Xaas.AwsRepo.AwsAdapter

  @moduletag :w984fy

  defmodule HarnessRouter do
    use Plug.Router

    plug(Plug.Logger)
    plug(:match)
    plug(:dispatch)

    # Scenario is stored in :persistent_term by each test.
    defp scenario,
      do: :persistent_term.get({__MODULE__, :scenario}, :ok_metrics)

    get "/latest/meta-data/instance-id" do
      case scenario() do
        :ok ->
          send_resp(conn, 500, "boom")

        :connection_refused_token_then_ok ->
          # token succeeded, instance-id read fails
          send_resp(conn, 500, "boom")

        _ ->
          send_resp(conn, 200, "i-0w984fyLOCAL")
      end
    end

    put "/latest/api/token" do
      send_resp(conn, 200, "LOCAL-TOKEN")
    end

    match _ do
      serve_cloudwatch(conn)
    end

    defp serve_cloudwatch(conn) do
      case scenario() do
        :ok_metrics ->
          send_resp(conn, 200, """
          <GetMetricStatisticsResponse>
            <GetMetricStatisticsResult>
              <Datapoints>
                <member>
                  <Average>10.0</Average>
                </member>
                <member>
                  <Average>20.0</Average>
                </member>
              </Datapoints>
            </GetMetricStatisticsResult>
          </GetMetricStatisticsResponse>
          """)

        :empty_metrics ->
          send_resp(conn, 200, """
          <GetMetricStatisticsResponse>
            <GetMetricStatisticsResult>
              <Datapoints></Datapoints>
            </GetMetricStatisticsResult>
          </GetMetricStatisticsResponse>
          """)

        :bad_status ->
          send_resp(conn, 400, """
          <ErrorResponse>
            <Error>
              <Type>Sender</Type>
              <Code>InvalidParameterCombination</Code>
              <Message>no such instance</Message>
            </Error>
          </ErrorResponse>
          """)

        :malformed ->
          send_resp(conn, 200, "<not-xml")

        :imds_ok ->
          send_resp(conn, 200, "i-0w984fyLOCAL")
      end
    end
  end

  setup do
    # Real HTTP listener on an ephemeral port.
    {:ok, _} =
      Plug.Cowboy.http(HarnessRouter, [],
        port: 0,
        ref: __MODULE__.HarnessRef
      )

    port = :ranch.get_port(__MODULE__.HarnessRef)
    base = "http://127.0.0.1:#{port}"

    # Lawful seams: ExAws monitoring service pointed at the local listener,
    # adapter base_url pointed at the local listener. Both are real app
    # config, read at call time.
    old_exaws = Application.get_env(:ex_aws, :monitoring)
    old_global = Application.get_env(:ex_aws, :region)

    Application.put_env(:ex_aws, :monitoring,
      scheme: "http",
      host: "127.0.0.1",
      port: port,
      region: "us-east-1"
    )

    Application.put_env(:ex_aws, :region, "us-east-1")
    Application.put_env(:ex_aws, :access_key_id, "LOCAL-HARNESS-KEY")
    Application.put_env(:ex_aws, :secret_access_key, "LOCAL-HARNESS-SECRET")

    old_base = Application.get_env(:xaas, AwsAdapter)
    Application.put_env(:xaas, AwsAdapter, base_url: base)

    on_exit(fn ->
      Plug.Cowboy.shutdown(__MODULE__.HarnessRef)
      restore_env(:ex_aws, :monitoring, old_exaws)
      restore_env(:ex_aws, :region, old_global)

      Application.put_env(:ex_aws, :access_key_id, nil)
      Application.delete_env(:ex_aws, :access_key_id)
      Application.delete_env(:ex_aws, :secret_access_key)

      case old_base do
        nil -> Application.delete_env(:xaas, AwsAdapter)
        env -> Application.put_env(:xaas, AwsAdapter, env)
      end
    end)

    {:ok, port: port, base: base}
  end

  defp restore_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_env(app, key, val), do: Application.put_env(app, key, val)

  describe "get_cpu_average/1 (ExAws CloudWatch query, real HTTP)" do
    test "parses two real datapoints to their average" do
      set_scenario(:ok_metrics)

      assert {:ok, 15.0} = AwsAdapter.get_cpu_average("i-0harness")
    end

    test "returns 0 for a real 200 with empty Datapoints" do
      set_scenario(:empty_metrics)

      assert {:ok, 0} = AwsAdapter.get_cpu_average("i-0harness")
    end

    test "non-200 is a typed error tuple" do
      set_scenario(:bad_status)

      assert {:error, _} = AwsAdapter.get_cpu_average("i-0harness")
    end

    test "malformed XML body raises a real parse error (not swallowed)" do
      set_scenario(:malformed)

      caught =
        try do
          {:no_exit, AwsAdapter.get_cpu_average("i-0harness")}
        rescue
          e -> {:rescue, e}
        catch
          kind, reason -> {kind, reason}
        end

      assert {:exit, {:fatal, {:unexpected_end, _, _, _}}} = caught
    end
  end

  describe "get_self_instance_id/0 (real IMDSv2 token + read over HTTP)" do
    test "token then instance-id round-trip against a real listener" do
      set_scenario(:imds_ok)

      assert {:ok, "i-0w984fyLOCAL"} = AwsAdapter.get_self_instance_id()
    end

    test "connection refused yields the wrapped error string" do
      # Free port, no listener: real refused TCP connect.
      {:ok, socket} =
        :gen_tcp.listen(0, [
          :binary,
          active: false
        ])

      {:ok, port} = :inet.port(socket)
      :gen_tcp.close(socket)

      Application.put_env(:xaas, AwsAdapter, base_url: "http://127.0.0.1:#{port}")

      assert {:error,
              "Failed to retrieve self instance id, error: \"Failed to retrieve AWS token, error: %Req.TransportError{reason: :econnrefused}\""} =
               AwsAdapter.get_self_instance_id()
    end

    test "token ok but instance-id read 500 is a typed error (W984gu status guard)" do
      # W984gu repair of the W984fy quirk: Req still returns
      # {:ok, %Req.Response{}} for any status, but the adapter now guards the
      # instance-id read on 2xx — a real 500 surfaces as the adapter's typed
      # {:error, _} shape, matching the connection-refused channel.
      set_scenario(:ok)

      assert {:error,
              "Failed to retrieve self instance id, error: unexpected_status_500"} =
               AwsAdapter.get_self_instance_id()
    end
  end

  defp set_scenario(s), do: :persistent_term.put({HarnessRouter, :scenario}, s)
end
