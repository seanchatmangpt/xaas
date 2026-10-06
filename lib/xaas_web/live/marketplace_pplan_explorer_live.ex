defmodule XaasWeb.MarketplacePplanExplorerLive do
  @moduledoc """
  Ash Phoenix UI for the GCP Marketplace p-plan lifecycle ontology.

  Parses `priv/gcp/marketplace_lifecycle.ttl` at load with `RDF.Turtle` +
  `SPARQL.ex`; renders stakeholder avatars (with domain filter), the 8-step
  workflow inspector, a FinOps spend-drawdown simulator (server-rendered SVG),
  system-dynamics cards, and a raw-Turtle viewer with a server-side line
  filter. All data comes from the ontology; no external CDN scripts.
  """

  use XaasWeb, :live_view

  alias RDF.{IRI, Literal}
  alias RDF.Turtle

  @ttl_path "priv/gcp/marketplace_lifecycle.ttl"
  @gcp "https://cloud.google.com/marketplace/ontology/v1#"
  @rdfs "http://www.w3.org/2000/01/rdf-schema#"
  @pp "http://purl.org/net/p-plan#"
  @prov "http://www.w3.org/ns/prov#"

  # Organization IRI local names -> marketplace domain grouping.
  @org_domains %{
    "KubeScaleTechnologies" => "ISV",
    "ApexGlobalLogistics" => "Enterprise",
    "GoogleCloudPlatform" => "Hyperscaler",
    "StrataCloudSystems" => "Reseller"
  }

  @impl true
  def mount(_params, _session, socket) do
    graph = load_graph()
    steps = load_steps(graph)
    variables = load_variables(graph)

    socket =
      socket
      |> assign(:plan_label, plan_label(graph))
      |> assign(:variables_count, map_size(variables))
      |> assign(:people, load_people(graph))
      |> assign(:orgs, load_orgs(graph))
      |> assign(:steps, steps)
      |> assign(:raw_ttl, ttl_source())
      |> assign(:turtle_query, "")
      |> assign(:domain_filter, "All")
      |> assign(:selected_step, 1)
      |> assign_sim(%{"pool" => "10000000", "deal" => "500000", "burn" => "60"})

    {:ok, socket}
  end

  # ------------------------------------------------------------- graph loading

  defp ttl_file do
    case Application.app_dir(:xaas, @ttl_path) do
      {:error, _} -> Path.expand(@ttl_path)
      path -> path
    end
  end

  defp load_graph do
    case Turtle.read_file(ttl_file()) do
      {:ok, %RDF.Graph{} = graph} -> graph
      {:error, reason} -> raise "failed to parse #{@ttl_path}: #{inspect(reason)}"
    end
  end

  defp ttl_source, do: File.read!(ttl_file())

  defp lv([term]), do: lv(term)
  defp lv(nil), do: nil
  defp lv(%Literal{} = lit), do: Literal.value(lit)
  defp lv(%IRI{} = iri), do: iri.value

  defp objects(graph, subject, predicate) do
    graph
    |> RDF.Graph.description(subject)
    |> RDF.Description.get(predicate, [])
    |> List.wrap()
  end

  defp local_name(%IRI{} = iri), do: local_name(iri.value)

  defp local_name(iri) do
    iri |> to_string() |> String.split(["#", "/"]) |> List.last()
  end

  defp iri(ns, local), do: RDF.iri(ns <> local)

  # ------------------------------------------------------------------- people

  defp load_people(graph) do
    query = """
    PREFIX gcp: <#{@gcp}>
    PREFIX prov: <#{@prov}>
    PREFIX rdfs: <#{@rdfs}>
    SELECT ?person ?name ?role ?org
    WHERE {
      ?person a prov:Person ;
              rdfs:label ?name ;
              gcp:roleTitle ?role ;
              gcp:memberOfOrganization ?org .
    }
    """

    result = SPARQL.execute_query(graph, query)

    case result do
      %SPARQL.Query.Result{} ->
        result.results
        |> Enum.map(fn row ->
          %{
            id: to_string(row["person"]),
            name: lv(row["name"]),
            role: lv(row["role"]),
            org: org_label(graph, row["org"]),
            domain: Map.get(@org_domains, local_name(row["org"]), "Other")
          }
        end)
        |> Enum.sort_by(&{&1.domain, &1.name})
    end
  end

  defp org_label(graph, org_iri_term) do
    graph
    |> RDF.Graph.description(org_iri_term)
    |> RDF.Description.get(iri(@rdfs, "label"), nil)
    |> lv()
    |> Kernel.||(local_name(org_iri_term))
  end

  defp load_orgs(graph) do
    query = """
    PREFIX prov: <#{@prov}>
    PREFIX rdfs: <#{@rdfs}>
    SELECT ?org ?label
    WHERE {
      ?org a prov:Organization ;
           rdfs:label ?label .
    }
    """

    result = SPARQL.execute_query(graph, query)

    case result do
      %SPARQL.Query.Result{} ->
        result.results
        |> Enum.map(fn row -> %{id: to_string(row["org"]), label: lv(row["label"])} end)
        |> Enum.sort_by(& &1.label)
    end
  end

  # -------------------------------------------------------------------- steps

  defp load_steps(graph) do
    step_type = iri(@pp, "Step")

    label_of = fn subject ->
      graph
      |> RDF.Graph.description(subject)
      |> RDF.Description.get(iri(@rdfs, "label"), nil)
      |> lv()
      |> Kernel.||(local_name(subject))
    end

    steps_by_iri =
      graph
      |> RDF.Graph.subjects()
      |> Enum.filter(fn subject ->
        step_type in objects(graph, subject, RDF.type())
      end)
      |> Map.new(fn subject -> {subject, build_step(graph, subject, label_of)} end)

    order_chain(steps_by_iri, label_of)
  end

  defp build_step(graph, subject, label_of) do
    %{
      iri: subject,
      label: label_of.(subject),
      preceded_by: objects(graph, subject, iri(@pp, "isPrecededBy")),
      agents: objects(graph, subject, iri(@prov, "wasAssociatedWith")),
      inputs: objects(graph, subject, iri(@pp, "hasInputVar")),
      outputs: objects(graph, subject, iri(@pp, "hasOutputVar"))
    }
  end

  # Execution order = the isPrecededBy chain: start at the step with no
  # predecessor, then follow each step's successor until all steps are emitted.
  defp order_chain(steps_by_iri, label_of) do
    first =
      steps_by_iri
      |> Enum.find(fn {_, step} -> step.preceded_by == [] end)
      |> elem(0)

    successors =
      steps_by_iri
      |> Enum.flat_map(fn {iri, step} ->
        Enum.map(step.preceded_by, fn pred -> {pred, iri} end)
      end)
      |> Map.new()

    Stream.unfold(first, fn
      nil -> nil
      current -> {current, Map.get(successors, current)}
    end)
    |> Enum.with_index(1)
    |> Enum.map(fn {step_iri, n} ->
      step = Map.fetch!(steps_by_iri, step_iri)
      %{
        n: n,
        label: step.label,
        preceded_by_label:
          case step.preceded_by do
            [pred | _] -> label_of.(pred)
            [] -> nil
          end,
        agent_labels: Enum.map(step.agents, label_of),
        input_labels: Enum.map(step.inputs, label_of),
        output_labels: Enum.map(step.outputs, label_of)
      }
    end)
  end

  # ----------------------------------------------------------------- variables

  defp load_variables(graph) do
    query = """
    PREFIX p-plan: <#{@pp}>
    PREFIX rdfs: <#{@rdfs}>
    SELECT ?var ?label
    WHERE {
      ?var a p-plan:Variable ;
           rdfs:label ?label .
    }
    """

    result = SPARQL.execute_query(graph, query)

    case result do
      %SPARQL.Query.Result{} ->
        result.results
        |> Map.new(fn row -> {to_string(row["var"]), lv(row["label"])} end)
    end
  end

  defp plan_label(graph) do
    graph
    |> RDF.Graph.description(iri(@gcp, "GCPMarketplaceLifecyclePlan"))
    |> RDF.Description.get(iri(@rdfs, "label"), nil)
    |> lv()
  end

  # -------------------------------------------------------------------- events

  @impl true
  def handle_event("select-step", %{"step" => idx}, socket) do
    {:noreply, assign(socket, :selected_step, String.to_integer(idx))}
  end

  def handle_event("filter-domain", %{"domain" => domain}, socket) do
    {:noreply, assign(socket, :domain_filter, domain)}
  end

  def handle_event("filter-turtle", %{"q" => q}, socket) do
    {:noreply, assign(socket, :turtle_query, q)}
  end

  def handle_event("sim", params, socket) do
    merged =
      socket.assigns.sim
      |> Map.take(["pool", "deal", "burn"])
      |> Map.merge(Map.take(params, ["pool", "deal", "burn"]))

    {:noreply, assign_sim(socket, merged)}
  end

  defp assign_sim(socket, %{"pool" => pool, "deal" => deal, "burn" => burn}) do
    pool = to_num(pool, 10_000_000, 1_000_000, 20_000_000)
    deal = to_num(deal, 500_000, 50_000, 2_000_000)
    burn = to_num(burn, 60, 30, 100)

    organic = pool * burn / 100
    post_total = min(pool, organic + deal)
    unused_commit = pool - organic
    post_unused = pool - post_total

    velocity_gain = if organic > 0, do: (post_total - organic) / organic * 100, else: 0.0

    sim = %{
      "pool" => pool,
      "deal" => deal,
      "burn" => burn,
      :series => %{
        baseline: Enum.map(0..12, fn m -> pool - organic * m / 12 end),
        post: Enum.map(0..12, fn m -> max(pool - post_total * m / 12, 0.0) end)
      },
      :kpis => %{
        unused_commit: unused_commit,
        post_unused: post_unused,
        velocity_gain: velocity_gain
      }
    }

    assign(socket, :sim, sim)
  end

  defp to_num(raw, default, min, max) do
    case Float.parse(to_string(raw)) do
      {n, _} -> clamp(n, min, max)
      :error -> default
    end
  end

  defp clamp(n, min, max), do: n |> max(min) |> min(max)

  # -------------------------------------------------------------------- render

  @impl true
  def render(assigns) do
    ~H"""
    <div class="dark mx-auto max-w-6xl min-h-screen bg-slate-950 text-slate-100 p-6 space-y-8">
      <header>
        <h1 class="text-2xl font-bold">GCP Marketplace Lifecycle Explorer</h1>
        <p id="ontology-summary" class="text-slate-400 text-sm mt-1">
          p-plan: {@plan_label} · {@variables_count} variables · {length(@steps)} steps ·
          {length(@people)} agents · {length(@orgs)} organizations
        </p>
      </header>

      <section>
        <h2 class="text-lg font-semibold mb-3">Stakeholder Avatars</h2>
        <form id="domain-filter-form" phx-change="filter-domain">
          <label class="block text-xs uppercase text-slate-400 mb-1" for="domain-filter">Domain</label>
          <select
            id="domain-filter"
            name="domain"
            class="bg-slate-800 border border-slate-700 rounded px-3 py-1.5 text-sm"
          >
            <%= for domain <- domains(@people) do %>
              <option value={domain} selected={@domain_filter == domain}>{domain}</option>
            <% end %>
          </select>
        </form>
        <div id="avatar-grid" class="grid grid-cols-1 md:grid-cols-4 gap-4 mt-3">
          <div
            :for={person <- @people}
            :if={@domain_filter in ["All", person.domain]}
            class="rounded-lg border border-slate-800 bg-slate-900 p-4"
          >
            <div class="flex items-center gap-3">
              <div class="h-10 w-10 rounded-full bg-indigo-600 flex items-center justify-center font-bold shrink-0">
                {initials(person.name)}
              </div>
              <div class="min-w-0">
                <div class="font-medium truncate">{person.name}</div>
                <div class="text-xs text-slate-400 truncate">{person.role}</div>
              </div>
            </div>
            <div class="mt-3 text-xs text-slate-300">
              {person.org}
              <.badge color="primary" size="sm" class="ml-2 align-middle">{person.domain}</.badge>
            </div>
          </div>
        </div>
      </section>

      <section class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div>
          <h2 class="text-lg font-semibold mb-3">Workflow Inspector</h2>
          <ol class="space-y-1">
            <li :for={{step, i} <- Enum.with_index(@steps, 1)}>
              <button
                type="button"
                phx-click="select-step"
                phx-value-step={Integer.to_string(i)}
                class={
                  "w-full text-left px-3 py-2 rounded text-sm " <>
                    if(@selected_step == i,
                      do: "bg-indigo-600 text-white",
                      else: "bg-slate-900 hover:bg-slate-800"
                    )
                }
              >
                {step.label}
              </button>
            </li>
          </ol>
        </div>
        <div class="lg:col-span-2">
          <div
            :for={{step, i} <- Enum.with_index(@steps, 1)}
            :if={@selected_step == i}
            class="rounded-lg border border-slate-800 bg-slate-900 p-5"
            id="step-detail"
          >
            <h3 class="font-semibold">
              {step.label}
              <span class="text-slate-500 font-normal">· step {i} of {length(@steps)}</span>
            </h3>
            <div class="mt-3 grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
              <div>
                <div class="text-slate-400 text-xs uppercase mb-1">Preceded by</div>
                <div>{step.preceded_by_label || "— (chain start)"}</div>
              </div>
              <div>
                <div class="text-slate-400 text-xs uppercase mb-1">Agents</div>
                <div>{Enum.join(step.agent_labels, ", ")}</div>
              </div>
              <div>
                <div class="text-slate-400 text-xs uppercase mb-1">Inputs</div>
                <ul class="list-disc list-inside space-y-0.5">
                  <li :for={input <- step.input_labels}>{input}</li>
                </ul>
              </div>
              <div>
                <div class="text-slate-400 text-xs uppercase mb-1">Outputs</div>
                <ul class="list-disc list-inside space-y-0.5">
                  <li :for={output <- step.output_labels}>{output}</li>
                </ul>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section>
        <h2 class="text-lg font-semibold mb-3">FinOps Spend-Drawdown Simulator</h2>
        <form id="sim-form" phx-change="sim" class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div>
            <label class="block text-sm text-slate-400 mb-1">Commit pool: {fmt_usd(@sim["pool"])}</label>
            <input
              type="range"
              name="pool"
              min="1000000"
              max="20000000"
              step="100000"
              value={@sim["pool"]}
              class="w-full"
            />
          </div>
          <div>
            <label class="block text-sm text-slate-400 mb-1">Deal size: {fmt_usd(@sim["deal"])}</label>
            <input
              type="range"
              name="deal"
              min="50000"
              max="2000000"
              step="10000"
              value={@sim["deal"]}
              class="w-full"
            />
          </div>
          <div>
            <label class="block text-sm text-slate-400 mb-1">Organic burn rate: {trunc(@sim["burn"])}%</label>
            <input type="range" name="burn" min="30" max="100" step="1" value={@sim["burn"]} class="w-full" />
          </div>
        </form>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mt-4">
          <div class="rounded-lg border border-slate-800 bg-slate-900 p-4">
            <div class="text-xs uppercase text-slate-400">Unused commit (baseline)</div>
            <div class="text-xl font-bold">{fmt_usd(@sim.kpis.unused_commit)}</div>
          </div>
          <div class="rounded-lg border border-slate-800 bg-slate-900 p-4">
            <div class="text-xs uppercase text-slate-400">Post-marketplace unused</div>
            <div class="text-xl font-bold text-emerald-400">{fmt_usd(@sim.kpis.post_unused)}</div>
          </div>
          <div class="rounded-lg border border-slate-800 bg-slate-900 p-4">
            <div class="text-xs uppercase text-slate-400">Velocity gain</div>
            <div class="text-xl font-bold text-sky-400">{fmt_pct(@sim.kpis.velocity_gain)}</div>
          </div>
        </div>

        <div class="rounded-lg border border-slate-800 bg-slate-900 p-4 mt-4">
          <.burn_down_chart
            baseline={@sim.series.baseline}
            post={@sim.series.post}
            pool={@sim["pool"]}
          />
        </div>
      </section>

      <section>
        <h2 class="text-lg font-semibold mb-3">System Dynamics</h2>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div class="rounded-lg border border-slate-800 bg-slate-900 p-4">
            <h3 class="font-medium">Two-stage approval race safeguard</h3>
            <p class="text-sm text-slate-400 mt-1">
              Pub/Sub + redirect race condition safeguard: the accounts:approve →
              entitlements:approve two-stage approval keeps entitlement activation
              strictly ordered behind billing binding.
            </p>
          </div>
          <div class="rounded-lg border border-slate-800 bg-slate-900 p-4">
            <h3 class="font-medium">CapEx → OpEx conversion</h3>
            <p class="text-sm text-slate-400 mt-1">
              Marketplace transacts ~80% of ACV, accelerating procurement velocity
              by converting capital expenditure into operational spend.
            </p>
          </div>
          <div class="rounded-lg border border-slate-800 bg-slate-900 p-4">
            <h3 class="font-medium">MCPO zero-fee channel intermediation</h3>
            <p class="text-sm text-slate-400 mt-1">
              Marketplace Channel Private Offers intermediate reseller-led deals
              through a zero-fee channel, keeping MSP margins intact.
            </p>
          </div>
          <div class="rounded-lg border border-slate-800 bg-slate-900 p-4">
            <h3 class="font-medium">Postpay-credit settlement reconciliation</h3>
            <p class="text-sm text-slate-400 mt-1">
              Settlement reconciles drawdown records against the consolidated
              invoice, clearing postpay credits before ISV disbursement.
            </p>
          </div>
        </div>
      </section>

      <section>
        <h2 class="text-lg font-semibold mb-3">Turtle Viewer</h2>
        <form id="turtle-filter-form" phx-change="filter-turtle">
          <input
            type="text"
            name="q"
            value={@turtle_query}
            placeholder="Filter TTL lines (e.g. Step, hasInputVar)..."
            class="w-full bg-slate-800 border border-slate-700 rounded px-3 py-2 text-sm"
          />
        </form>
        <pre class="mt-3 rounded-lg border border-slate-800 bg-black p-4 text-xs overflow-auto max-h-96"><code>{filtered_ttl(@raw_ttl, @turtle_query)}</code></pre>
      </section>
    </div>
    """
  end

  # ---------------------------------------------------------------- components

  attr :baseline, :list, required: true
  attr :post, :list, required: true
  attr :pool, :any, required: true

  defp burn_down_chart(assigns) do
    assigns =
      assigns
      |> assign(:baseline_pts, svg_points(assigns.baseline))
      |> assign(:post_pts, svg_points(assigns.post))

    ~H"""
    <svg viewBox="0 0 760 240" class="w-full" role="img" aria-label="Commit balance burn-down over 12 months">
      <line x1="40" y1="200" x2="720" y2="200" stroke="#334155" />
      <line x1="40" y1="200" x2="40" y2="20" stroke="#334155" />
      <polyline points={@baseline_pts} fill="none" stroke="#64748b" stroke-width="2" stroke-dasharray="6 4" />
      <polyline points={@post_pts} fill="none" stroke="#34d399" stroke-width="2.5" />
      <text x="56" y="35" fill="#94a3b8" font-size="12">baseline (organic only)</text>
      <text x="240" y="35" fill="#34d399" font-size="12">post-marketplace commit balance</text>
      <text x="40" y="220" fill="#64748b" font-size="11">M0</text>
      <text x="705" y="220" fill="#64748b" font-size="11">M12</text>
    </svg>
    """
  end

  defp svg_points(series) do
    y_max = Enum.max(series ++ [1.0])

    series
    |> Enum.with_index()
    |> Enum.map_join(" ", fn {v, i} ->
      x = 40 + i * (680 / (length(series) - 1))
      y = 200 - v / y_max * 180
      "#{:erlang.float_to_binary(x * 1.0, decimals: 1)},#{:erlang.float_to_binary(y * 1.0, decimals: 1)}"
    end)
  end

  defp filtered_ttl(nil, _), do: ""
  defp filtered_ttl(ttl, "") when is_binary(ttl), do: ttl

  defp filtered_ttl(ttl, q) when is_binary(ttl) do
    needle = String.downcase(q)

    ttl
    |> String.split("\n")
    |> Enum.filter(&(needle != "" and String.contains?(String.downcase(&1), needle)))
    |> Enum.join("\n")
  end

  defp domains(people) do
    ["All" | people |> Enum.map(& &1.domain) |> Enum.uniq() |> Enum.sort()]
  end

  defp initials(name) do
    name
    |> String.split()
    |> Enum.map(&String.at(&1, 0))
    |> Enum.take(2)
    |> Enum.join()
  end

  defp fmt_usd(n) when is_number(n) do
    whole = trunc(n)

    whole
    |> Integer.to_string()
    |> reverse_groups()
    |> String.replace(",", ",")
    |> then(&"$" <> &1)
  end

  defp fmt_usd(_), do: "$0"

  defp reverse_groups(digits) do
    digits
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.join()
  end

  defp fmt_pct(n) when is_number(n) do
    :erlang.float_to_binary(n * 1.0, decimals: 1) <> "%"
  end

  defp fmt_pct(_), do: "0.0%"
  end
