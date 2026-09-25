defmodule Xaas.Ultracode.Learn.ProjectionTest do
  use Xaas.DataCase, async: false

  @moduledoc """
  Chicago-style qualification of the learning projection into worker
  behavior (`Xaas.Ultracode.Learn.Projection`): real sandboxed Postgres for
  every test that touches the loop's repair-goal assembly (real
  `Xaas.Ultracode.Autonomic.create_run_and_epoch/5` over real `Run`/`Epoch`
  rows and a real ticket file on disk), and a real campaign ledger on disk
  for the `mix xaas.ultracode.learn` task's digest + append.

  The facts themselves are FIXTURES injected through the production
  `config :xaas, :ultracode_learn_facts` resolver seam (the same {module,
  fun}/fun-1 seam shape as `:ultracode_wave_runner`) -- the seam the wave's
  E3 sibling's `Xaas.Ultracode.Learn.campaign_facts/1` plugs into by
  default. The fail-open law is asserted both with a failing stub AND with
  the REAL default resolver while `Learn` has no facts for the campaign:
  the repair goal, the ticket, and the loop's progress never depend on
  Learn.

  Covered law:

    * `repair_context/2` -- deterministic, bounded (<= 400 chars), empty
      on no facts / no item / no hint (hints exist only for non-alive
      items);
    * `campaign_facts/1` -- fail-open on `{:error, _}` and on raises,
      memoized once per TTL per campaign, nil for standalone runs;
    * `campaign_id/1` -- ledger-path token resolution to the FULL campaign
      Run id through real rows, token fallback, nil for standalone runs;
    * repair-goal wiring -- the learned block rides AFTER the loop's own
      court text (`goal_with == goal_without <> repair_context(...)`),
      attempt 1 of a later wave still gets the hint, and a facts-less wave
      produces the byte-identical historical goal;
    * ticket stamping -- `"learn"` section on attempt >= 2 only, with hint
      + failure fingerprints; idempotent shape; absent without facts;
    * the mix task -- read-only digest (per item + aggregate), exactly one
      `learn` event per invocation on the real campaign ledger, honest
      `{:error, _}` on unjudgeable campaigns.
  """

  alias Mix.Tasks.Xaas.Ultracode.Learn, as: LearnTask
  alias Xaas.Ultracode.{Autonomic, Campaign, Run}
  alias Xaas.Ultracode.Learn.Projection

  @suite "aps-dod"
  @base_sha "5c31d9d05fe36dc1eca3a26c9eb5cd267a2cf625"
  @hint "The court rejected attempt 2: min_new_tests not met; add at least 4 tests under tests/."

  @facts %{
    campaign_id: "00000000-0000-0000-0000-00000000abcd",
    generated_at: "2026-09-21T00:00:00Z",
    ocel_valid: true,
    # Byte-for-byte the Learn contract's shape: atom finals, atom receipt
    # outcomes, string fingerprints, hints only for non-alive items.
    items: [
      %{
        item_id: "item-a",
        attempts: 3,
        final: :blocked,
        court_verdicts: [:build_broken, :timeout],
        failure_fingerprints: ["aps_backlog:min_new_tests", "court:fail"]
      },
      %{
        item_id: "item-alive",
        attempts: 1,
        final: :alive,
        court_verdicts: [:pass],
        failure_fingerprints: []
      }
    ],
    aggregate: %{attempts_total: 5, rate_limits: 1, reaps: 1, median_attempt_seconds: 300.0},
    hints: %{"item-a" => @hint}
  }

  @item %{
    "id" => "item-a",
    "goal" => "Fix the standing contract tests",
    "allowed_paths" => ["tests/test_standing_contract.py"],
    "min_new_tests" => 4,
    "min_kill_ratio" => 1.0,
    "mutants" => []
  }

  @history [%{attempt: 1, failure: "court verdict fail (receipt outcome build_broken): 2 failed"}]

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)

    # The campaign/run rows' real VerifierSuiteRegistered validation needs
    # the suite registered, exactly as dev.exs does for the operator.
    Application.put_env(:xaas, :ultracode_verifier_suites, %{
      @suite => %{steps: []}
    })

    # VM-unique ticket dir (the campaign_test tripwire: $TMPDIR is shared
    # across concurrently running `mix test` VMs).
    ticket_dir =
      Path.join(
        System.tmp_dir!(),
        "xaas-learn-projection-test-#{System.system_time(:millisecond)}-" <>
          "#{System.unique_integer([:positive])}"
      )

    Application.put_env(:xaas, :ultracode_ticket_dir, ticket_dir)
    Application.delete_env(:xaas, :ultracode_learn_facts)

    on_exit(fn ->
      Application.delete_env(:xaas, :ultracode_verifier_suites)
      Application.delete_env(:xaas, :ultracode_learn_facts)
      Application.delete_env(:xaas, :ultracode_ticket_dir)
      File.rm_rf!(ticket_dir)
    end)

    %{ticket_dir: ticket_dir}
  end

  # ------------------------------------------------------------------
  # Fixtures
  # ------------------------------------------------------------------

  # A wave-loop ctx with a real Campaign-shaped ledger path inside the
  # test's ticket dir. Unique 4-byte token per call, so the projection's
  # per-campaign memoization never crosses tests.
  defp wiring_ctx(ticket_dir) do
    token = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)

    ctx = %{
      ledger: Path.join([ticket_dir, "campaign-#{token}", "ledger.ndjson"]),
      ticket_dir: ticket_dir,
      repo: "aps",
      repos: %{"aps" => %{suite: @suite, base_sha: @base_sha}},
      provider: "zcode-learn-projection-test"
    }

    {token, ctx}
  end

  defp with_facts_resolver(fun \\ fn _cid -> {:ok, @facts} end),
    do: Application.put_env(:xaas, :ultracode_learn_facts, fun)

  # ------------------------------------------------------------------
  # repair_context/2: deterministic, bounded, fail-open
  # ------------------------------------------------------------------

  test "repair_context is deterministic and bounded" do
    context = Projection.repair_context(@facts, "item-a")

    assert context == Projection.repair_context(@facts, "item-a")
    assert String.length(context) <= 400
    assert context =~ "\n\nLEARNED CONTEXT (prior campaign attempts, advisory):\n"
    assert context =~ "prior attempts: 3, final standing: blocked"
    assert context =~ "court verdicts: build_broken; timeout"
    assert context =~ "hint: #{@hint}"
  end

  test "repair_context is empty without facts, without the item, or without a hint" do
    assert Projection.repair_context(nil, "item-a") == ""
    assert Projection.repair_context(%{}, "item-a") == ""
    assert Projection.repair_context("garbage", "item-a") == ""
    assert Projection.repair_context(@facts, "item-unknown") == ""
    assert Projection.repair_context(@facts, :not_a_binary) == ""

    # The alive item has facts but (per the Learn contract) no hint: no
    # learned block -- hints exist only for non-alive items.
    assert Projection.repair_context(@facts, "item-alive") == ""

    # An item whose facts exist but whose hint is missing/empty: empty.
    no_hint = %{items: @facts.items, hints: %{}}
    assert Projection.repair_context(no_hint, "item-a") == ""
  end

  # ------------------------------------------------------------------
  # campaign_facts/1: fail-open + memoization
  # ------------------------------------------------------------------

  test "facts fetch fails open on a resolver error and on a raise" do
    token = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)

    with_facts_resolver(fn _cid -> {:error, :learn_down} end)
    Projection.clear_cache(token)
    assert Projection.campaign_facts(token) == nil

    raising_token = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
    with_facts_resolver(fn _cid -> raise "learn exploded" end)
    Projection.clear_cache(raising_token)
    assert Projection.campaign_facts(raising_token) == nil
  end

  test "the REAL default resolver (Learn absent or facts-less) fails open" do
    token = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)

    Application.delete_env(:xaas, :ultracode_learn_facts)
    Projection.clear_cache(token)

    # No campaign row and no ledger exist for this token: the real default
    # ({Learn, :campaign_facts}) either refuses typed ({:error, _}) or is
    # not loaded yet (UndefinedFunctionError) -- either way, nil facts and
    # an empty projection, never a raise into the loop.
    assert Projection.campaign_facts(token) == nil
    assert %{context: "", ticket: nil} = Projection.item_learning(%{ledger: "x"}, "item-a")
  end

  test "facts are memoized once per campaign within the TTL" do
    token = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
    Process.put(:learn_resolver_calls, 0)

    with_facts_resolver(fn _cid ->
      Process.put(:learn_resolver_calls, Process.get(:learn_resolver_calls, 0) + 1)
      {:ok, @facts}
    end)

    Projection.clear_cache(token)

    assert Projection.campaign_facts(token) == @facts
    assert Projection.campaign_facts(token) == @facts
    assert Process.get(:learn_resolver_calls) == 1

    # The memoization is per campaign id: another campaign fetches again.
    other = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
    Projection.clear_cache(other)
    assert Projection.campaign_facts(other) == @facts
    assert Process.get(:learn_resolver_calls) == 2

    Projection.clear_cache(token)
    Projection.clear_cache(other)
  end

  test "a non-map facts payload fails open" do
    token = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
    with_facts_resolver(fn _cid -> {:ok, "not a map"} end)
    Projection.clear_cache(token)
    assert Projection.campaign_facts(token) == nil
  end

  test "item_learning never raises, whatever the ctx" do
    assert %{context: "", ticket: nil} = Projection.item_learning(%{}, "item-a")
    assert %{context: "", ticket: nil} = Projection.item_learning(nil, "item-a")
    assert %{context: "", ticket: nil} = Projection.item_learning(%{ledger: 42}, "item-a")
  end

  # ------------------------------------------------------------------
  # campaign_id/1: ledger-path identity
  # ------------------------------------------------------------------

  test "a standalone autonomic ledger path has no campaign identity" do
    assert Projection.campaign_id(%{ledger: "/tmp/tickets/autonomic-a1b2c3/ledger.ndjson"}) ==
             nil

    assert Projection.campaign_id(%{}) == nil
    assert Projection.campaign_id(nil) == nil
  end

  test "a campaign ledger path resolves to the FULL campaign Run id through real rows" do
    campaign = campaign_row!()

    token = String.slice(campaign.id, 0, 8)
    ctx = %{ledger: Path.join([tmp_ticket_dir(), "campaign-#{token}", "ledger.ndjson"])}

    assert Projection.campaign_id(ctx) == campaign.id
  end

  test "an unresolvable campaign token falls back to the token itself" do
    token = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
    ctx = %{ledger: Path.join([tmp_ticket_dir(), "campaign-#{token}", "ledger.ndjson"])}

    assert Projection.campaign_id(ctx) == token
  end

  # ------------------------------------------------------------------
  # Repair-goal + ticket wiring (real create_run_and_epoch, real rows)
  # ------------------------------------------------------------------

  test "repair goal with facts equals the facts-less goal plus the learned block", %{
    ticket_dir: ticket_dir
  } do
    {token_with, ctx_with} = wiring_ctx(ticket_dir)
    {token_without, ctx_without} = wiring_ctx(ticket_dir)

    with_facts_resolver()
    Projection.clear_cache(token_with)
    {run_with, _} = Autonomic.create_run_and_epoch(@item, nil, 2, @history, ctx_with)

    with_facts_resolver(fn _cid -> {:error, :learn_down} end)
    Projection.clear_cache(token_without)
    {run_without, _} = Autonomic.create_run_and_epoch(@item, nil, 2, @history, ctx_without)

    # The learned block rides AFTER the loop's own court text, exactly
    # repair_context -- nothing else about the goal changed.
    assert run_with.goal ==
             run_without.goal <> Projection.repair_context(@facts, "item-a")

    assert run_with.goal =~ "PREVIOUS ATTEMPT(S) WERE REJECTED BY THE INDEPENDENT COURT"
    assert run_without.goal =~ "PREVIOUS ATTEMPT(S) WERE REJECTED BY THE INDEPENDENT COURT"
    refute run_without.goal =~ "LEARNED CONTEXT"
  end

  test "attempt 1 of a later wave receives the hint in the goal but no ticket learn section", %{
    ticket_dir: ticket_dir
  } do
    {token, ctx} = wiring_ctx(ticket_dir)
    with_facts_resolver()
    Projection.clear_cache(token)

    {run, epoch} = Autonomic.create_run_and_epoch(@item, nil, 1, [], ctx)

    assert run.goal == @item["goal"] <> Projection.repair_context(@facts, "item-a")
    assert epoch.run_id == run.id

    ticket = ticket_json(ctx, run.id)
    refute Map.has_key?(ticket, "learn")
  end

  test "attempt >= 2 stamps the ticket's learn section (hint + fingerprints)", %{
    ticket_dir: ticket_dir
  } do
    {token, ctx} = wiring_ctx(ticket_dir)
    with_facts_resolver()
    Projection.clear_cache(token)

    {run, _} = Autonomic.create_run_and_epoch(@item, nil, 2, @history, ctx)

    ticket = ticket_json(ctx, run.id)
    assert %{"learn" => learn} = ticket
    assert learn["hint"] == @hint
    assert learn["failure_fingerprints"] == ["aps_backlog:min_new_tests", "court:fail"]
    assert learn["attempts"] == 3

    # Contract atom `final`/verdicts stringify into the JSON ticket.
    assert learn["final"] == "blocked"
    assert learn["court_verdicts"] == ["build_broken", "timeout"]

    # The historical ticket shape is otherwise intact.
    assert ticket["schemaVersion"] == "aps-ticket/1"
    assert ticket["item"] == "item-a"
    assert ticket["attempt"] == 2
    assert ticket["history"] == [@history |> hd() |> stringify()]
  end

  test "attempt >= 2 without facts stamps nothing (byte-shaped fail-open ticket)", %{
    ticket_dir: ticket_dir
  } do
    {token, ctx} = wiring_ctx(ticket_dir)
    with_facts_resolver(fn _cid -> {:error, :learn_down} end)
    Projection.clear_cache(token)

    {run, _} = Autonomic.create_run_and_epoch(@item, nil, 2, @history, ctx)

    ticket = ticket_json(ctx, run.id)
    refute Map.has_key?(ticket, "learn")
    assert ticket["schemaVersion"] == "aps-ticket/1"
    assert ticket["history"] == [@history |> hd() |> stringify()]
  end

  test "the learn section is idempotent: identical facts stamp identical sections", %{
    ticket_dir: ticket_dir
  } do
    {token_a, ctx_a} = wiring_ctx(ticket_dir)
    {token_b, ctx_b} = wiring_ctx(ticket_dir)

    with_facts_resolver()
    Projection.clear_cache(token_a)
    {run_a, _} = Autonomic.create_run_and_epoch(@item, nil, 2, @history, ctx_a)

    Projection.clear_cache(token_b)
    {run_b, _} = Autonomic.create_run_and_epoch(@item, nil, 2, @history, ctx_b)

    assert ticket_json(ctx_a, run_a.id)["learn"] == ticket_json(ctx_b, run_b.id)["learn"]

    # Stamping the same section twice yields the same map (idempotent shape).
    learn = ticket_json(ctx_a, run_a.id)["learn"]
    assert Projection.stamp_ticket(%{}, 2, %{context: "", ticket: learn}) == %{learn: learn}
  end

  # ------------------------------------------------------------------
  # mix xaas.ultracode.learn: digest read-only, exactly one event per run
  # ------------------------------------------------------------------

  test "digest is read-only and appends nothing" do
    campaign = campaign_row!()
    ledger = campaign_ledger!(campaign.id)

    with_facts_resolver()

    assert {:ok, digest, ^ledger} = LearnTask.digest(campaign.id)
    assert digest["campaign_id"] == campaign.id
    assert digest["ocel_valid"] == true

    assert digest["aggregate"] == %{
             "attempts_total" => 5,
             "rate_limits" => 1,
             "reaps" => 1,
             "median_attempt_seconds" => 300.0
           }

    assert [%{"item_id" => "item-a"}, %{"item_id" => "item-alive"}] =
             Enum.sort_by(digest["items"], & &1["item_id"])

    item_a = Enum.find(digest["items"], &(&1["item_id"] == "item-a"))
    assert item_a["hint"] == true
    assert item_a["attempts"] == 3
    assert item_a["final"] == "blocked"
    assert item_a["court_verdicts"] == 2
    assert item_a["failure_fingerprints"] == ["aps_backlog:min_new_tests", "court:fail"]

    alive = Enum.find(digest["items"], &(&1["item_id"] == "item-alive"))
    assert alive["hint"] == false
    assert alive["final"] == "alive"

    # Read-only: the ledger is untouched by the digest.
    assert File.read!(ledger) == seed_event_line()
  end

  test "append_learn_event appends exactly one learn event per invocation" do
    campaign = campaign_row!()
    ledger = campaign_ledger!(campaign.id)
    with_facts_resolver()
    {:ok, digest, ^ledger} = LearnTask.digest(campaign.id)

    assert :ok = LearnTask.append_learn_event(ledger, digest)

    events = ledger_events(ledger)
    assert length(events) == 2

    assert [%{"event" => "learn", "data" => ^digest, "ts" => ts}] =
             Enum.filter(events, &(&1["event"] == "learn"))

    assert is_binary(ts)

    # The second task invocation appends exactly one more, never rewriting.
    assert :ok = LearnTask.append_learn_event(ledger, digest)
    assert LearnTask.digest(campaign.id) |> elem(0) == :ok

    learn_events = Enum.filter(ledger_events(ledger), &(&1["event"] == "learn"))
    assert length(learn_events) == 2
    assert Enum.at(ledger_events(ledger), 0)["event"] == "campaign_start"
  end

  test "digest reports errors honestly (never an empty digest)" do
    campaign = campaign_row!()

    with_facts_resolver(fn _cid -> {:error, :learn_down} end)

    assert {:error, {:facts_unavailable, id, :learn_down}} = LearnTask.digest(campaign.id)
    assert id == campaign.id

    with_facts_resolver(fn _cid -> :garbage end)
    assert {:error, {:bad_facts, id2, :garbage}} = LearnTask.digest(campaign.id)
    assert id2 == campaign.id

    assert {:error, :campaign_not_found} = LearnTask.digest(Ecto.UUID.generate())

    non_campaign =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{goal: "a plain run, not a campaign", provider: "zcode-learn-test", max_cycles: 1},
        authorize?: false
      )
      |> Ash.create!()

    assert {:error, {:not_a_campaign, id3}} = LearnTask.digest(non_campaign.id)
    assert id3 == non_campaign.id
  end

  test "digest(nil) resolves the most recent campaign row" do
    _older = campaign_row!()
    newest = campaign_row!()

    with_facts_resolver()

    assert {:ok, digest, _ledger} = LearnTask.digest(nil)
    assert digest["campaign_id"] == newest.id
  end

  # ------------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------------

  defp tmp_ticket_dir, do: Application.fetch_env!(:xaas, :ultracode_ticket_dir)

  defp campaign_row! do
    Run
    |> Ash.Changeset.for_create(
      :create,
      %{
        goal: "#{Campaign.goal_marker()} learn projection qualification campaign",
        provider: "zcode-learn-projection-test",
        verifier_suite: @suite,
        max_cycles: 2
      },
      authorize?: false
    )
    |> Ash.create!()
  end

  defp campaign_ledger!(campaign_id) do
    ledger = Path.join(Campaign.campaign_dir(campaign_id), "ledger.ndjson")
    File.mkdir_p!(Path.dirname(ledger))
    File.write!(ledger, seed_event_line())
    ledger
  end

  defp seed_event_line do
    Jason.encode!(%{
      ts: "2026-09-21T00:00:00Z",
      event: "campaign_start",
      campaign_run_id: "seed"
    }) <> "\n"
  end

  defp ledger_events(ledger) do
    ledger
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
  end

  defp ticket_json(ctx, run_id) do
    ctx.ticket_dir |> Path.join("#{run_id}.json") |> File.read!() |> Jason.decode!()
  end

  defp stringify(%{} = m), do: Map.new(m, fn {k, v} -> {to_string(k), v} end)
end
