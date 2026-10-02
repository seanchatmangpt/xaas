defmodule XaasWeb.Chicago.SellerLive do
  @moduledoc """
  Chicago agentic-payment seller projection (v26.10.1).

  Renders ONLY what the executive projection carries (`Xaas.Chicago.executive/0`
  per RESOLUTIONS R4, payload shape per R3, artifact
  `priv/chicago/chicago.executive.json` per R1). Standing law (R8): every
  rendered standing is UNKNOWN until a real receipt binds observed execution;
  cases stay candidate predictions. On a refused or missing executive this
  surface renders a typed BLOCKED banner and never invented content.

  Zero layer ids, zero case ids and zero narrative sentences are hardcoded in
  this module — all of it comes from the projection JSON. The anti-hardcode
  grep in `test/xaas/chicago/seller/seller_live_test.exs` enforces that.

  Loader seam: `Application.get_env(:xaas, :chicago_executive_loader)` /
  `:chicago_subject_loader` may override the default MFA below. Production
  never sets these keys; only tests mount with a synthesized fixture through
  them.
  """

  use XaasWeb, :live_view

  @default_executive_loader {Xaas.Chicago, :executive, []}
  @default_subject_loader {Xaas.Chicago, :subject, []}
  @blocked_hint "run mix chicago.render"
  @nothing_demonstrated "nothing yet demonstrated on this subject"

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:blocked_hint, @blocked_hint)
      |> assign(:nothing_demonstrated, @nothing_demonstrated)

    case load_executive() do
      {:ok, exec} ->
        demonstrated_ids =
          exec
          |> get_in(["demonstrated"])
          |> List.wrap()
          |> MapSet.new()

        {:ok,
         socket
         |> assign(:exec, exec)
         |> assign(:demonstrated_ids, demonstrated_ids)
         |> assign(:blocked, nil)}

      {:blocked, reason} ->
        {:ok,
         socket
         |> assign(:exec, nil)
         |> assign(:demonstrated_ids, MapSet.new())
         |> assign(:blocked, %{reason: reason, subject: load_subject()})}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="mx-auto max-w-6xl p-8" data-testid="chicago-seller-root">
      <header class="mb-8">
        <p class="text-sm font-semibold uppercase tracking-wide">
          Chicago agentic payment — seller projection
        </p>
        <div :if={is_map(@exec)} class="mt-2 flex flex-wrap items-center gap-3">
          <span
            class="rounded bg-slate-800 px-2 py-1 font-mono text-sm text-slate-100"
            data-testid="chicago-header-subject"
          >
            {@exec["subject"]}
          </span>
          <span
            class="rounded border px-2 py-1 text-xs uppercase tracking-wide"
            data-testid="chicago-authority-claim"
          >
            authorityClaim: {@exec["authorityClaim"]}
          </span>
          <span class="text-xs text-slate-500" data-testid="chicago-generator-identity">
            {@exec["generatorIdentity"]}
          </span>
        </div>
        <div :if={is_map(@exec)} class="mt-2" data-testid="chicago-source-digests">
          <span class="text-xs font-semibold uppercase tracking-wide text-slate-500">
            source digests
          </span>
          <ul class="mt-1">
            <li
              :for={{digest, i} <- digests(@exec)}
              class="font-mono text-xs text-slate-600"
              data-testid={"chicago-source-digest-" <> Integer.to_string(i)}
            >
              {digest["path"]} sha256:{digest["sha256"]}
            </li>
          </ul>
        </div>
      </header>

      <div
        :if={@blocked}
        class="mb-8 rounded border border-red-300 bg-red-50 p-4"
        data-testid="chicago-blocked"
      >
        <p class="font-semibold text-red-800">BLOCKED — executive projection unavailable</p>
        <p class="mt-1 font-mono text-sm text-red-700">{inspect(@blocked.reason)}</p>
        <p class="mt-1 text-sm text-red-700">
          subject:
          <span data-testid="chicago-blocked-subject">
            {@blocked.subject || "unavailable (projection API not loaded)"}
          </span>
        </p>
        <p class="mt-2 text-sm font-medium text-red-900">{@blocked_hint}</p>
      </div>

      <section
        :if={is_map(@exec)}
        class="mb-6 rounded border p-4"
        data-testid="chicago-headline"
      >
        <h1 class="text-2xl font-bold">{get_in(@exec, ["narrative", "headline"])}</h1>
        <p class="mt-1 text-xs uppercase tracking-wide text-slate-500">
          audience: {get_in(@exec, ["narrative", "audience"])}
        </p>
      </section>

      <section
        :if={is_map(@exec)}
        class="mb-6 rounded border p-4"
        data-testid="chicago-customer-problem"
      >
        <h2 class="text-lg font-bold">Customer problem</h2>
        <p class="mt-2 text-sm">{get_in(@exec, ["narrative", "customerProblem"])}</p>
      </section>

      <section
        :if={is_map(@exec)}
        class="mb-6 rounded border p-4"
        data-testid="chicago-desired-outcome"
      >
        <h2 class="text-lg font-bold">Desired outcome</h2>
        <p class="mt-2 text-sm">{get_in(@exec, ["narrative", "desiredOutcome"])}</p>
      </section>

      <section
        :if={is_map(@exec)}
        class="mb-6 rounded border p-4"
        data-testid="chicago-capabilities"
      >
        <h2 class="text-lg font-bold">Relevant capabilities</h2>
        <div class="mt-3 grid gap-3 md:grid-cols-2">
          <article
            :for={cap <- capabilities(@exec)}
            class="rounded border p-3"
            data-testid={"chicago-capability-" <> cap["id"]}
          >
            <div class="flex items-center justify-between gap-2">
              <strong class="text-sm">{cap["label"]}</strong>
              <span
                class={capability_chip_class(capability_state(@demonstrated_ids, cap))}
                data-testid={"chicago-capability-state-" <> cap["id"]}
              >
                {capability_state(@demonstrated_ids, cap)}
              </span>
            </div>
            <p class="mt-1 text-xs uppercase tracking-wide text-slate-500">{cap["role"]}</p>
          </article>
        </div>
      </section>

      <section
        :if={is_map(@exec)}
        class="mb-6 rounded border p-4"
        data-testid="chicago-semantic-path"
      >
        <h2 class="text-lg font-bold">Proposed semantic path</h2>
        <p class="mt-2 font-mono text-sm">{get_in(@exec, ["narrative", "semanticPath"])}</p>
      </section>

      <section
        :if={is_map(@exec)}
        class="mb-6 rounded border p-4"
        data-testid="chicago-demonstrated"
      >
        <h2 class="text-lg font-bold">Demonstrated</h2>
        <p
          :if={Enum.empty?(@demonstrated_ids)}
          class="mt-2 text-sm text-slate-500"
          data-testid="chicago-demonstrated-empty"
        >
          {@nothing_demonstrated}
        </p>
        <ul :if={not Enum.empty?(@demonstrated_ids)} class="mt-2 list-disc pl-5">
          <li
            :for={id <- Enum.sort(@demonstrated_ids)}
            class="text-sm"
            data-testid={"chicago-demonstrated-" <> id}
          >
            {id}
          </li>
        </ul>
      </section>

      <section
        :if={is_map(@exec)}
        class="mb-6 rounded border p-4"
        data-testid="chicago-scenarios"
      >
        <h2 class="text-lg font-bold">Candidate-partial</h2>
        <p class="mt-1 text-xs text-slate-500">
          candidate case predictions — never pre-judged outcomes
        </p>
        <h3 class="mt-3 text-sm font-semibold">
          positive
          <span data-testid="chicago-scenarios-positive-count">{scenario_count(@exec, "positive")}</span>
        </h3>
        <ul class="mt-1">
          <li
            :for={scenario <- scenarios(@exec, "positive")}
            class="mt-2 rounded border p-2"
            data-testid={"chicago-scenario-" <> scenario["id"]}
          >
            <span
              class="mr-2 rounded bg-emerald-100 px-1.5 py-0.5 text-xs text-emerald-800"
              data-testid={"chicago-scenario-polarity-" <> scenario["id"]}
            >
              {scenario["polarity"]}
            </span>
            <strong class="text-sm">{scenario["label"]}</strong>
            <span class="ml-1 font-mono text-xs text-slate-500">{scenario["id"]}</span>
            <p class="mt-1 text-sm">{scenario["description"]}</p>
          </li>
        </ul>
        <h3 class="mt-3 text-sm font-semibold">
          negative
          <span data-testid="chicago-scenarios-negative-count">{scenario_count(@exec, "negative")}</span>
        </h3>
        <ul class="mt-1">
          <li
            :for={scenario <- scenarios(@exec, "negative")}
            class="mt-2 rounded border p-2"
            data-testid={"chicago-scenario-" <> scenario["id"]}
          >
            <span
              class="mr-2 rounded bg-amber-100 px-1.5 py-0.5 text-xs text-amber-800"
              data-testid={"chicago-scenario-polarity-" <> scenario["id"]}
            >
              {scenario["polarity"]}
            </span>
            <strong class="text-sm">{scenario["label"]}</strong>
            <span class="ml-1 font-mono text-xs text-slate-500">{scenario["id"]}</span>
            <p class="mt-1 text-sm">{scenario["description"]}</p>
          </li>
        </ul>
      </section>

      <section
        :if={is_map(@exec)}
        class="mb-6 rounded border p-4"
        data-testid="chicago-authority-boundaries"
      >
        <h2 class="text-lg font-bold">Authority boundaries</h2>
        <ul class="mt-2 list-disc pl-5">
          <li
            :for={{boundary, i} <- authority_boundaries(@exec)}
            class="text-sm"
            data-testid={"chicago-authority-boundary-" <> Integer.to_string(i)}
          >
            {boundary}
          </li>
        </ul>
      </section>

      <section
        :if={is_map(@exec)}
        class="mb-6 rounded border p-4"
        data-testid="chicago-evidence"
      >
        <h2 class="text-lg font-bold">Evidence</h2>
        <table class="mt-2 w-full text-sm">
          <thead>
            <tr class="text-left text-xs uppercase tracking-wide text-slate-500">
              <th class="py-1">layer</th>
              <th class="py-1">standing</th>
              <th class="py-1">receipt</th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={item <- evidence(@exec)}
              class="border-t"
              data-testid={"chicago-evidence-" <> item["layer"]}
            >
              <td class="py-1 font-mono text-xs" data-testid={"chicago-evidence-layer-" <> item["layer"]}>
                {item["layer"]}
              </td>
              <td class="py-1" data-testid={"chicago-evidence-standing-" <> item["layer"]}>
                {item["standing"]}
              </td>
              <td class="py-1" data-testid={"chicago-evidence-receipt-" <> item["layer"]}>
                {receipt_label(item["receipt"])}
              </td>
            </tr>
          </tbody>
        </table>
      </section>

      <section
        :if={is_map(@exec)}
        class="mb-6 rounded border p-4"
        data-testid="chicago-failure-recovery"
      >
        <h2 class="text-lg font-bold">Failure-recovery</h2>
        <ul class="mt-2">
          <li
            :for={recovery <- failure_recoveries(@exec)}
            class="mt-2 rounded border p-2"
            data-testid={"chicago-recovery-" <> recovery["caseId"]}
          >
            <span class="font-mono text-xs text-slate-500">{recovery["caseId"]}</span>
            <span
              class="ml-2 rounded bg-red-100 px-1.5 py-0.5 font-mono text-xs text-red-800"
              data-testid={"chicago-recovery-refusal-" <> recovery["caseId"]}
            >
              {recovery["refusal"]}
            </span>
            <p class="mt-1 text-sm">{recovery["recovery"]}</p>
          </li>
        </ul>
      </section>

      <section
        :if={is_map(@exec)}
        class="mb-6 rounded border p-4"
        data-testid="chicago-delivery-state"
      >
        <h2 class="text-lg font-bold">Delivery state</h2>
        <div class="mt-3 grid gap-3 md:grid-cols-5">
          <div class="rounded border p-3">
            <div class="text-xs uppercase tracking-wide text-slate-500">required layers</div>
            <div class="text-xl font-bold" data-testid="chicago-delivery-required-layers">
              {get_in(@exec, ["deliveryState", "requiredLayers"])}
            </div>
          </div>
          <div class="rounded border p-3">
            <div class="text-xs uppercase tracking-wide text-slate-500">demonstrated</div>
            <div class="text-xl font-bold" data-testid="chicago-delivery-demonstrated-layers">
              {get_in(@exec, ["deliveryState", "demonstratedLayers"])}
            </div>
          </div>
          <div class="rounded border p-3">
            <div class="text-xs uppercase tracking-wide text-slate-500">candidate</div>
            <div class="text-xl font-bold" data-testid="chicago-delivery-candidate-layers">
              {get_in(@exec, ["deliveryState", "candidateLayers"])}
            </div>
          </div>
          <div class="rounded border p-3">
            <div class="text-xs uppercase tracking-wide text-slate-500">successor</div>
            <div class="text-xl font-bold" data-testid="chicago-delivery-successor-layers">
              {get_in(@exec, ["deliveryState", "successorLayers"])}
            </div>
          </div>
          <div class="rounded border p-3">
            <div class="text-xs uppercase tracking-wide text-slate-500">overall standing</div>
            <div class="text-xl font-bold" data-testid="chicago-delivery-overall-standing">
              {get_in(@exec, ["deliveryState", "overallStanding"])}
            </div>
          </div>
        </div>
      </section>
    </main>
    """
  end

  ## Projection loading (R4 signatures; typed refusals only)

  defp load_executive do
    {m, f, a} = Application.get_env(:xaas, :chicago_executive_loader, @default_executive_loader)

    if function_exported?(m, f, length(a)) do
      case apply(m, f, a) do
        {:ok, exec} -> {:ok, exec}
        {:refused, reason} -> {:blocked, {:refused, reason}}
        other -> {:blocked, {:unexpected_executive_response, other}}
      end
    else
      {:blocked, :projection_api_unavailable}
    end
  end

  defp load_subject do
    {m, f, a} = Application.get_env(:xaas, :chicago_subject_loader, @default_subject_loader)

    if function_exported?(m, f, length(a)) do
      case apply(m, f, a) do
        {:ok, subject} -> subject
        subject when is_binary(subject) -> subject
        _other -> nil
      end
    else
      nil
    end
  end

  ## JSON-shaped accessors (string keys only, nil-tolerant)

  defp capabilities(exec), do: List.wrap(exec["capabilities"])
  defp digests(exec), do: Enum.with_index(List.wrap(exec["sourceDigests"]))
  defp authority_boundaries(exec), do: Enum.with_index(List.wrap(exec["authorityBoundaries"]))
  defp failure_recoveries(exec), do: List.wrap(exec["failureRecovery"])
  defp evidence(exec), do: List.wrap(exec["evidence"])

  defp scenarios(exec, polarity) do
    exec["scenarios"]
    |> List.wrap()
    |> Enum.filter(&(&1["polarity"] == polarity))
  end

  defp scenario_count(exec, polarity), do: scenarios(exec, polarity) |> length()

  defp capability_state(demonstrated_ids, cap) do
    cond do
      MapSet.member?(demonstrated_ids, cap["id"]) -> "demonstrated"
      cap["role"] == "successor" -> "successor"
      true -> "candidate"
    end
  end

  defp capability_chip_class("demonstrated"),
    do: "rounded bg-emerald-100 px-1.5 py-0.5 text-xs text-emerald-800"

  defp capability_chip_class("candidate"),
    do: "rounded bg-amber-100 px-1.5 py-0.5 text-xs text-amber-800"

  defp capability_chip_class("successor"),
    do: "rounded bg-sky-100 px-1.5 py-0.5 text-xs text-sky-800"

  defp receipt_label(%{"id" => id}), do: to_string(id)
  defp receipt_label(receipt) when is_binary(receipt), do: receipt
  defp receipt_label(nil), do: "none"
  defp receipt_label(other), do: inspect(other)
end
