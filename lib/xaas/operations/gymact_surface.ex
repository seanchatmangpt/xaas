defmodule Xaas.Operations.GymactSurface do
  @moduledoc """
  XaaS -> gymact actuation bridge (R8 gap #3, v26.10.6 convergence).

  A thin, fail-closed HTTP adapter over gymact's FastAPI surface
  (`/Users/sac/gymact/src/gymact/surfaces/fastapi.py`):

      config :xaas, :gymact_surface, base_url: "http://127.0.0.1:8000"

  with the bearer token supplied either as `token:` in the same config list
  or through the `INTERNAL_API_TOKEN` environment variable — the same
  bearer posture the `XaasWeb.Plugs.RequireInternalApiToken` plug enforces
  on the xaas side of `/internal-api`.

  Every function is gated on that configuration BEFORE any HTTP call or
  ledger transition. Unconfigured = typed refusal, never a best-effort
  default or string scraping:

      {:error, %Xaas.Actuation.Refusal{code: :gymact_not_configured}}

  Reads go straight to gymact. Consequential DO never runs as a bare proxy:
  `actuate/4` runs the external three-commit protocol the repo doctrine
  (`Xaas.Actuation`'s moduledoc, `Xaas.Castle`) prescribes for remote,
  non-rollbackable consequences —

      prepare_external (durable intent + prepared receipt)
        -> gymact HTTP DO
        -> seal_external (durable outer seal)

  — carrying a caller-supplied stable idempotency key and explicit
  authority evidence. `Xaas.Actuation.run/4` itself is deliberately not
  used for the remote DO: its own moduledoc states external consequences
  cannot lawfully pretend a Postgres rollback can undo a remote side
  effect. Local Ash consequences keyed to a gymact subject still route
  through `actuate_local/4`, a gated `Xaas.Actuation.run/4` passthrough.
  `:actuate_status` is not touched by this module.
  """

  alias Xaas.Actuation.Refusal

  @config_key :gymact_surface
  @token_env "INTERNAL_API_TOKEN"

  @type config :: %{base_url: String.t(), token: String.t()}
  @type refused :: {:error, %Refusal{}}

  ## ------------------------------------------------------------------
  ## Configuration (fail-closed)
  ## ------------------------------------------------------------------

  @doc "Resolved adapter config, or a typed `:gymact_not_configured` refusal."
  @spec config() :: {:ok, config()} | refused()
  def config do
    case Application.get_env(:xaas, @config_key) do
      opts when is_list(opts) ->
        with {:ok, base_url} <- require_binary(opts, :base_url),
             {:ok, token} <- token(opts) do
          {:ok, %{base_url: String.trim_trailing(base_url, "/"), token: token}}
        end

      _other ->
        {:error, refusal()}
    end
  end

  @doc "GET /health — the cheapest liveness read over the real surface."
  @spec health() :: {:ok, map()} | {:error, term()}
  def health do
    with {:ok, cfg} <- config() do
      get(cfg, "/health")
    end
  end

  @doc "GET /providers — the runtime's discovered environments."
  @spec providers() :: {:ok, map()} | {:error, term()}
  def providers do
    with {:ok, cfg} <- config() do
      get(cfg, "/providers")
    end
  end

  @doc """
  POST /candidates — normalize a REST candidate-intent envelope into
  gymact's transport-independent semantic key (a powerless candidate; no
  authority participates).
  """
  @spec prepare_candidate(map()) :: {:ok, map()} | {:error, term()}
  def prepare_candidate(payload) when is_map(payload) do
    with {:ok, cfg} <- config() do
      post(cfg, "/candidates", payload)
    end
  end

  @doc """
  POST /episodes — materialize one bounded episode (memory provider used in
  tests: `%{provider: "memory", config: %{initial: %{...}, requires_authority: false}}`).
  """
  @spec open_episode(map()) :: {:ok, map()} | {:error, term()}
  def open_episode(params) when is_map(params) do
    with {:ok, cfg} <- config() do
      post(cfg, "/episodes", params)
    end
  end

  @doc "GET /episodes/:id/capabilities"
  @spec capabilities(String.t()) :: {:ok, map()} | {:error, term()}
  def capabilities(episode_id) when is_binary(episode_id) do
    with {:ok, cfg} <- config() do
      get(cfg, "/episodes/" <> URI.encode_www_form(episode_id) <> "/capabilities")
    end
  end

  @doc """
  POST /episodes/:id/actions/selected — the canonical gymact DO port. The
  payload is an opaque court-manufactured combinatorial cut
  (`gymact.cut.CombinatorialBrokerRequest`; every digest is computed and
  re-checked by gymact itself). This adapter never recomputes or forges cut
  digests and never mints authority — no string scraping.
  """
  @spec submit_action(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def submit_action(episode_id, cut) when is_binary(episode_id) and is_map(cut) do
    with {:ok, cfg} <- config() do
      post(cfg, "/episodes/" <> URI.encode_www_form(episode_id) <> "/actions/selected", cut)
    end
  end

  @doc """
  POST /episodes/:id/verify — an independent predicate over observed state;
  `expected` is the partial state the episode must match.
  """
  @spec verify(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def verify(episode_id, expected) when is_binary(episode_id) and is_map(expected) do
    with {:ok, cfg} <- config() do
      post(cfg, "/episodes/" <> URI.encode_www_form(episode_id) <> "/verify", %{
        expected: expected
      })
    end
  end

  ## ------------------------------------------------------------------
  ## Actuation-style mutations
  ## ------------------------------------------------------------------

  @doc """
  Consequential gymact DO behind the actuation ledger. `resource`, `action`,
  and `input` are the caller's admitted Ash surface; opts require
  `:idempotency_key`, and — for the actual DO — `:episode_id` and `:cut`
  (the court-manufactured gymact cut). With the default `authorize?: false`
  external posture a non-empty `:authority` map is required by the kernel.
  The typed `:gymact_not_configured` refusal fires BEFORE any ledger or
  HTTP transition. After prepare, a missing/empty `:episode_id` or `:cut`
  is a typed `:episode_id_required` / `:cut_required` refusal that IS
  durably sealed as `:refused`; a non-2xx or transport remote failure is
  durably sealed as `:failed` with a json-safe error map
  (`%{class: :gymact_http_error | :gymact_transport_error, ...}`) — the
  ledger always learns the outcome (W674-GAP-1/GAP-2).
  """
  @spec actuate(module(), atom(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def actuate(resource, action, input, opts)
      when is_atom(resource) and is_atom(action) and is_map(input) do
    with {:ok, _cfg} <- config() do
      case prepare_ledger(resource, action, input, opts) do
        {:ok, %{status: :replayed} = replay} ->
          {:ok, Map.drop(replay, [:admission])}

        {:ok, %{status: :prepared, admission: admission}} ->
          do_and_seal(admission, opts)

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Gated `Xaas.Actuation.run/4` passthrough for LOCAL Ash consequences keyed
  to a gymact subject. Same fail-closed config gate; `Xaas.Actuation.run/4`'s
  idempotency-key requirement applies unchanged (`{:error,
  :idempotency_key_required}` without one).
  """
  @spec actuate_local(module(), atom(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def actuate_local(resource, action, input, opts) do
    with {:ok, _cfg} <- config() do
      Xaas.Actuation.run(resource, action, input, opts)
    end
  end

  ## ------------------------------------------------------------------
  ## Internals
  ## ------------------------------------------------------------------

  defp prepare_ledger(resource, action, input, opts) do
    idempotency_key =
      case Keyword.fetch(opts, :idempotency_key) do
        {:ok, key} when is_binary(key) and key != "" -> key
        _ -> raise KeyError, key: :idempotency_key, term: opts
      end

    Xaas.Actuation.prepare_external(resource, action, input,
      idempotency_key: idempotency_key,
      subject_id: Keyword.get(opts, :subject_id),
      actor: Keyword.get(opts, :actor),
      tenant: Keyword.get(opts, :tenant),
      authorize?: Keyword.get(opts, :authorize?, false),
      authority: Keyword.get(opts, :authority, %{})
    )
  rescue
    KeyError -> {:error, :idempotency_key_required}
  end

  # Sealed DO failure classes. The ledger's `ActuationReceipt.error` is a
  # `:map` attribute, so every sealed error is a json-safe map (a raw
  # `{:gymact_http_error, status, body}` tuple renders as a LIST under
  # `Xaas.Actuation`'s `json_safe/1` and the `:seal` action rejects it —
  # W674-GAP-1).
  defp do_and_seal(admission, opts) do
    result =
      with {:ok, episode_id} <- external_opt(opts, :episode_id),
           {:ok, cut} <- external_opt(opts, :cut),
           {:ok, body} <- submit_action(episode_id, cut) do
        {:ok, body}
      else
        {:error, %Refusal{}} = sealed_refusal ->
          # Typed refusal (e.g. missing :episode_id/:cut) — `Kernel.seal`
          # classifies a `Xaas.Actuation.Refusal` as a durable `:refused`.
          sealed_refusal

        {:error, {:gymact_http_error, status, body}} ->
          {:error, %{class: :gymact_http_error, status: status, body: json_safe(body)}}

        {:error, {:gymact_transport_error, exception}} ->
          {:error, %{
            class: :gymact_transport_error,
            message: exception |> Exception.message() |> json_safe()
          }}
      end

    Xaas.Actuation.seal_external(admission, result)
  end

  # A missing required external-DO opt is a typed refusal (W674-GAP-2),
  # not a raw `WithClauseError` from `Keyword.fetch/2`.
  defp external_opt(opts, :episode_id) do
    case Keyword.fetch(opts, :episode_id) do
      {:ok, id} when is_binary(id) and id != "" -> {:ok, id}
      _ -> {:error, Refusal.new(:episode_id_required, %{opt: :episode_id})}
    end
  end

  defp external_opt(opts, :cut) do
    case Keyword.fetch(opts, :cut) do
      {:ok, cut} when is_map(cut) -> {:ok, cut}
      _ -> {:error, Refusal.new(:cut_required, %{opt: :cut})}
    end
  end

  defp json_safe(%_{} = struct), do: Map.delete(Map.from_struct(struct), :__struct__)

  defp json_safe(map) when is_map(map),
    do: Map.new(map, fn {k, v} -> {to_string(k), json_safe(v)} end)

  defp json_safe(list) when is_list(list), do: Enum.map(list, &json_safe/1)

  defp json_safe(atom) when is_atom(atom), do: Atom.to_string(atom)

  defp json_safe(value), do: value

  defp token(opts) do
    case Keyword.get(opts, :token) || System.get_env(@token_env) do
      token when is_binary(token) and token != "" -> {:ok, token}
      _ -> {:error, refusal()}
    end
  end

  defp require_binary(opts, key) do
    case Keyword.get(opts, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, refusal()}
    end
  end

  defp refusal, do: Refusal.new(:gymact_not_configured, %{config_key: @config_key})

  defp get(cfg, path), do: request(cfg, :get, path)

  defp post(cfg, path, payload), do: request(cfg, :post, path, payload)

  defp request(cfg, method, path, payload \\ :no_body) do
    url = cfg.base_url <> path

    opts =
      [
        method: method,
        url: url,
        headers: [
          {"authorization", "Bearer " <> cfg.token},
          {"accept", "application/json"}
        ],
        retry: false,
        receive_timeout: 15_000
      ]
      |> maybe_json(method, payload)

    case Req.request(opts) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:gymact_http_error, status, body}}

      {:error, exception} ->
        {:error, {:gymact_transport_error, exception}}
    end
  end

  defp maybe_json(opts, :get, _), do: opts

  defp maybe_json(opts, _method, payload) when is_map(payload),
    do: Keyword.put(opts, :json, payload)

  defp maybe_json(opts, _method, _), do: opts
end
