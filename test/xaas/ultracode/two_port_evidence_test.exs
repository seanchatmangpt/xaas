defmodule Xaas.Ultracode.TwoPortEvidenceTest do
  @moduledoc """
  Chicago-style qualification of the two-port runtime surface's DURABLE
  evidence:

    * `CapabilityPort.resolve/4` emits `capability_requested` /
      `capability_resolved` / `capability_gap` through `:telemetry` (the same
      mechanism `Lease.record_provider_event/2` uses). A real `:telemetry`
      handler is attached -- a real collaborator, not a mock -- and the
      events are asserted on the metadata actually delivered.
    * `Lease.close/4` and `Lease.reclaim_epoch/4` stamp
      `RuntimeSurface.effective_surface/1` into the persisted Receipt
      evidence, re-read from Postgres, with no lease token anywhere.

  Real Repo sandbox, real tmp git repository, real `git`, real court
  sources injected through the court's own config seam (async: false).
  """

  use ExUnit.Case, async: false

  alias Xaas.Ultracode.{CapabilityPort, Epoch, Lease, Receipt, Run, RuntimeSurface}

  @git_env [
    {"GIT_AUTHOR_NAME", "t"},
    {"GIT_AUTHOR_EMAIL", "t@t"},
    {"GIT_COMMITTER_NAME", "t"},
    {"GIT_COMMITTER_EMAIL", "t@t"}
  ]

  defmodule HoldsSource do
    @behaviour Xaas.Ultracode.CapabilityResolver.Source
    @impl true
    def candidates(_item, _ctx),
      do: {:ok, [%{capability_id: "recipe:mix-format", satisfies: ["recipe:mix-format"]}]}
  end

  defmodule EmptySource do
    @behaviour Xaas.Ultracode.CapabilityResolver.Source
    @impl true
    def candidates(_item, _ctx), do: {:ok, []}
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)

    saved = Application.fetch_env(:xaas, :ultracode_capability_sources)

    on_exit(fn ->
      case saved do
        {:ok, value} -> Application.put_env(:xaas, :ultracode_capability_sources, value)
        :error -> Application.delete_env(:xaas, :ultracode_capability_sources)
      end
    end)

    tmp = Path.join(System.tmp_dir!(), "two-port-evidence-#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)
    on_exit(fn -> File.rm_rf(tmp) end)
    {:ok, gap_path: Path.join(tmp, "gaps.ndjson")}
  end

  defp provider_id, do: "two-port-#{System.unique_integer([:positive])}"

  defp git(dir, args),
    do: System.cmd("git", ["-C", dir | args], stderr_to_stdout: true, env: @git_env)

  defp commit(dir, file, content) do
    File.write!(Path.join(dir, file), content)
    {_, 0} = git(dir, ["add", file])
    {_, 0} = git(dir, ["commit", "--quiet", "-m", file])
    {sha, 0} = git(dir, ["rev-parse", "HEAD"])
    String.trim(sha)
  end

  defp tmp_repo do
    dir = Path.join(System.tmp_dir!(), "xaas-two-port-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    {_, 0} = git(dir, ["init", "--quiet", "-b", "main"])
    {dir, commit(dir, "a.txt", "base\n")}
  end

  defp leased(provider, attrs, worktree) do
    {:ok, run} =
      Run
      |> Ash.Changeset.for_create(
        :create,
        Map.merge(%{goal: "Qualify two-port evidence.", provider: provider}, attrs),
        authorize?: false
      )
      |> Ash.create()

    {:ok, epoch} =
      Epoch
      |> Ash.Changeset.for_create(
        :create,
        %{
          run_id: run.id,
          cycle: 0,
          exact_subject: "two-port evidence qualification",
          state: :running,
          worktree: worktree
        },
        authorize?: false
      )
      |> Ash.create()

    {:ok, leased, token, _run} =
      Lease.claim_next(provider, "worker-e", epoch_id: epoch.id, pool_capacity: nil)

    %{epoch: leased, token: token}
  end

  defp attach_capability_events do
    test_pid = self()
    handler_id = "two-port-evidence-#{System.unique_integer([:positive])}"

    :ok =
      :telemetry.attach_many(
        handler_id,
        CapabilityPort.telemetry_events(),
        fn event, measurements, metadata, _config ->
          send(test_pid, {:capability_event, event, measurements, metadata})
        end,
        nil
      )

    on_exit(fn -> :telemetry.detach(handler_id) end)
  end

  defp persisted_receipt(receipt_id) do
    {:ok, receipt} = Ash.get(Receipt, receipt_id, authorize?: false)
    receipt
  end

  defp assert_surface(surface, epoch_id, token) do
    assert surface["semantic_ports"] == ["sa2a", "sjira"]
    assert surface["direct_external"] == []
    assert surface["policy_digest"] == RuntimeSurface.policy_digest()
    assert surface["lease_id"] == epoch_id
    assert surface["authority"] == "NONE"
    assert is_list(surface["env_keys"])
    refute Map.has_key?(surface, "lease_token")
    refute Jason.encode!(surface) =~ token
  end

  describe "CapabilityPort telemetry evidence" do
    test "a bound capability emits requested + resolved with lease epoch, never the token",
         %{gap_path: gap} do
      Application.put_env(:xaas, :ultracode_capability_sources, %{holds: HoldsSource})
      {repo, x} = tmp_repo()
      %{token: token, epoch: epoch} = leased(provider_id(), %{base_sha: x}, repo)
      {:ok, ctx} = Lease.lease_context(token)
      attach_capability_events()

      assert {:ok, %{"state" => "bound"}} =
               CapabilityPort.resolve(ctx, "recipe:mix-format", %{}, gap_path: gap)

      digest = RuntimeSurface.policy_digest()
      work_id = ctx["work_id"]
      epoch_id = epoch.id

      assert_receive {:capability_event, [:xaas, :ultracode, :capability, :capability_requested],
                      %{count: 1},
                      %{
                        work_id: ^work_id,
                        epoch_id: ^epoch_id,
                        capability: "recipe:mix-format",
                        class: nil,
                        code: nil,
                        policy_digest: ^digest
                      } = requested}

      assert_receive {:capability_event, [:xaas, :ultracode, :capability, :capability_resolved],
                      %{count: 1},
                      %{
                        work_id: ^work_id,
                        epoch_id: ^epoch_id,
                        capability: "recipe:mix-format",
                        class: "reuse",
                        code: nil,
                        policy_digest: ^digest
                      } = resolved}

      refute_receive {:capability_event, [:xaas, :ultracode, :capability, :capability_gap], _, _}

      for meta <- [requested, resolved] do
        refute inspect(meta) =~ token
        refute Map.has_key?(meta, :lease_token)
      end
    end

    test "no satisfier emits capability_gap with class + code and writes one gap record",
         %{gap_path: gap} do
      Application.put_env(:xaas, :ultracode_capability_sources, %{empty: EmptySource})
      {repo, x} = tmp_repo()
      %{token: token, epoch: epoch} = leased(provider_id(), %{base_sha: x}, repo)
      {:ok, ctx} = Lease.lease_context(token)
      attach_capability_events()

      assert {:error, %{"code" => "NO_CAPABILITY"}} =
               CapabilityPort.resolve(ctx, "tool:missing-thing", %{}, gap_path: gap)

      epoch_id = epoch.id

      assert_receive {:capability_event, [:xaas, :ultracode, :capability, :capability_requested],
                      _, %{epoch_id: ^epoch_id}}

      assert_receive {:capability_event, [:xaas, :ultracode, :capability, :capability_gap],
                      %{count: 1},
                      %{
                        epoch_id: ^epoch_id,
                        capability: "tool:missing-thing",
                        class: class,
                        code: "NO_CAPABILITY"
                      } = meta}

      assert is_binary(class) and class != "reuse"
      refute inspect(meta) =~ token

      refute_receive {:capability_event, [:xaas, :ultracode, :capability, :capability_resolved],
                      _, _}

      assert CapabilityPort.gap_stats(gap) == %{"tool:missing-thing" => 1}
    end

    test "a wire subject mismatch is evidenced as capability_gap PROVENANCE_MISMATCH, no gap record",
         %{gap_path: gap} do
      Application.put_env(:xaas, :ultracode_capability_sources, %{holds: HoldsSource})
      {repo, x} = tmp_repo()
      %{token: token, epoch: epoch} = leased(provider_id(), %{base_sha: x}, repo)
      {:ok, ctx} = Lease.lease_context(token)
      attach_capability_events()

      assert {:error, %{"code" => "PROVENANCE_MISMATCH"}} =
               CapabilityPort.resolve(
                 ctx,
                 "recipe:mix-format",
                 %{"subject" => %{"base_sha" => String.duplicate("0", 40)}},
                 gap_path: gap
               )

      epoch_id = epoch.id

      assert_receive {:capability_event, [:xaas, :ultracode, :capability, :capability_gap], _,
                      %{epoch_id: ^epoch_id, class: nil, code: "PROVENANCE_MISMATCH"}}

      assert CapabilityPort.gap_stats(gap) == %{}
    end
  end

  describe "effective_surface stamped into sealed receipts" do
    test "close/4 persists effective_surface (sa2a+sjira, no direct external, no token)" do
      {repo, x} = tmp_repo()
      %{token: token, epoch: epoch} = leased(provider_id(), %{base_sha: x}, repo)
      head = commit(repo, "b.txt", "descendant\n")

      # A worker-supplied surface claim is overwritten by the fabric's stamp.
      spoof = %{"effective_surface" => %{"direct_external" => ["WebFetch"]}}
      assert {:ok, _closed, receipt} = Lease.close(token, head, :partial_alive, spoof)

      persisted = persisted_receipt(receipt.id)
      surface = persisted.evidence["effective_surface"]
      assert_surface(surface, epoch.id, token)
      assert surface["subject"]["base_sha"] == x
      refute Jason.encode!(persisted.evidence) =~ token
    end

    test "reclaim_epoch/4 persists effective_surface in the reclaim receipt, no token" do
      {repo, x} = tmp_repo()
      %{token: token, epoch: epoch} = leased(provider_id(), %{base_sha: x}, repo)

      assert {:reclaimed, _, receipt} =
               Lease.reclaim_epoch(epoch.id, :worker_down, %{}, expected_lease_token: token)

      persisted = persisted_receipt(receipt.id)
      assert_surface(persisted.evidence["effective_surface"], epoch.id, token)
      assert persisted.evidence["effective_surface"]["subject"]["base_sha"] == x
      refute Jason.encode!(persisted.evidence) =~ token
    end
  end
end
