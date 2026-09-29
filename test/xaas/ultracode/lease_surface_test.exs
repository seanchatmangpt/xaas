defmodule Xaas.Ultracode.LeaseSurfaceTest do
  @moduledoc """
  Chicago-style qualification of the Lease's runtime-surface additions:
  policy-data tool admission (`RuntimeSurface.admit_tool/2`), the bound
  lease context, the effective surface, the claim envelope, and the
  subject-drift court (`check_subject/2`, enforced by `close/4` and
  `actuate/2`) -- real Repo sandbox, real tmp git repositories, real `git`.
  """

  # async: false -- mutates the global :ultracode_provider_tools app env.
  use ExUnit.Case, async: false

  alias Xaas.Ultracode.{Epoch, Lease, Run}

  @git_env [
    {"GIT_AUTHOR_NAME", "t"},
    {"GIT_AUTHOR_EMAIL", "t@t"},
    {"GIT_COMMITTER_NAME", "t"},
    {"GIT_COMMITTER_EMAIL", "t@t"}
  ]

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp provider_id, do: "surface-#{System.unique_integer([:positive])}"

  defp tmp_repo do
    dir = Path.join(System.tmp_dir!(), "xaas-lease-surface-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    {_, 0} = git(dir, ["init", "--quiet", "-b", "main"])
    commit(dir, "a.txt", "base\n")
  end

  defp git(dir, args),
    do: System.cmd("git", ["-C", dir | args], stderr_to_stdout: true, env: @git_env)

  defp commit(dir, file, content) do
    File.write!(Path.join(dir, file), content)
    {_, 0} = git(dir, ["add", file])
    {_, 0} = git(dir, ["commit", "--quiet", "-m", file])
    {sha, 0} = git(dir, ["rev-parse", "HEAD"])
    {dir, String.trim(sha)}
  end

  # An unrelated root commit Y in the same checkout: no ancestry with X.
  defp orphan_commit(dir) do
    {_, 0} = git(dir, ["checkout", "--quiet", "--orphan", "unrelated"])
    {_, 0} = git(dir, ["rm", "-rf", "--quiet", "."])
    {_, sha} = commit(dir, "z.txt", "unrelated root\n")
    sha
  end

  defp leased(provider, attrs \\ %{}, worktree \\ nil) do
    {:ok, run} =
      Run
      |> Ash.Changeset.for_create(
        :create,
        Map.merge(%{goal: "Qualify the lease surface.", provider: provider}, attrs),
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
          exact_subject: "lease surface qualification",
          state: :running,
          worktree: worktree
        },
        authorize?: false
      )
      |> Ash.create()

    {:ok, leased, token, run_ctx} =
      Lease.claim_next(provider, "worker-s", epoch_id: epoch.id, pool_capacity: nil)

    %{run: run_ctx, epoch: leased, token: token}
  end

  describe "admit_tool/2 over the runtime-surface policy" do
    test "WebFetch is a forbidden external semantic edge; Edit allowed; Bash refused" do
      %{token: token} = leased(provider_id())

      assert {:error,
              {:forbidden_external_semantic_edge,
               %{
                 "from" => "ultracode",
                 "to" => "WebFetch",
                 "required" => "UltraCode -> SA2A -> resolve_capability"
               }}} = Lease.admit_tool(token, "WebFetch")

      assert {:ok, %{decision: :allow}} = Lease.admit_tool(token, "Edit")
      assert {:error, {:refused_no_authority, "Bash"}} = Lease.admit_tool(token, "Bash")
    end

    test "a provider override can only narrow: it cannot re-enable WebFetch" do
      provider = provider_id()
      previous = Application.get_env(:xaas, :ultracode_provider_tools)
      Application.put_env(:xaas, :ultracode_provider_tools, %{provider => ~w(Edit WebFetch)})

      on_exit(fn ->
        if previous,
          do: Application.put_env(:xaas, :ultracode_provider_tools, previous),
          else: Application.delete_env(:xaas, :ultracode_provider_tools)
      end)

      %{token: token} = leased(provider)

      assert {:error, {:forbidden_external_semantic_edge, %{"to" => "WebFetch"}}} =
               Lease.admit_tool(token, "WebFetch")

      assert {:ok, %{decision: :allow}} = Lease.admit_tool(token, "Edit")
      # Narrowed out: in policy, not in the override.
      assert {:error, {:unknown_tool_class, "Read"}} = Lease.admit_tool(token, "Read")
    end
  end

  describe "lease_context/1, surface/1, claim_envelope/3" do
    test "lease_context returns the bound subject" do
      {repo, x} = tmp_repo()

      %{token: token, epoch: epoch, run: run} =
        leased(
          provider_id(),
          %{base_sha: x, repository_identity: "demo-repo", work_order_iri: "urn:sj:work:1"},
          repo
        )

      assert {:ok, ctx} = Lease.lease_context(token)
      assert ctx["lease_token"] == token
      assert ctx["epoch_id"] == epoch.id
      assert ctx["run_id"] == run.id
      assert ctx["provider"] == run.provider
      assert ctx["worker_id"] == "worker-s"
      assert ctx["repo"] == "demo-repo"
      assert ctx["base_sha"] == x
      assert ctx["cwd"] == repo
      assert ctx["work_id"] == "urn:sj:work:1"
      assert Map.has_key?(ctx, "branch")
    end

    test "surface/1 is the effective surface: sa2a+sjira, no direct external, authority NONE" do
      {repo, x} = tmp_repo()

      %{token: token} =
        leased(provider_id(), %{base_sha: x, repository_identity: "demo-repo"}, repo)

      assert {:ok, surface} = Lease.surface(token)
      assert surface["schema"] == "xaas-ultracode-runtime-surface/v1"
      assert surface["semantic_ports"] == ["sa2a", "sjira"]
      assert surface["direct_external"] == []
      assert surface["authority"] == "NONE"
      assert surface["policy_digest"] == Xaas.Ultracode.RuntimeSurface.policy_digest()
      assert surface["subject"] == %{"repo" => "demo-repo", "base_sha" => x, "branch" => nil}
      assert "Edit" in surface["agent_tools"]
      refute "WebFetch" in surface["agent_tools"]
      refute "Bash" in surface["agent_tools"]
    end

    test "claim_envelope carries surface and a tracker-neutral work object" do
      {repo, x} = tmp_repo()

      %{token: token, epoch: epoch, run: run} =
        leased(provider_id(), %{base_sha: x, repository_identity: "demo-repo"}, repo)

      assert %{"surface" => surface, "work" => work} = Lease.claim_envelope(epoch, token, run)
      assert surface["subject"]["base_sha"] == x
      assert work["id"] == run.id
      assert work["subject"] == %{"repo" => "demo-repo", "base_sha" => x, "branch" => nil}
      assert work["objective"] == run.goal
      assert work["dependencies"] == %{}
      assert work["provenance"]["run_id"] == run.id

      assert Enum.sort(Map.keys(work)) ==
               ~w(acceptance dependencies id objective provenance subject)
    end

    test "a reclaimed lease has no context (so a bound capability handle is revoked)" do
      provider = provider_id()
      %{token: token, epoch: epoch} = leased(provider)

      assert {:ok, _} = Lease.lease_context(token)

      assert {:reclaimed, _, _} =
               Lease.reclaim_epoch(epoch.id, :worker_down, %{}, expected_lease_token: token)

      assert {:error, {:lease_not_live, :failed}} = Lease.lease_context(token)
      assert {:error, _} = Lease.surface(token)
    end
  end

  describe "subject drift court" do
    test "FALSIFIER: head on an unrelated root commit Y is stale for base X (check_subject and close)" do
      {repo, x} = tmp_repo()
      %{token: token} = leased(provider_id(), %{base_sha: x}, repo)
      y = orphan_commit(repo)

      assert {:error, {:stale_subject, %{"bound" => ^x, "observed" => ^y}}} =
               Lease.check_subject(token, y)

      assert {:error, {:stale_subject, %{"bound" => ^x, "observed" => ^y}}} =
               Lease.close(token, y, :partial_alive, %{})

      # Refused closure seals nothing: the lease is still live.
      assert {:ok, _} = Lease.lease_context(token)
    end

    test "a head descending from X is not stale; close proceeds" do
      {repo, x} = tmp_repo()
      %{token: token} = leased(provider_id(), %{base_sha: x}, repo)
      {_, head} = commit(repo, "b.txt", "descendant\n")

      assert :ok = Lease.check_subject(token, head)
      assert :ok = Lease.check_subject(token, x)
      assert {:ok, closed, receipt} = Lease.close(token, head, :partial_alive, %{})
      assert closed.final_head == head
      assert receipt.evidence["head_verified"] == true
    end

    test "actuate/2 refuses stale_subject before the registry is consulted" do
      {repo, x} = tmp_repo()
      %{token: token} = leased(provider_id(), %{base_sha: x}, repo)
      y = orphan_commit(repo)

      # The lease cwd HEAD is now Y (orphan branch checked out).
      assert {:error, {:stale_subject, %{"bound" => ^x, "observed" => ^y}}} =
               Lease.actuate(token, %{"resource" => "R", "action" => "a"})

      # Court F5 falsifier: a wire "head" naming the bound base cannot
      # override the checkout's real HEAD -- the drift court still refuses.
      assert {:error, {:stale_subject, %{"bound" => ^x, "observed" => ^x, "checkout_head" => ^y}}} =
               Lease.actuate(token, %{"resource" => "R", "action" => "a", "head" => x})

      # A wire head that AGREES with a descending checkout reaches the
      # (empty, fail-closed) registry.
      {_, 0} = git(repo, ["checkout", "--quiet", "--detach", x])

      assert {:error, {:unregistered_actuation, {"R", "a"}}} =
               Lease.actuate(token, %{"resource" => "R", "action" => "a", "head" => x})
    end

    test "no bound base_sha: check_subject is :ok" do
      %{token: token} = leased(provider_id())
      assert :ok = Lease.check_subject(token, "0000000000000000000000000000000000000000")
    end
  end
end
