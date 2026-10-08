defmodule Xaas.CensusTailCourtW984mmTest do
  @moduledoc """
  W984mm court for the W984lq eighth re-census tail
  (docs/sjira/v26.10.6/plans/w984lq-recensus.md, rows 6-10):

  - Xaas.PromEx.CpuPlugin (state-bearing plugin: happy + error branches of
    execute_cpu_metrics/0, polling_metrics/1 default and custom poll_rate)
  - Xaas.Runtime.ProviderFabric.Budget (pure state machine — real consume
    transitions)
  - Xaas.Trimtab.ZcodeAdapter (pure encode — all real branches)
  - UNKNOWN_postgrex_types / Xaas.PostgrexTypes (compile-time
    Postgrex.Types.define projection — load + extension-surface court)
  - Xaas.Governance.Types.ChangeOfControlEventType (pure types module —
    cast behavior through the real Ash.Type.Enum derivation)

  Chicago discipline: every collaborator is real. The CpuPlugin happy path
  runs through the disclosed real `Xaas.AwsRepo.FixtureAdapter`; the error
  path runs through a hand-written real adapter implementing the real
  `Xaas.AwsRepo` behaviour (a hand-written real interface implementation is
  not a mock). No mocks, no patches.
  """

  use ExUnit.Case, async: false

  alias Xaas.AwsRepo.FixtureAdapter
  alias Xaas.Governance.Types.ChangeOfControlEventType
  alias Xaas.PromEx.CpuPlugin
  alias Xaas.Runtime.ProviderFabric.Budget
  alias Xaas.Trimtab.ZcodeAdapter

  @cpu_event [:prom_ex, :plugin, :os, :cpu]

  # ------------------------------------------------------------------
  # Xaas.PromEx.CpuPlugin
  # ------------------------------------------------------------------

  describe "Xaas.PromEx.CpuPlugin.execute_cpu_metrics/0" do
    test "happy path emits telemetry with fixture instance id and nonzero util" do
      handler_id = "w984mm-cpu-happy"
      :telemetry.attach(handler_id, @cpu_event, &__MODULE__.happy_handler/4, nil)
      old = Application.get_env(:xaas, Xaas.AwsRepo)

      Application.put_env(:xaas, Xaas.AwsRepo, adapter: FixtureAdapter)
      CpuPlugin.execute_cpu_metrics()
      Application.put_env(:xaas, Xaas.AwsRepo, old)

      assert_receive {:w984mm_cpu_happy, instance_id, util}, 1_000
      assert instance_id == "i-09ba9852c02d92e38"
      assert is_float(util) and util > 0.0

      on_exit(fn -> :telemetry.detach(handler_id) end)
    end

    test "error path emits util 0.0 with empty metadata (typed util-0 event)" do
      handler_id = "w984mm-cpu-error"
      :telemetry.attach(handler_id, @cpu_event, &__MODULE__.error_handler/4, nil)
      old = Application.get_env(:xaas, Xaas.AwsRepo)

      Application.put_env(:xaas, Xaas.AwsRepo, adapter: W984mm.FailingAdapter)
      CpuPlugin.execute_cpu_metrics()
      Application.put_env(:xaas, Xaas.AwsRepo, old)

      assert_receive {:w984mm_cpu_error_util, util}, 1_000
      assert util == 0.0
      assert_receive {:w984mm_cpu_error_meta, meta}, 1_000
      assert meta == %{}

      on_exit(fn -> :telemetry.detach(handler_id) end)
    end
  end

  def happy_handler(_event, %{util: util}, %{instance_id: instance_id}, nil) do
    send(self(), {:w984mm_cpu_happy, instance_id, util})
  end

  def error_handler(_event, %{util: util}, meta, nil) do
    send(self(), {:w984mm_cpu_error_util, util})
    send(self(), {:w984mm_cpu_error_meta, meta})
  end

  describe "Xaas.PromEx.CpuPlugin.polling_metrics/1" do
    test "default poll rate is 1_000" do
      assert [%PromEx.MetricTypes.Polling{} = polling] = CpuPlugin.polling_metrics([])
      assert polling.poll_rate == 1_000
      assert polling.group_name == :os_cpu_polling_events
      assert elem(polling.measurements_mfa, 0) == CpuPlugin
      assert elem(polling.measurements_mfa, 1) == :execute_cpu_metrics
    end

    test "explicit poll_rate is honored" do
      assert [%PromEx.MetricTypes.Polling{} = polling] = CpuPlugin.polling_metrics(poll_rate: 5_000)
      assert polling.poll_rate == 5_000
    end
  end

  # ------------------------------------------------------------------
  # Xaas.Runtime.ProviderFabric.Budget
  # ------------------------------------------------------------------

  describe "Xaas.Runtime.ProviderFabric.Budget.consume/1" do
    test "consume decrements attempts (real state transition)" do
      budget = %Budget{attempts: 3}
      assert {:ok, %Budget{attempts: 2}} = Budget.consume(budget)
    end

    test "exhausted budget (attempts: 0) refuses with :exhausted" do
      assert {:error, :exhausted} = Budget.consume(%Budget{attempts: 0})
    end

    test "last attempt succeeds and lands at exactly zero" do
      assert {:ok, %Budget{attempts: 0}} = Budget.consume(%Budget{attempts: 1})
      # the zeroed struct is now exhausted on the next draw
      assert {:error, :exhausted} = Budget.consume(%Budget{attempts: 0})
    end

    test "non-Budget input refuses with :exhausted (guard fallthrough)" do
      assert {:error, :exhausted} = Budget.consume(%{attempts: 100})
    end
  end

  # ------------------------------------------------------------------
  # Xaas.Trimtab.ZcodeAdapter
  # ------------------------------------------------------------------

  describe "Xaas.Trimtab.ZcodeAdapter.encode/1" do
    test "full request encodes with protocol, subject, objective, action, payload" do
      request = %{subject: "checkout-1", objective: "ship", action: "approve", payload: %{"k" => 1}}

      assert {:ok,
              %{
                protocol: "zcode.trimtab.v1",
                subject: "checkout-1",
                objective: "ship",
                action: "approve",
                payload: %{"k" => 1}
              }} = ZcodeAdapter.encode(request)
    end

    test "missing action/payload keys default to nil without failing" do
      assert {:ok, encoded} = ZcodeAdapter.encode(%{subject: "s", objective: "o"})
      assert encoded.action == nil
      assert encoded.payload == nil
      assert encoded.protocol == "zcode.trimtab.v1"
    end

    test "invalid request shape refuses with :invalid_request" do
      assert {:error, :invalid_request} = ZcodeAdapter.encode(%{subject: "only-subject"})
      assert {:error, :invalid_request} = ZcodeAdapter.encode("not a map")
    end
  end

  # ------------------------------------------------------------------
  # Xaas.PostgrexTypes (census UNKNOWN_postgrex_types)
  # ------------------------------------------------------------------

  describe "Xaas.PostgrexTypes (UNKNOWN_postgrex_types entry)" do
    test "compile-time Postgrex.Types.define projection is loaded with real extension surface" do
      assert Xaas.PostgrexTypes = Code.ensure_loaded!(Xaas.PostgrexTypes)
      # AshPostgres vector extension is projected into the types module.
      assert Code.ensure_loaded?(AshPostgres.Extensions.Vector)
      # The module is a real Postgrex types module: it defines the
      # Postgrex types dispatch surface (encode/decode entry points).
      assert function_exported?(Xaas.PostgrexTypes, :encode_params, 2)
      assert function_exported?(Xaas.PostgrexTypes, :decode_rows, 3)
      assert function_exported?(Xaas.PostgrexTypes, :find, 2)
    end
  end

  # ------------------------------------------------------------------
  # Xaas.Governance.Types.ChangeOfControlEventType
  # ------------------------------------------------------------------

  describe "Xaas.Governance.Types.ChangeOfControlEventType" do
    test "declares the three platform-console-ported values" do
      values = ChangeOfControlEventType.values()
      assert :acquisition in values
      assert :merger in values
      assert :ownership_change in values
      assert length(values) == 3
    end

    test "cast_input accepts atoms, strings, and nil" do
      assert {:ok, :acquisition} = ChangeOfControlEventType.cast_input(:acquisition, [])
      assert {:ok, :merger} = ChangeOfControlEventType.cast_input("merger", [])
      assert {:ok, :ownership_change} = ChangeOfControlEventType.cast_input("ownership_change", [])
      assert {:ok, nil} = ChangeOfControlEventType.cast_input(nil, [])
    end

    test "cast_input refuses values outside the enum" do
      assert :error = ChangeOfControlEventType.cast_input("hostile_takeover", [])
      assert :error = ChangeOfControlEventType.cast_input(42, [])
    end

    test "storage_type is a text column" do
      assert :string = ChangeOfControlEventType.storage_type()
    end
  end
end

defmodule W984mm.FailingAdapter do
  @moduledoc """
  Hand-written real adapter implementing the real `Xaas.AwsRepo` behaviour,
  returning the metadata-service failure so the CpuPlugin error branch runs
  for real. A hand-written real interface implementation is not a mock
  (testing-chicago-style rule).
  """

  @behaviour Xaas.AwsRepo

  @impl true
  def get_cpu_average(_instance_id), do: {:ok, 12.5}

  @impl true
  def get_self_instance_id, do: {:error, "no metadata service"}
end
