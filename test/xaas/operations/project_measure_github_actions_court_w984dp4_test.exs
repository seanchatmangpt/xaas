defmodule Xaas.Operations.ProjectMeasure.GitHubActionsCourtW984dp4Test do
  @moduledoc """
  Lane W984dp4 burn-down court for `Xaas.Operations.ProjectMeasure.GitHubActions`
  (`lib/xaas/operations/project_measure/github_actions.ex`, 151 LOC).

  Fresh CamelCase-aware census (this lane): the module had ZERO test references
  anywhere under `test/` — the sibling `test/xaas/operations/project_measure_test.exs`
  covers the `ProjectMeasure` resource surface but never `GitHubActions`.

  What is courted (per test, real invariants + the mutant class each kills):

  1. Repository identity fail-closed (`REFUSED[REPOSITORY_IDENTITY_INVALID]`)
     — kills any mutant that removes or loosens `split_repository/1` (e.g.
     treating `"owner"` or `""` as a valid identity and emitting a malformed
     `/repos//...` request to the wire).
  2. Real multi-page pagination over real HTTP (Bandit/Plug on 127.0.0.1,
     port 0; the module's real Req client crosses real TCP) — kills
     off-by-one `pages` computations (`div` instead of ceiling, or an early
     `page >= pages` stop) that silently drop the final partial page.
  3. Truncation fail-closed (`CI_RUN_SEARCH_TRUNCATED`) — kills any mutant
     that drops the `length(all_rows) == total` final consistency check,
     which would admit a truncated run population as complete evidence.
  4. Mid-pagination count drift (`CI_RUN_COUNT_DRIFT`) — kills any mutant
     that removes `validate_total/4`'s expected-vs-observed comparison, the
     pagination analog of the module's stated fail-closed doctrine.
  5. Bounded pagination cap (`CI_RUN_PAGINATION_UNBOUNDED` at page 101) —
     kills any mutant that removes or raises the `@max_pages` guard clause,
     i.e. the loop-termination safety property.

  All collaborators are real: the module's own `request/3` uses `Req.get/2`
  against a real Bandit listener; no mocks, no stubs. Server behavior is
  scripted through `:persistent_term` (Bandit handlers run in other
  processes); wire hits are counted with a real `:counters` counter.
  """

  use ExUnit.Case, async: false

  alias Xaas.Operations.ProjectMeasure.GitHubActions

  @since ~U[2026-10-01 00:00:00Z]
  @until ~U[2026-10-07 00:00:00Z]

  @server_key {__MODULE__, :server}
  @hits_key {__MODULE__, :hits}

  setup do
    :persistent_term.put(@hits_key, :counters.new(1, [:atomics]))

    on_exit(fn ->
      :persistent_term.erase(@server_key)
      :persistent_term.erase(@hits_key)
    end)

    :ok
  end

  # ------------------------------------------------------------------
  # Real local HTTP endpoint (same Chicago pattern as
  # gymact_surface_deepening_test.exs): real Bandit listener on an
  # OS-assigned port, real Req client on the module side.
  # ------------------------------------------------------------------

  defp start_server(totals_by_page, rows_by_page) do
    port = free_port()

    :persistent_term.put(@server_key, %{
      totals_by_page: totals_by_page,
      rows_by_page: rows_by_page
    })

    {:ok, _} =
      Bandit.start_link(
        plug: __MODULE__,
        ip: {127, 0, 0, 1},
        port: port,
        thousand_island_options: [shutdown_timeout: 100]
      )

    port
  end

  defp free_port do
    {:ok, socket} = :gen_tcp.listen(0, ip: {127, 0, 0, 1})
    {:ok, port} = :inet.port(socket)
    :gen_tcp.close(socket)
    port
  end

  defp run(repository, port) do
    GitHubActions.list_workflow_runs(repository, @since, @until,
      api_url: "http://127.0.0.1:#{port}"
    )
  end

  defp hits do
    :persistent_term.get(@hits_key, nil) |> :counters.get(1)
  end

  defp row(i), do: %{"id" => i, "name" => "run-#{i}"}

  # -- the Plug served by Bandit --------------------------------------

  def init(opts), do: opts

  def call(conn, _opts) do
    :counters.add(hits_counter(), 1, 1)

    %{totals_by_page: totals, rows_by_page: by_page} = :persistent_term.get(@server_key)

    page =
      conn.query_string
      |> Plug.Conn.Query.decode()
      |> Map.get("page", "1")
      |> String.to_integer()

    total = Map.get(totals, page) || Map.get(totals, 1)
    served = Map.get(by_page, page, 0)
    rows = if served > 0, do: Enum.map(1..served//1, &row(page * 1000 + &1)), else: []

    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(200, Jason.encode!(%{"total_count" => total, "workflow_runs" => rows}))
  end

  defp hits_counter, do: :persistent_term.get(@hits_key)

  # ------------------------------------------------------------------
  # 1. Repository identity fail-closed
  # ------------------------------------------------------------------

  test "1. malformed repository identities are typed-refused without touching the wire" do
    port = start_server(%{1 => 0}, %{})

    # Disclosed contract boundary (observed, not courted as an invariant):
    # split_repository/1 checks only that both "/"-split parts are non-empty,
    # so whitespace-laden identities (" a/b") and embedded-slash names
    # ("o//r" -> name "/r") pass through verbatim into the request path.
    # This lane courts the fail-closed refusals, not a stricter identity
    # grammar the module never promised.
    for bad <- ["owner-only", "", "owner/", "/name", nil] do
      assert {:error, "REFUSED[REPOSITORY_IDENTITY_INVALID] repository=" <> rest} =
               run(bad, port),
             "expected typed refusal for #{inspect(bad)}"

      assert rest == if is_binary(bad), do: bad, else: inspect(bad)
    end

    assert hits() == 0, "no request should have been made for a malformed identity"
  end

  # ------------------------------------------------------------------
  # 2. Real multi-page pagination
  # ------------------------------------------------------------------

  test "2. paginates the real final partial page over real HTTP and returns all rows" do
    # 250 total => pages = ceil(250/100) = 3 (100 + 100 + 50)
    port = start_server(%{1 => 250}, %{1 => 100, 2 => 100, 3 => 50})

    assert {:ok, rows} = run("owner/name", port)

    assert length(rows) == 250
    ids = rows |> Enum.map(& &1["id"]) |> Enum.sort()
    assert ids == Enum.to_list(1001..1100) ++ Enum.to_list(2001..2100) ++ Enum.to_list(3001..3050),
           "expected the exact three real pages including the final 50-row partial page, no drops"

    assert hits() == 3, "expected exactly 3 real HTTP page requests"
  end

  # ------------------------------------------------------------------
  # 3. Truncation fail-closed
  # ------------------------------------------------------------------

  test "3. a short final population is refused, never admitted as complete" do
    # Server reports 250 total but only ever serves 200 rows (page 3 is
    # empty). The truncation check must make this visible.
    port = start_server(%{1 => 250}, %{1 => 100, 2 => 100, 3 => 0})

    assert {:error, "REFUSED[CI_RUN_SEARCH_TRUNCATED]" <> _} = run("owner/name", port)
  end

  # ------------------------------------------------------------------
  # 4. Mid-pagination count drift
  # ------------------------------------------------------------------

  test "4. a total_count that changes mid-pagination is refused" do
    # Page 1 reports total 200; pages >= 2 report 150 -> the drift check
    # must fail closed on page 2. Flip is keyed by page number inside the
    # plug itself, so there is no race with the client's sequential fetch.
    port = start_server(%{1 => 200, 2 => 150}, %{1 => 100})

    assert {:error, "REFUSED[CI_RUN_COUNT_DRIFT]" <> _} = run("owner/name", port)
    assert hits() == 2, "refusal must fire on the second page, before any further fetch"
  end

  # ------------------------------------------------------------------
  # 5. Bounded pagination
  # ------------------------------------------------------------------

  test "5. pagination is bounded: huge reported population hits the cap, not an unbounded loop" do
    # 12_000 total => pages = 120 > @max_pages(100): the fetch loop must
    # refuse at the cap instead of looping forever. 100 real HTTP requests.
    port = start_server(%{1 => 12_000}, %{})

    assert {:error, "REFUSED[CI_RUN_PAGINATION_UNBOUNDED]" <> _} = run("owner/name", port)

    assert hits() == 100, "expected exactly @max_pages real requests before the cap fired"
  end
end
