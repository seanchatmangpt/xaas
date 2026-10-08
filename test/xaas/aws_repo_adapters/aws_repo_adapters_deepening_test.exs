defmodule Xaas.AwsRepoAdaptersDeepeningTest do
  @moduledoc """
  Chicago courts for the `Xaas.AwsRepo` adapter residue (W984du census:
  Xaas.AwsRepo.FixtureAdapter 2 pubs, Xaas.AwsRepo.AwsAdapter 2 pubs).

  The FixtureAdapter is fully deterministic and asserted on real state.
  AwsAdapter's two pubs make live network calls (EC2 IMDS at 169.254.169.254
  and CloudWatch via ExAws) with no injection seam, so their failure paths are
  exercised for real where they are reachable without live AWS: not here.
  Tests below cover every deterministic branch; the live-AWS branches remain
  disclosed-uncovered with the reason stated (no real collaborator reachable).
  """

  use ExUnit.Case, async: true

  alias Xaas.AwsRepo
  alias Xaas.AwsRepo.FixtureAdapter

  describe "Xaas.AwsRepo.FixtureAdapter.get_cpu_average/1" do
    test "returns {:ok, cpu} with cpu a float in the 1..99 range plus fixture jitter" do
      assert {:ok, cpu} = FixtureAdapter.get_cpu_average("i-fixture")
      assert is_float(cpu)

      integer_part = trunc(cpu)
      assert integer_part in 1..99
      assert cpu - integer_part >= 0.123456 - 1.0e-9
      assert cpu - integer_part < 1.0
    end

    test "is instance-id agnostic: two different ids both succeed" do
      assert {:ok, cpu1} = FixtureAdapter.get_cpu_average("i-aaa")
      assert {:ok, cpu2} = FixtureAdapter.get_cpu_average("i-bbb")
      assert is_float(cpu1) and is_float(cpu2)
    end

    test "facade dispatch through Xaas.AwsRepo hits the configured adapter" do
      assert {:ok, cpu} = AwsRepo.get_cpu_average("i-fixture")
      assert is_float(cpu)
    end
  end

  describe "Xaas.AwsRepo.FixtureAdapter.get_self_instance_id/0" do
    test "returns the fixed demo instance id" do
      assert {:ok, "i-09ba9852c02d92e38"} = FixtureAdapter.get_self_instance_id()
    end

    test "facade dispatch returns the same fixed id" do
      assert {:ok, "i-09ba9852c02d92e38"} = AwsRepo.get_self_instance_id()
    end
  end

  describe "adapter configuration" do
    test "ILSRepo default adapter is the FixtureAdapter" do
      config = Application.get_env(:xaas, Xaas.Library.ILSRepo)
      assert Keyword.get(config, :adapter) == Xaas.Library.ILSRepo.FixtureAdapter
    end

    test "AwsRepo configured adapter is a real module implementing the behaviour" do
      config = Application.fetch_env!(:xaas, Xaas.AwsRepo)
      adapter = Keyword.fetch!(config, :adapter)
      assert is_atom(adapter)
      assert function_exported?(adapter, :get_cpu_average, 1)
      assert function_exported?(adapter, :get_self_instance_id, 0)
    end
  end
end
