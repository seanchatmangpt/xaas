defmodule Xaas.Ultracode.DodTrustWiringTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Chicago-style qualification of the DoD-trust WIRING through the real
  fabric: real Run/Epoch/Receipt rows (sandboxed Postgres), real Ash actions,
  real `Lease.close/4`, the real `Sensing` -> `Autonomic.create_run_and_epoch/5`
  -> `{ticket}` -> `Verifier.run/2` chain, real git worktrees and real `/bin/sh`
  suites. Assertions are on sealed receipts and on the rows the database holds.

  Properties:

    * a quarantined suite cannot be named by a new Run (`suite_unhealthy`) and
      is admitted again the moment the court records a healthy result;
    * a vacuous DoD can never seal `:alive`, and the controller treats the
      typed refusal as unrepairable instead of re-dispatching the worker;
    * probes a Semantic Jira order declares travel order -> sensing -> ticket ->
      verifier without any human or worker step.
  """

  alias Xaas.Test.DodFixture, as: Fx
  alias Xaas.Ultracode.{Autonomic, Epoch, Lease, Receipt, Run, Sensing, SuiteHealth, Verifier}

  @provider "zcode-dodtrust-test"
  @env %{"PATH" => "/usr/bin:/bin"}
  @strong ~s|test "$(cat answer.txt)" = 42|
  @probe %{
    id: "wrong-answer",
    kind: "replace",
    file: "answer.txt",
    pattern: "42",
    replacement: "41"
  }

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    keys = [
      :ultracode_verifier_suites,
      :ultracode_worktree_root,
      :ultracode_suite_health_dir,
      :ultracode_ticket_dir,
      :ultracode_target_suites
    ]

    original = for key <- keys, into: %{}, do: {key, Application.get_env(:xaas, key)}

    on_exit(fn ->
      for {key, value} <- original do
        if is_nil(value),
          do: Application.delete_env(:xaas, key),
          else: Application.put_env(:xaas, key, value)
      end
    end)

    root = Fx.tmp("root")
    store = Fx.tmp("store")
    tickets = Fx.tmp("tickets")
    parent = Fx.tmp("origin")

    Application.put_env(:xaas, :ultracode_worktree_root, root)
    Application.put_env(:xaas, :ultracode_suite_health_dir, store)
    Application.put_env(:xaas, :ultracode_ticket_dir, tickets)
    Application.delete_env(:xaas, :ultracode_target_suites)

    {repo, green} = Fx.repo(parent, %{"answer.txt" => "42\n"})
    Fx.tag(repo, "dod-green", green)
    Fx.git!(repo, ["checkout", "--quiet", "-b", "red-side"])
    red = Fx.commit(repo, %{"answer.txt" => "41\n"}, "break the answer")
    Fx.tag(repo, "dod-red", red)
    Fx.git!(repo, ["checkout", "--quiet", "main"])

    %{root: root, tickets: tickets, repo: repo, green: green}
  end

  defp health(repo),
    do: %{repo: repo, green_ref: "dod-green", red_ref: "dod-red", max_age_seconds: 1_000}

  defp suite(script, extra \\ %{}) do
    Map.merge(
      %{env: @env, steps: [%{id: "dod", argv: ["/bin/sh", "-c", script], timeout_ms: 20_000}]},
      extra
    )
  end

  defp register(suites), do: Application.put_env(:xaas, :ultracode_verifier_suites, suites)

  defp create_run(action, suite_name) do
    Run
    |> Ash.Changeset.for_create(
      action,
      %{goal: "DoD trust qualification.", provider: @provider, verifier_suite: suite_name},
      authorize?: false
    )
    |> Ash.create()
  end

  defp leased(root, repo, suite_name) do
    worktree = Fx.linked_worktree(repo, root, Fx.head(repo))
    {:ok, run} = create_run(:create, suite_name)

    {:ok, _epoch} =
      Epoch
      |> Ash.Changeset.for_create(
        :create,
        %{
          run_id: run.id,
          cycle: 0,
          exact_subject: "dod trust",
          state: :running,
          worktree: worktree
        },
        authorize?: false
      )
      |> Ash.create()

    {:ok, epoch, token, _run} = Lease.claim_next(@provider, "worker-dodtrust")
    {epoch, token, Fx.head(worktree)}
  end

  describe "Run admission (VerifierSuiteRegistered)" do
    test "a quarantined suite cannot be named by a Run; the healthy court result releases it, no human step",
         %{repo: repo} do
      register(%{
        "vacuous" => suite("exit 0", %{health: health(repo)}),
        "strong" => suite(@strong, %{health: health(repo)}),
        "plain" => suite(@strong)
      })

      # never checked -> quarantined, on BOTH create actions
      for action <- [:create, :submit] do
        assert {:error, error} = create_run(action, "strong")
        assert Exception.message(error) =~ "suite_unhealthy:never_checked"
      end

      # vacuous: the court measures it and keeps it quarantined
      assert {:ok, %{"verdict" => "vacuous"}} = SuiteHealth.check("vacuous")
      assert {:error, error} = create_run(:create, "vacuous")
      assert Exception.message(error) =~ "suite_unhealthy:unhealthy_vacuous"

      # unmanaged suites and unknown names keep their old behaviour
      assert {:ok, %Run{verifier_suite: "plain"}} = create_run(:create, "plain")
      assert {:error, unknown} = create_run(:create, "nope")
      assert Exception.message(unknown) =~ "unknown_verifier_suite"

      # the strong suite is re-checked by the sweep and admits again
      assert [%{action: :checked, verdict: "healthy"}] = SuiteHealth.sweep(suites: ["strong"])
      assert {:ok, %Run{verifier_suite: "strong"}} = create_run(:create, "strong")
      assert {:ok, %Run{verifier_suite: "strong"}} = create_run(:submit, "strong")
    end
  end

  describe "Lease.close/4 with falsifier probes" do
    test "a vacuous DoD can never seal :alive; the controller treats the refusal as unrepairable",
         %{root: root, repo: repo} do
      register(%{"vacuous-dod" => suite("exit 0", %{probes: [@probe]})})
      {epoch, token, head} = leased(root, repo, "vacuous-dod")

      assert {:ok, _epoch, receipt} = Lease.close(token, head, :alive)

      assert receipt.outcome == :partial_alive
      assert receipt.evidence["head_verified"] == true

      assert %{
               "status" => "error",
               "refusal" => "vacuous_dod",
               "probes" => [%{"verdict" => "survived"}]
             } =
               receipt.evidence["fabric_verifier"]

      # the sealed receipt the database holds says the same
      sealed = Ash.read!(Receipt, authorize?: false) |> Enum.find(&(&1.epoch_id == epoch.id))
      assert sealed.outcome == :partial_alive

      assert {:repair, text} = Autonomic.judge_receipt(sealed)
      assert text =~ "vacuous_dod"

      assert {:refused, "vacuous_dod", reason} = Autonomic.settle(epoch, %{})
      assert reason =~ "court verdict error"
    end

    test "the same probes leave a strong DoD :alive, and the controller accepts it", %{
      root: root,
      repo: repo
    } do
      register(%{"strong-dod" => suite(@strong, %{probes: [@probe]})})
      {epoch, token, head} = leased(root, repo, "strong-dod")

      assert {:ok, _epoch, receipt} = Lease.close(token, head, :alive)

      assert receipt.outcome == :alive

      assert %{"status" => "pass", "probe_summary" => %{"killed" => 1, "survived" => 0}} =
               receipt.evidence["fabric_verifier"]

      assert {:done, %Receipt{outcome: :alive}, _epoch} = Autonomic.settle(epoch, %{})
    end
  end

  describe "order -> sensing -> ticket -> verifier" do
    test "probes an order declares reach the verifier through the controller-written ticket", %{
      root: root,
      tickets: tickets
    } do
      order = """
      ---
      {"identity": "SJ-901", "acceptance": ["answer is 42"], "falsifiers": ["wrong answer accepted"]}
      ---

      # SJ-901: keep the answer honest

      ## Status
      OPEN

      ```xaas-probes
      [{"id": "wrong-answer", "kind": "replace", "file": "answer.txt",
        "pattern": "42", "replacement": "41", "falsifier": 0}]
      ```
      """

      {repo, head} =
        Fx.repo(Fx.tmp("order-repo"), %{"answer.txt" => "42\n", "docs/jira/sj-901.md" => order})

      # sensing: the order's probes ride on the item
      {:ok, doc} = Sensing.derive(%{"type" => "jira_dir"}, repo)

      assert [
               %{"probes" => [%{"id" => "wrong-answer", "falsifier" => "wrong answer accepted"}]} =
                 item
             ] = doc["items"]

      # control: a suite that IS able to fail is fine with the order's probe ...
      register(%{"strong-plain" => suite(@strong), "vacuous-plain" => suite("exit 0")})
      wt = Fx.linked_worktree(repo, root, head)

      for {suite_name, expected} <- [{"strong-plain", "pass"}, {"vacuous-plain", "error"}] do
        ctx = %{
          ticket_dir: tickets,
          repos: %{"tr" => %{suite: suite_name, base_sha: head}},
          repo: "tr",
          provider: @provider
        }

        # the controller step: Run + Epoch + ticket
        {run, epoch} = Autonomic.create_run_and_epoch(item, wt, 1, [], ctx)

        ticket = tickets |> Path.join("#{run.id}.json") |> File.read!() |> Jason.decode!()
        assert [%{"id" => "wrong-answer"}] = ticket["probes"]
        refute Map.has_key?(ticket, "probes_error")

        # the fabric step: the verifier reads the ticket back
        assert {:ok, result} =
                 Verifier.run(suite_name, %{
                   worktree: wt,
                   head: head,
                   run_id: run.id,
                   epoch_id: epoch.id
                 })

        assert result["status"] == expected, inspect(result)

        if expected == "error" do
          assert result["refusal"] == "vacuous_dod"
          assert result["reason"] =~ "wrong-answer"
        end
      end
    end

    test "an item whose order carried invalid probes is refused by the verifier, never ignored",
         %{root: root, tickets: tickets} do
      order = """
      ---
      {"identity": "SJ-902", "acceptance": ["a"], "falsifiers": ["f"]}
      ---

      # SJ-902: bad probes

      ## Status
      OPEN

      ```xaas-probes
      [{"kind": "truncate", "file": "answer.txt", "falsifier": "an invented falsifier"}]
      ```
      """

      {repo, head} =
        Fx.repo(Fx.tmp("order-repo"), %{"answer.txt" => "42\n", "docs/jira/sj-902.md" => order})

      {:ok, %{"items" => [item]}} = Sensing.derive(%{"type" => "jira_dir"}, repo)
      assert item["probes_error"] =~ "invented falsifier"

      register(%{"strong-plain" => suite(@strong)})
      wt = Fx.linked_worktree(repo, root, head)

      ctx = %{
        ticket_dir: tickets,
        repos: %{"tr" => %{suite: "strong-plain", base_sha: head}},
        repo: "tr",
        provider: @provider
      }

      {run, epoch} = Autonomic.create_run_and_epoch(item, wt, 1, [], ctx)

      assert {:ok, %{"status" => "error", "refusal" => "probes_refused", "reason" => reason}} =
               Verifier.run("strong-plain", %{
                 worktree: wt,
                 head: head,
                 run_id: run.id,
                 epoch_id: epoch.id
               })

      assert reason =~ "order_probes_invalid"
    end
  end
end
