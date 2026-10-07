defmodule XaasWeb.SensitiveResourcesRoutingCourtTest do
  @moduledoc """
  W829 — sensitive-resources routing court.

  Doctrine (CLAUDE.md "Sensitive resources") declares Ledger.Balance/Account/
  Transfer and Accounts.User/Token are deliberately unwired from `/api`. This
  court pins that doctrine as a real routing fact via genuine route
  introspection — `Phoenix.Router.routes/1` for the parent Phoenix router and
  `AshJsonApi.Router.formatted_routes/1` for the two generated AshJsonApi
  routers (which are Plug.Router catch-alls, so `__routes__/0` does not exist
  on them; `formatted_routes/1` IS their real, compiled route table). No HTTP,
  no mocks.
  """

  use ExUnit.Case, async: true

  @sensitive_segments ~w(balances accounts transfers users tokens)

  @ash_routers [XaasWeb.ApiRouter, XaasWeb.InternalApiRouter]

  defp route_table(XaasWeb.Router = router) do
    router
    |> Phoenix.Router.routes()
    |> Enum.map(fn route ->
      %{
        verb: to_string(route.verb),
        segments: segments(route),
        helper: route.helper,
        label: inspect(route.plug) <> "." <> inspect(route.plug_opts)
      }
    end)
  end

  defp route_table(router) when router in @ash_routers do
    router
    |> AshJsonApi.Router.formatted_routes()
    |> Enum.map(fn route ->
      %{
        verb: route.verb,
        segments: route.path |> String.split("/", trim: true),
        helper: nil,
        label: route.label
      }
    end)
  end

  # Phoenix __routes__ entries carry the real path as either :path_info (list)
  # or :path (binary); a few verified-routes entries carry keyword-list path
  # metadata instead — keep only genuine segment binaries from those.
  defp segments(route) do
    case Map.get(route, :path_info) || Map.fetch!(route, :path) do
      path when is_binary(path) -> String.split(path, "/", trim: true)
      path when is_list(path) -> Enum.filter(path, &is_binary/1)
    end
  end

  defp sensitive_hits(routes) do
    Enum.filter(routes, fn route ->
      Enum.any?(route.segments, &(&1 in @sensitive_segments))
    end)
  end

  test "no route in any router references a sensitive resource (path segments)" do
    for router <- [XaasWeb.Router | @ash_routers] do
      routes = route_table(router)
      # the introspection itself must be non-vacuous: every router has real routes
      assert length(routes) > 0, "vacuous introspection: #{router} returned no routes"

      hits = sensitive_hits(routes)
      assert hits == [], """
      sensitive-resource route leak in #{inspect(router)}:
      #{inspect(hits, pretty: true)}
      """
    end
  end

  test "no route helper/label references a sensitive resource" do
    for router <- [XaasWeb.Router | @ash_routers] do
      hits =
        router
        |> route_table()
        |> Enum.filter(fn route ->
          text = route.helper || route.label || ""

          Enum.any?(@sensitive_segments, fn seg ->
            String.contains?(text, String.trim_trailing(seg, "s"))
          end)
        end)

      assert hits == [], """
      sensitive-resource helper/label leak in #{inspect(router)}:
      #{inspect(hits, pretty: true)}
      """
    end
  end

  test "deliberately-wired exceptions: Org create/update routes ARE present on /api" do
    api = route_table(XaasWeb.ApiRouter)

    # formatted_routes/1 paths exclude the router's /api mount prefix
    assert Enum.any?(api, fn r ->
             r.verb == :post and r.segments == ["orgs"] and
               String.contains?(r.label, "Org.create")
           end),
           "POST /api/orgs (Org create) missing from ApiRouter route table: #{inspect(Enum.filter(api, &String.contains?(&1.label, "Org")))}"

    assert Enum.any?(api, fn r ->
             r.verb == :patch and r.segments == ["orgs", ":id"] and
               String.contains?(r.label, "Org.update")
           end),
           "PATCH /api/orgs/:id (Org update) missing from ApiRouter route table"

    assert Enum.any?(api, fn r ->
             r.verb == :get and r.segments == ["orgs"] and
               String.contains?(r.label, "Org.read")
           end),
           "GET /api/orgs (Org index) missing from ApiRouter route table"
  end

  test "typescript_rpc surface (W813 pin) exposes no sensitive domains" do
    # grep-grade pin: extract the real rpc_action declarations from the live
    # domain sources, refute any sensitive-domain token, and assert the
    # extracted set equals the pinned allowed set (drift in either direction fails).
    domain_files = Path.wildcard("lib/xaas/*.ex")
    assert domain_files != []

    extracted =
      domain_files
      |> Enum.flat_map(fn file ->
        file
        |> File.read!()
        |> then(&Regex.scan(~r/rpc_action\(:([a-z0-9_]+),\s*:(\w+)\)/, &1))
        |> Enum.map(fn [_, name, action] -> {file, name, action} end)
      end)

    assert length(extracted) > 0, "vacuous pin: no rpc_action declarations found"

    sensitive_tokens = ~w(user token balance transfer ledger_account)

    for {file, name, _action} <- extracted do
      refute Enum.any?(sensitive_tokens, &String.contains?(name, &1)),
             "rpc action #{name} in #{file} leaks a sensitive-domain token"
    end

    pinned =
      ~w(list_marketplace_providers list_accounts_orgs list_billing_subscriptions measure_project)

    assert Enum.sort(Enum.map(extracted, fn {_, name, _} -> name end)) == Enum.sort(pinned), """
    typescript_rpc surface drifted from the pinned W813 allow-list:
      extracted: #{inspect(Enum.sort(Enum.map(extracted, fn {_, name, _} -> name end)))}
      pinned:    #{inspect(Enum.sort(pinned))}
    """
  end

  test "introspection is deterministic across repeated calls" do
    for router <- [XaasWeb.Router | @ash_routers] do
      first = route_table(router)
      second = route_table(router)
      assert first == second, "non-deterministic route introspection in #{inspect(router)}"
    end
  end
end
