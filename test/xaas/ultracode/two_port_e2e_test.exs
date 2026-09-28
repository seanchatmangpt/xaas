defmodule Xaas.Ultracode.TwoPortE2ETest do
  @moduledoc """
  End-to-end Chicago qualification of the UltraCode two-port runtime
  surface (sJira work in, SA2A capability out), over REAL collaborators:
  the sandboxed `Xaas.Repo` (via `Xaas.Ultracode.SemanticCase`), real
  `SemanticWork.admit/2` semantic admission, the real HTTP execution fabric
  (`claim_next` over `/internal-api/execution/mcp`), a real tmp git
  repository and real `git commit`s, the real capability court fed by a
  real (simple) `Source` module through its own config seam, and the real
  `Xaas.Actuation.run/4` DO kernel for the replay/conflict leg.

  OBSERVED vs REFUSED-BY-DESIGN is part of each step's name/comment:

    * OBSERVED: sJira descriptor admitted; claim payload carries `work` and
      `surface`; local construction (file + real commit) with NO capability
      request; subject court ok on a descendant head; capability handle
      bound with `brce`/`actuate`; registered actuation succeeds, replays,
      and conflicts; close releases the lease; reclaim revokes a handle.
    * REFUSED-BY-DESIGN: with an empty `:ultracode_actuation_registry` the
      consequential handle has no ambient DO (`unregistered_actuation`).

  Deviation (recorded, not hidden): `SemanticWork.materialize/2` provisions
  its Epoch cwd with `git worktree add` inside the fixture repo. This
  session's operator law forbids worktrees, so the test admits the SAME
  descriptor through `SemanticWork.admit/2` and creates the Run/Epoch from
  the admitted fields directly, with the plain tmp fixture repo itself as
  the lease cwd.
  """

  use Xaas.Ultracode.SemanticCase, async: false

  import Plug.Conn
  import Phoenix.ConnTest

  alias Xaas.Ultracode.{CapabilityPort, Epoch, Lease, Run, SemanticWork}
  alias Xaas.Ultracode.RuntimeSurface.Failure

  @endpoint XaasWeb.Endpoint

  @git_env [
    {"GIT_AUTHOR_NAME", "t"},
    {"GIT_AUTHOR_EMAIL", "t@t"},
    {"GIT_COMMITTER_NAME", "t"},
    {"GIT_COMMITTER_EMAIL", "t@t"}
  ]

  defmodule PublishSource do
    @moduledoc false
    @behaviour Xaas.Ultracode.CapabilityResolver.Source
    @impl true
    def candidates(_item, _ctx),
      do: {:ok, [%{capability_id: "sa2a:publish_change", satisfies: ["publish_change"]}]}
  end

  setup %{base: base} do
    keys = [
      :ultracode_capability_sources,
      :ultracode_capability_gap_path,
      :ultracode_actuation_registry
    ]

    saved = Map.new(keys, &{&1, Application.fetch_env(:xaas, &1)})

    on_exit(fn ->
      Enum.each(saved, fn
        {key, {:ok, value}} -> Application.put_env(:xaas, key, value)
        {key, :error} -> Application.delete_env(:xaas, key)
      end)
    end)

    Application.put_env(:xaas, :ultracode_capability_sources, %{"local" => PublishSource})
    Application.put_env(:xaas, :ultracode_capability_gap_path, Path.join(base, "gaps.ndjson"))
    Application.delete_env(:xaas, :ultracode_actuation_registry)
    :ok
  end

  defp claim_over_fabric(provider, epoch_id) do
    result =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
      |> put_req_header("content-type", "application/json")
      |> put_req_header("accept", "application/json")
      |> post(
        "/internal-api/execution/mcp",
        Jason.encode!(%{
          jsonrpc: "2.0",
          id: 1,
          method: "tools/call",
          params: %{
            name: "claim_next",
            arguments: %{provider: provider, provider_worker_id: "worker-e2e", epoch_id: epoch_id}
          }
        })
      )
      |> json_response(200)
      |> Map.fetch!("result")

    refute result["isError"]
    [%{"text" => text}] = result["content"]
    Jason.decode!(text)
  end

  # sJira descriptor -> real semantic admission -> Run/Epoch from the
  # ADMITTED fields (no worktree; the plain fixture repo is the lease cwd).
  defp admitted_work(repo, sha, suffix, provider) do
    descriptor =
      sha
      |> semantic_descriptor(suffix, "autonomic_wave_attempt")
      |> Map.put(:provider, provider)

    assert {:ok, admitted} = SemanticWork.admit(descriptor, binding: :graph)

    {:ok, run} =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{
          goal: admitted.goal,
          provider: admitted.provider,
          verifier_suite: admitted.verifier_suite,
          work_order_iri: admitted.work_order_iri,
          checkpoint_iri: admitted.checkpoint_iri,
          graph_digest: admitted.graph_digest,
          repository_identity: admitted.repository_identity,
          execution_repo_alias: admitted.execution_repo_alias,
          execution_policy: admitted.execution_policy,
          dependency_evidence: %{},
          base_sha: admitted.base_sha
        },
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
          exact_subject: admitted.work_order_iri <> "@" <> admitted.graph_digest,
          state: :running,
          worktree: repo
        },
        authorize?: false
      )
      |> Ash.create()

    {admitted, run, epoch}
  end

  defp commit!(repo, file, content) do
    File.write!(Path.join(repo, file), content)
    {_, 0} = System.cmd("git", ["-C", repo, "add", file], stderr_to_stdout: true, env: @git_env)

    {_, 0} =
      System.cmd("git", ["-C", repo, "commit", "--quiet", "-m", file],
        stderr_to_stdout: true,
        env: @git_env
      )

    git!(repo, ["rev-parse", "HEAD"])
  end

  test "two-port loop: sJira work in, local construction, SA2A capability, BRCE actuate, close",
       %{repo: repo, sha: base_sha} do
    provider = "two-port-#{System.unique_integer([:positive])}"
    suffix = "two-port-#{System.unique_integer([:positive])}"
    {admitted, run, epoch} = admitted_work(repo, base_sha, suffix, provider)

    # OBSERVED: the fabric's claim payload carries the normalized sJira
    # work object and the effective runtime surface.
    claim = claim_over_fabric(provider, epoch.id)
    token = claim["lease_token"]
    assert claim["work"]["id"] == admitted.work_order_iri
    assert claim["work"]["subject"]["base_sha"] == base_sha
    assert claim["work"]["subject"]["repo"] == "seanchatmangpt/xaas"
    assert claim["work"]["objective"] == run.goal
    assert claim["surface"]["semantic_ports"] == ["sa2a", "sjira"]
    assert claim["surface"]["direct_external"] == []
    assert claim["surface"]["authority"] == "NONE"

    # OBSERVED: local construction needs no capability request -- a file
    # written in the lease cwd and a real commit on top of the bound base.
    head = commit!(repo, "construction.txt", "built locally\n")
    assert head != base_sha
    assert :ok = Lease.check_subject(token, head)

    # OBSERVED: the SA2A port binds a consequential capability to the
    # lease subject; it is invocable only via BRCE actuate.
    assert {:ok, ctx} = Lease.lease_context(token)
    assert {:ok, handle} = CapabilityPort.resolve(ctx, "publish_change", %{})
    assert handle["capability_id"] == "sa2a:publish_change"
    assert handle["authority_requirement"] == "brce"
    assert handle["invocation_contract"] == "actuate"
    assert handle["subject"]["base_sha"] == base_sha
    assert :ok = CapabilityPort.check_handle(handle, Lease.lease_context(token))

    key = "two-port-#{System.unique_integer([:positive])}"

    request = %{
      "resource" => "Xaas.Marketplace.Provider",
      "action" => "actuate_status",
      "input" => %{"status" => "active"},
      "idempotency_key" => key,
      "head" => head
    }

    # REFUSED-BY-DESIGN: empty actuation registry => no ambient DO, even
    # with a bound brce handle in hand.
    assert {:error, {:unregistered_actuation, {"Xaas.Marketplace.Provider", "actuate_status"}}} =
             Lease.actuate(token, request)

    # OBSERVED: a registered real Ash resource/action (the same pair
    # test/xaas/actuation_test.exs drives) succeeds, replays on the same
    # key+payload, and conflicts on the same key with a different payload.
    target = Xaas.Generator.create_provider!(%{org_id: "org-two-port"})

    Application.put_env(:xaas, :ultracode_actuation_registry, %{
      provider => %{
        {"Xaas.Marketplace.Provider", "actuate_status"} =>
          {Xaas.Marketplace.Provider, :actuate_status, target.id}
      }
    })

    assert {:ok, first} = Lease.actuate(token, request)
    assert first.status == :succeeded
    refute first.replay?

    assert {:ok, replay} = Lease.actuate(token, request)
    assert replay.status == :replayed
    assert replay.replay?
    assert replay.receipt.id == first.receipt.id

    assert {:error, conflict} =
             Lease.actuate(token, put_in(request, ["input", "status"], "suspended"))

    assert %{"code" => "CONFLICTING_REPLAY"} = Failure.from_term(conflict)

    # OBSERVED: close on the constructed head releases the lease; the
    # handle bound to it is revoked afterwards.
    assert {:ok, closed, _receipt} = Lease.close(token, head, :partial_alive, %{})
    assert closed.state != :running
    assert {:error, _} = Lease.lease_context(token)

    assert {:error, %{"code" => "UNAUTHORIZED", "details" => %{"reason" => "revoked"}}} =
             CapabilityPort.check_handle(handle, Lease.lease_context(token))
  end

  test "reclaim(:worker_down) revokes a bound capability handle (UNAUTHORIZED)", %{
    repo: repo,
    sha: base_sha
  } do
    provider = "two-port-reclaim-#{System.unique_integer([:positive])}"
    suffix = "two-port-reclaim-#{System.unique_integer([:positive])}"
    {_admitted, _run, epoch} = admitted_work(repo, base_sha, suffix, provider)

    claim = claim_over_fabric(provider, epoch.id)
    token = claim["lease_token"]

    assert {:ok, ctx} = Lease.lease_context(token)
    assert {:ok, handle} = CapabilityPort.resolve(ctx, "publish_change", %{})

    assert {:reclaimed, _, _} =
             Lease.reclaim_epoch(epoch.id, :worker_down, %{}, expected_lease_token: token)

    assert {:error, _} = lease_result = Lease.lease_context(token)

    assert {:error, %{"code" => "UNAUTHORIZED", "details" => %{"reason" => "revoked"}}} =
             CapabilityPort.check_handle(handle, lease_result)
  end

  test "drift: a head on an unrelated root is STALE_SUBJECT for the bound base", %{
    repo: repo,
    sha: base_sha
  } do
    provider = "two-port-drift-#{System.unique_integer([:positive])}"
    suffix = "two-port-drift-#{System.unique_integer([:positive])}"
    {_admitted, _run, epoch} = admitted_work(repo, base_sha, suffix, provider)
    token = claim_over_fabric(provider, epoch.id)["lease_token"]

    {_, 0} =
      System.cmd("git", ["-C", repo, "checkout", "--quiet", "--orphan", "unrelated"],
        stderr_to_stdout: true
      )

    {_, 0} = System.cmd("git", ["-C", repo, "rm", "-rf", "--quiet", "."], stderr_to_stdout: true)
    orphan = commit!(repo, "z.txt", "unrelated root\n")

    assert {:error, {:stale_subject, %{"bound" => ^base_sha, "observed" => ^orphan}} = stale} =
             Lease.check_subject(token, orphan)

    assert %{"code" => "STALE_SUBJECT"} = Failure.from_term(stale)
  end
end
