defmodule XaasWeb.ExecutionFabricController do
  @moduledoc """
  HTTP surface of the provider-pull execution fabric, under `/internal-api`
  and its Bearer-token gate (`RequireInternalApiToken`, fail-closed).

  This controller owns no state and no resources: it is a thin transport
  projection onto the existing Ultracode seam — `Xaas.Ultracode.Lease`
  (claim/admit/close/refuse over `Run`/`Epoch`/`Receipt`). Two shapes:

    * `POST /internal-api/execution/hooks/:event` — plain JSON consumed by
      the generated provider plugin's hook scripts. A `pre_tool_use`
      refusal is HTTP 403 with a typed reason; the hook script converts
      any non-allow into the provider's blocking exit code, and converts
      its own transport failure to an explicit deny (BRCE_UNAVAILABLE).

    * `POST /internal-api/execution/mcp` — a stateless MCP JSON-RPC 2.0
      endpoint exposing claim_next / heartbeat / admit_tool /
      record_provider_event / close_candidate / refuse / actuate to the
      provider's MCP client. `actuate` is the ZCode-UI-as-actuator seam: it
      forwards a REGISTERED `{resource, action}` pair straight to
      `Xaas.Ultracode.Lease.actuate/2` (see that function's docs), the only
      way a provider worker crosses into the admitted `Xaas.Actuation.run/4`
      DO kernel — a wholly separate, narrower surface from `admit_tool`'s
      own construction/consequence fence, which this does not touch.

    * `GET /internal-api/execution/epochs/:epoch_id/receipts` — the real
      lawful read path onto `Xaas.Ultracode.Receipt` (see that resource's
      moduledoc): every sealed Receipt for one Epoch, scoped by the
      required `epoch_id` path param and gated by the same Bearer token
      as every other route in this controller. Added to close a real gap:
      Receipt previously had no production-reachable read path at all.
      Real, this pass: org-scoped to a real 404 (never a leaking 403) when
      the caller authenticated via an org-carrying token and the epoch's
      run belongs to a different org (or none) -- see `receipts/2` below.
      Unchanged for the legacy shared-token / org-less DB-token tiers.

    * `POST /internal-api/execution/runs` — real customer-facing
      submission surface (this pass): creates a Run + its first, already
      `:running` Epoch (cycle 0) directly from the AUTHENTICATED org
      `XaasWeb.Plugs.RequireInternalApiToken` resolved onto
      `conn.assigns[:current_org]` -- never from any request body/header
      field a client could set. A caller authenticated only via the legacy
      shared token, or a DB token with no `org_id`, gets a real, typed 403
      (`org_scoped_token_required`), never a silently org-less Run. See
      `create_run/2` below.
  """

  use XaasWeb, :controller

  require Logger

  alias Xaas.Accounts.Org
  alias Xaas.Ultracode.{Epoch, Lease, Receipt, Run}

  @mcp_tools [
    %{
      name: "claim_next",
      description:
        "Claim the oldest lease-free running epoch of a provider-pull run. " <>
          "Returns the work payload (run goal + exact subject + the name of the fabric verifier suite " <>
          "that will independently judge the closed head, if any) and the lease token.",
      inputSchema: %{
        type: "object",
        properties: %{
          provider: %{type: "string"},
          provider_worker_id: %{type: "string"},
          epoch_id: %{
            type: "string",
            description:
              "Optional: claim exactly this epoch (it must still be a ready epoch of this provider) " <>
                "instead of the oldest ready one."
          }
        },
        required: ["provider"]
      }
    },
    %{
      name: "heartbeat",
      description: "Renew the lease held by this lease_token.",
      inputSchema: %{
        type: "object",
        properties: %{lease_token: %{type: "string"}},
        required: ["lease_token"]
      }
    },
    %{
      name: "admit_tool",
      description:
        "Per-consequence admission court for one proposed tool invocation. Refusal is a fence.",
      inputSchema: %{
        type: "object",
        properties: %{lease_token: %{type: "string"}, tool: %{type: "string"}},
        required: ["lease_token", "tool"]
      }
    },
    %{
      name: "record_provider_event",
      description: "Record a provider-observed event. Observation, never subject success.",
      inputSchema: %{
        type: "object",
        properties: %{lease_token: %{type: "string"}, event: %{type: "object"}},
        required: ["lease_token", "event"]
      }
    },
    %{
      name: "close_candidate",
      description:
        "Close the leased epoch with head-verified evidence and seal the Receipt. " <>
          "Provider stop never implies closure.",
      inputSchema: %{
        type: "object",
        properties: %{
          lease_token: %{type: "string"},
          final_head: %{type: "string"},
          outcome: %{type: "string"},
          evidence: %{type: "object"}
        },
        required: ["lease_token", "final_head", "outcome"]
      }
    },
    %{
      name: "refuse",
      description: "Refuse the leased work with a typed reason.",
      inputSchema: %{
        type: "object",
        properties: %{lease_token: %{type: "string"}, reason: %{type: "string"}},
        required: ["lease_token", "reason"]
      }
    },
    %{
      name: "actuate",
      description:
        "Invoke the admitted Ash.Reactor DO kernel (Xaas.Actuation.run/4) for one " <>
          "REGISTERED {resource, action} pair under this lease's own provider registry. " <>
          "A wholly separate, narrower surface from admit_tool's construction/consequence " <>
          "fence -- Bash/git_push/publish remain refused there, unchanged. An unregistered " <>
          "pair is refused; authority evidence is always attached here and bound to this " <>
          "lease, never an empty/delegated authority map. There is no subject_id argument " <>
          "on purpose -- the registered pair's own config decides which subject (or none) " <>
          "it may act on, never the caller.",
      inputSchema: %{
        type: "object",
        properties: %{
          lease_token: %{type: "string"},
          resource: %{type: "string"},
          action: %{type: "string"},
          input: %{type: "object"},
          idempotency_key: %{type: "string"}
        },
        required: ["lease_token", "resource", "action", "idempotency_key"]
      }
    }
  ]

  @valid_outcomes ~w(alive partial_alive blocked build_broken unsupported refused)

  # ------------------------------------------------------------------
  # Hook surface (plain JSON)
  # ------------------------------------------------------------------

  def hook(%{method: "POST"} = conn, %{"event" => event}) do
    with {:ok, body, conn} <- read_json(conn) do
      handle_hook(conn, event, body)
    end
  end

  defp handle_hook(conn, "session_start", body) do
    # No worker registry exists by design: worker identity is free-form and
    # travels with the claim. Session start is acknowledged for hook-protocol
    # symmetry and observed via telemetry only.
    :telemetry.execute(
      [:xaas, :ultracode, :provider_session],
      %{},
      %{provider: body["provider"] || "zcode", session_id: body["session_id"], cwd: body["cwd"]}
    )

    json(conn, %{status: "acknowledged"})
  end

  defp handle_hook(conn, "pre_tool_use", body) do
    case lease_token(body) do
      nil ->
        refused(conn, 403, :no_lease)

      token ->
        case Lease.admit_tool(token, body["tool"] || "") do
          {:ok, %{decision: :allow} = allow} ->
            json(conn, Map.new(allow, fn {k, v} -> {to_string(k), v} end))

          {:error, reason} ->
            refused(conn, 403, reason)
        end
    end
  end

  defp handle_hook(conn, event, body)
       when event in ~w(user_prompt_submit post_tool_use post_tool_use_failure) do
    case lease_token(body) do
      nil ->
        refused(conn, 422, :no_lease)

      token ->
        case Lease.record_provider_event(token, %{
               hook: event,
               tool: body["tool"],
               tool_use_id: body["tool_use_id"],
               cwd: body["cwd"],
               session_id: body["session_id"]
             }) do
          :ok -> json(conn, %{status: "recorded"})
          {:error, reason} -> refused(conn, 422, reason)
        end
    end
  end

  defp handle_hook(conn, "stop", body) do
    case lease_token(body) do
      nil ->
        json(conn, %{status: "not_closeable", reason: "no_lease"})

      token ->
        case Lease.close(
               token,
               body["final_head"] || "",
               outcome(body["standing"]),
               body["evidence"] || %{}
             ) do
          {:ok, epoch, receipt} ->
            json(conn, %{
              status: "closed",
              epoch_id: epoch.id,
              outcome: receipt.outcome
            })

          {:error, reason} ->
            # Stop without a closeable lease is observed, not fatal: the
            # lease expires on its own; the provider must not treat this
            # as closure.
            Logger.warning("XAAS_STOP_WITHOUT_CLOSE reason=#{inspect(reason)}")
            json(conn, %{status: "not_closeable", reason: inspect(reason)})
        end
    end
  end

  defp handle_hook(conn, unknown_event, _body) do
    refused(conn, 404, {:unknown_hook_event, unknown_event})
  end

  # ------------------------------------------------------------------
  # MCP surface (stateless JSON-RPC 2.0)
  # ------------------------------------------------------------------

  def mcp(%{method: "POST"} = conn, _params) do
    with {:ok, body, conn} <- read_json(conn),
         {:ok, response} <- rpc(body) do
      json(conn, response)
    else
      {:error, %{} = rpc_error} ->
        json(conn, rpc_error)

      {:error, reason} ->
        conn
        |> put_status(400)
        |> json(%{error: "bad_request", detail: inspect(reason)})
    end
  end

  defp rpc(%{"id" => id, "method" => "initialize"}) do
    {:ok,
     %{
       jsonrpc: "2.0",
       id: id,
       result: %{
         protocolVersion: "2025-03-26",
         capabilities: %{tools: %{}},
         serverInfo: %{name: "xaas-ultracode-lease", version: "1.0.0"}
       }
     }}
  end

  defp rpc(%{"id" => id, "method" => "tools/list"}) do
    {:ok, %{jsonrpc: "2.0", id: id, result: %{tools: @mcp_tools}}}
  end

  defp rpc(%{"id" => id, "method" => "tools/call", "params" => %{"name" => name} = params}) do
    case dispatch_tool(name, Map.get(params, "arguments", %{})) do
      {:ok, result} ->
        {:ok,
         %{
           jsonrpc: "2.0",
           id: id,
           result: %{content: [%{type: "text", text: Jason.encode!(result)}]}
         }}

      {:error, reason} ->
        # Tool-level refusal is a JSON-RPC tool error carrying the typed
        # reason — never a silent success.
        {:ok,
         %{
           jsonrpc: "2.0",
           id: id,
           result: %{
             isError: true,
             content: [%{type: "text", text: Jason.encode!(%{error: format_reason(reason)})}]
           }
         }}
    end
  end

  defp rpc(%{"id" => id, "method" => method}) do
    {:error,
     %{jsonrpc: "2.0", id: id, error: %{code: -32_601, message: "method not found: #{method}"}}}
  end

  defp rpc(%{"method" => "notifications/" <> _}), do: {:ok, :notification}

  defp rpc(_), do: {:error, :invalid_request}

  # A directed claim needs a well-formed UUID. A malformed one is a typed
  # refusal -- never a silent fallback to oldest-first, which would bind the
  # worker to an epoch it did not ask for.
  defp claim_opts(%{"epoch_id" => id}) do
    case is_binary(id) && Ecto.UUID.cast(id) do
      {:ok, uuid} -> {:ok, [epoch_id: uuid]}
      _ -> {:error, :invalid_epoch_id}
    end
  end

  defp claim_opts(_args), do: {:ok, []}

  defp dispatch_tool("claim_next", args) do
    with {:ok, opts} <- claim_opts(args),
         {:ok, epoch, token, run} <-
           Lease.claim_next(args["provider"] || "zcode", args["provider_worker_id"], opts) do
      {:ok,
       %{
         lease_token: token,
         lease_expires_at: epoch.lease_expires_at,
         epoch_id: epoch.id,
         cycle: epoch.cycle,
         exact_subject: epoch.exact_subject,
         goal: run.goal,
         worktree: epoch.worktree,
         verifier_suite: run.verifier_suite
       }}
    end
  end

  defp dispatch_tool("heartbeat", %{"lease_token" => token}) do
    with :ok <- Lease.renew(token), do: {:ok, %{status: "renewed"}}
  end

  defp dispatch_tool("heartbeat", _), do: {:error, :lease_token_required}

  defp dispatch_tool("admit_tool", %{"lease_token" => token, "tool" => tool}) do
    Lease.admit_tool(token, tool)
  end

  defp dispatch_tool("admit_tool", _), do: {:error, :lease_token_and_tool_required}

  defp dispatch_tool("record_provider_event", %{"lease_token" => token, "event" => event}) do
    with :ok <- Lease.record_provider_event(token, event), do: {:ok, %{status: "recorded"}}
  end

  defp dispatch_tool("record_provider_event", _), do: {:error, :lease_token_and_event_required}

  defp dispatch_tool("close_candidate", %{"lease_token" => token, "final_head" => head} = args) do
    case Lease.close(token, head, outcome(args["outcome"]), args["evidence"] || %{}) do
      {:ok, epoch, receipt} ->
        {:ok, %{status: "closed", epoch_id: epoch.id, outcome: receipt.outcome}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp dispatch_tool("close_candidate", _), do: {:error, :lease_token_and_head_required}

  defp dispatch_tool("refuse", %{"lease_token" => token, "reason" => reason}) do
    case Lease.refuse(token, reason_atom(reason)) do
      {:ok, epoch, receipt} ->
        {:ok, %{status: "refused", epoch_id: epoch.id, outcome: receipt.outcome}}

      {:error, err} ->
        {:error, err}
    end
  end

  defp dispatch_tool("refuse", _), do: {:error, :lease_token_and_reason_required}

  defp dispatch_tool("actuate", %{"lease_token" => token} = args) when is_binary(token) do
    case Lease.actuate(token, args) do
      {:ok, envelope} -> {:ok, format_actuation(envelope)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch_tool("actuate", _), do: {:error, :lease_token_required}

  defp dispatch_tool(other, _), do: {:error, {:unknown_tool, other}}

  # ------------------------------------------------------------------
  # Customer-facing submission surface (real, this pass — see moduledoc)
  # ------------------------------------------------------------------

  def create_run(%{method: "POST"} = conn, params) do
    case conn.assigns[:current_org] do
      %Org{} = org -> do_create_run(conn, org, params)
      _ -> org_scoped_token_required(conn)
    end
  end

  # `org_id` is set from the AUTHENTICATED `org` this function was handed
  # by `create_run/2` (itself sourced only from `conn.assigns[:current_org]`,
  # which `XaasWeb.Plugs.RequireInternalApiToken` derives from the verified
  # bearer token) — never from `params`, which is untrusted client input.
  #
  # Real, evidence-found fix (2026-09 fs-safety hardening pass): the Run
  # and Epoch creates below used to be two independent, unwrapped
  # `Ash.create/1` calls -- a real `mix test` run against the new
  # `WorktreeIsSafe` validation caught this live: a rejected worktree
  # left a real, orphaned `:pending` Run row behind with no Epoch,
  # because the Run had already committed before the Epoch create
  # failed. Wrapped in one real data-layer transaction, this repo's own
  # established pattern for "multiple Ash creates, one all-or-nothing
  # unit" (`Xaas.Actuation.run/4`'s `Ash.DataLayer.transaction/5` +
  # `Ash.DataLayer.rollback/2`), not a new mechanism.
  defp do_create_run(conn, %Org{} = org, params) do
    goal = params["goal"]
    worktree = params["worktree"]
    provider = params["provider"] || "zcode"
    verifier_suite = params["verifier_suite"]
    resources = [Run, Epoch]

    transaction_result =
      Ash.DataLayer.transaction(
        resources,
        fn ->
          with {:ok, run} <- create_run_row(goal, provider, org.id, verifier_suite),
               exact_subject = params["exact_subject"] || default_exact_subject(org, run),
               {:ok, epoch} <- create_running_epoch(run, exact_subject, worktree) do
            {run, epoch}
          else
            {:error, reason} -> Ash.DataLayer.rollback(resources, reason)
          end
        end,
        nil,
        %{type: :custom, metadata: %{operation: :xaas_execution_fabric_create_run}}
      )

    case transaction_result do
      {:ok, {run, epoch}} ->
        conn
        |> put_status(201)
        |> json(%{run_id: run.id, epoch_id: epoch.id})

      {:error, reason} ->
        create_run_error(conn, reason)
    end
  end

  # Real per-org quota (2026-09 fs-safety hardening pass -- see
  # `Xaas.Ultracode.Run`'s own `rate_limit do` block): a genuine 429, not
  # a generic 400, distinguishing "your submission was malformed" from
  # "your submission was fine, submit fewer of them" -- the correct HTTP
  # semantics for a rate limit, and real evidence a caller-facing client
  # can branch on (retry-after semantics) rather than treating both cases
  # identically.
  defp create_run_error(conn, reason) do
    if rate_limited?(reason) do
      conn
      |> put_status(429)
      |> json(%{error: "rate_limited", detail: "too many run submissions for this org"})
    else
      conn
      |> put_status(400)
      |> json(%{error: "invalid_request", detail: format_reason(reason)})
    end
  end

  # Real, evidence-corrected match -- twice over, both caught by re-running
  # the real check after implementing rather than assumed correct:
  #
  # 1. `AshRateLimiter.LimitExceeded` is `class: :forbidden`
  #    (deps/ash_rate_limiter/lib/ash_rate_limiter/limit_exceeded.ex), so a
  #    rate-limited `:submit` call surfaces wrapped in
  #    `%Ash.Error.Forbidden{}`, NOT `%Ash.Error.Invalid{}` -- matching only
  #    `Invalid` (the first draft) silently fell through to a generic 400.
  # 2. Once `do_create_run/3` below was wrapped in one
  #    `Ash.DataLayer.transaction/5` (fixing the orphaned-Run bug the
  #    `WorktreeIsSafe` fix exposed -- see that function's own comment), a
  #    live `mix test` run showed `Ash.create/1`'s error, called from
  #    INSIDE an already-open data-layer transaction, comes back as the
  #    raw `%Ash.Changeset{errors: [...]}` instead of either wrapper above
  #    -- Ash defers the final `Ash.Error` wrapping to the transaction
  #    owner in that shape. All three are handled the same way: unwrap to
  #    the real `errors` list and check each one.
  defp rate_limited?(%Ash.Error.Invalid{errors: errors}), do: Enum.any?(errors, &rate_limited?/1)

  defp rate_limited?(%Ash.Error.Forbidden{errors: errors}),
    do: Enum.any?(errors, &rate_limited?/1)

  defp rate_limited?(%Ash.Changeset{errors: errors}), do: Enum.any?(errors, &rate_limited?/1)

  defp rate_limited?(%AshRateLimiter.LimitExceeded{}), do: true
  defp rate_limited?(_), do: false

  # `verifier_suite` is a NAME the operator registered
  # (`Xaas.Ultracode.Verifier`); `VerifierSuiteRegistered` turns an unknown
  # name into a typed 400, and a suite only ever executes in a worktree under
  # the operator containment root, so naming one grants no execution reach.
  defp create_run_row(goal, provider, org_id, verifier_suite) do
    Run
    |> Ash.Changeset.for_create(
      :submit,
      %{goal: goal, provider: provider, org_id: org_id, verifier_suite: verifier_suite},
      authorize?: false
    )
    |> Ash.create()
  end

  # Cycle 0, state :running directly (not via Run.:start/CreateFirstEpoch,
  # which produces a :expected epoch) -- same shape this controller's own
  # test suite already relies on (provider_run_and_epoch/2 in
  # execution_fabric_controller_test.exs), so a run submitted here is
  # immediately claim_next-visible to a provider worker.
  defp create_running_epoch(run, exact_subject, worktree) do
    Epoch
    |> Ash.Changeset.for_create(
      :create,
      %{
        run_id: run.id,
        # Denormalized from the just-created Run -- see Epoch's own
        # moduledoc "Org scoping" section. This is the real value
        # `receipts_for_org/3` below filters on at the query layer.
        org_id: run.org_id,
        cycle: 0,
        exact_subject: exact_subject,
        state: :running,
        started_at: DateTime.utc_now(),
        worktree: worktree
      },
      authorize?: false
    )
    |> Ash.create()
  end

  defp default_exact_subject(%Org{slug: slug}, %Run{id: run_id}),
    do: "org:#{slug}-run:#{run_id}"

  defp org_scoped_token_required(conn) do
    conn
    |> put_status(403)
    |> json(%{error: "org_scoped_token_required"})
  end

  # ------------------------------------------------------------------
  # Receipt read surface (real lawful read path — see
  # Xaas.Ultracode.Receipt's moduledoc + its `:for_epoch` read action)
  # ------------------------------------------------------------------

  def receipts(%{method: "GET"} = conn, %{"epoch_id" => epoch_id}) do
    case conn.assigns[:current_org] do
      %Org{} = org -> receipts_for_org(conn, epoch_id, org)
      _ -> receipts_unscoped(conn, epoch_id)
    end
  end

  # Unchanged from before this pass -- the legacy shared-token / org-less
  # DB-token tiers keep exactly this behavior (real regression floor per
  # this pass's own instructions).
  defp receipts_unscoped(conn, epoch_id) do
    case Receipt.for_epoch(epoch_id) do
      {:ok, receipts} ->
        json(conn, %{
          epoch_id: epoch_id,
          receipts: Enum.map(receipts, &format_receipt/1)
        })

      {:error, reason} ->
        conn
        |> put_status(400)
        |> json(%{error: "invalid_epoch_id", detail: format_reason(reason)})
    end
  end

  # Real org scoping (this pass): only reachable when the caller
  # authenticated via an org-carrying token. QUERY-LAYER enforced (real
  # multitenancy retrofit, see `Xaas.Ultracode.Run`/`Epoch`'s own
  # moduledocs) -- `tenant: org_id` on Epoch's own `:enforce`d default
  # `:read` action applies a real `org_id == ^org_id` filter before the row
  # ever reaches this function, not a manual comparison after an unscoped
  # fetch. A real 404 (never a 403, which would leak that the epoch
  # exists) for an epoch whose own `org_id` doesn't match this token's org
  # (a different org's epoch, or one with no org_id at all) -- org-less
  # epochs stay admin/internal-tier only, never visible to a customer
  # token.
  defp receipts_for_org(conn, epoch_id, %Org{id: org_id}) do
    case Ash.get(Epoch, epoch_id, tenant: org_id, authorize?: false) do
      {:ok, %Epoch{}} ->
        receipts_unscoped(conn, epoch_id)

      {:error, %Ash.Error.Invalid{errors: errors}} ->
        if Enum.any?(errors, &match?(%Ash.Error.Query.NotFound{}, &1)) do
          epoch_not_found(conn, epoch_id)
        else
          # Syntactically invalid epoch id -- preserve the same 400
          # contract as the unscoped path (Receipt.for_epoch re-validates
          # and produces the identical "invalid_epoch_id" response).
          receipts_unscoped(conn, epoch_id)
        end

      {:error, _not_found} ->
        epoch_not_found(conn, epoch_id)
    end
  end

  defp epoch_not_found(conn, epoch_id) do
    conn
    |> put_status(404)
    |> json(%{error: "epoch_not_found", detail: "no accessible epoch #{inspect(epoch_id)}"})
  end

  # Shapes an `Xaas.Actuation.run/4` envelope for the wire. `envelope.result`
  # is the LIVE resource struct on purpose (actuation_test.exs's replay-
  # regression coverage) -- not JSON-safe, so the transport uses
  # `receipt.result` instead, the already-`json_safe/1`-processed snapshot
  # `Xaas.Actuation.Kernel.seal/2` persisted.
  defp format_actuation(envelope) do
    %{
      status: Atom.to_string(envelope.status),
      replay: envelope.replay?,
      intent_id: envelope.intent.id,
      receipt_id: envelope.receipt.id,
      result: envelope.receipt.result
    }
  end

  defp format_receipt(%Receipt{} = receipt) do
    %{
      id: receipt.id,
      epoch_id: receipt.epoch_id,
      subject: receipt.subject,
      outcome: receipt.outcome,
      evidence: receipt.evidence,
      sealed_at: receipt.sealed_at
    }
  end

  # ------------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------------

  # Plug.Parsers at the endpoint has already read and decoded JSON bodies
  # by the time the controller runs — read_body would see an empty stream.
  # Prefer the parsed body_params; fall back to a raw read only when the
  # parser did not fetch them.
  defp read_json(%{body_params: %Plug.Conn.Unfetched{}} = conn), do: read_json_raw(conn)

  defp read_json(%{body_params: params} = conn) when is_map(params), do: {:ok, params, conn}

  defp read_json(conn), do: read_json_raw(conn)

  defp read_json_raw(conn) do
    case Plug.Conn.read_body(conn, length: 1_000_000) do
      {:ok, raw, conn} ->
        case Jason.decode(raw) do
          {:ok, body} when is_map(body) -> {:ok, body, conn}
          _ -> {:error, :invalid_json}
        end

      {:more, _, _} ->
        {:error, :body_too_large}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # The hook payload's lease key varies across provider builds; the
  # transport normalizes it and NEVER invents a token.
  defp lease_token(body) do
    case body["lease_token"] do
      token when is_binary(token) and token != "" -> token
      _ -> nil
    end
  end

  # Case-insensitive on purpose: providers report standing in the documented
  # vocabulary's natural casing ("ALIVE"); normalize before matching so an
  # honest ALIVE is never silently downgraded to partial_alive.
  defp outcome(outcome) when is_binary(outcome) do
    case String.downcase(outcome) do
      o when o in @valid_outcomes -> String.to_atom(o)
      _ -> :partial_alive
    end
  end

  # `String.to_existing_atom/1`, not `String.to_atom/1`: `reason` is
  # attacker-controlled MCP input (the `refuse` tool's free-text argument).
  # BEAM atoms are never garbage-collected, so unconditionally interning an
  # unbounded caller-supplied string is an atom-table exhaustion DoS against
  # the whole node. Any legitimate refusal reason already exists as an atom
  # somewhere in this codebase (compiled module/pattern-match literals), so
  # restricting to existing atoms costs nothing for real callers and refuses
  # only fabricated reason strings, which fall back to :unknown.
  defp reason_atom(reason) do
    case reason do
      nil -> :unknown
      binary when is_binary(binary) -> safe_existing_atom(binary)
      other -> other
    end
  end

  defp safe_existing_atom(binary) do
    String.to_existing_atom(binary)
  rescue
    ArgumentError -> :unknown
  end

  defp refused(conn, status, reason) do
    conn
    |> put_status(status)
    |> json(%{decision: "deny", reason: format_reason(reason)})
  end

  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason({tag, detail}) when is_atom(tag), do: "#{tag}:#{inspect(detail)}"

  # Real, typed extraction for the common Ash validation-failure shape
  # (`Xaas.Ultracode.Validations.WorktreeIsSafe`, `Run.goal`'s
  # `max_length` constraint, ...): surfaces the actual `field`/`message`
  # instead of a giant `inspect/1` blob of the whole %Ash.Error.Invalid{}
  # struct, so a 400 caller sees e.g. `"worktree: worktree_traversal"`
  # rather than opaque internals.
  defp format_reason(%Ash.Error.Invalid{errors: [%{field: field, message: message} | _]})
       when not is_nil(field) do
    "#{field}: #{message}"
  end

  # Same real shape, unwrapped from a raw `%Ash.Changeset{}` -- see
  # `rate_limited?/1`'s own comment on why an action's error surfaces this
  # way when called from inside an already-open data-layer transaction
  # (`do_create_run/3`'s `Ash.DataLayer.transaction/5`).
  defp format_reason(%Ash.Changeset{errors: [%{field: field, message: message} | _]})
       when not is_nil(field) do
    "#{field}: #{message}"
  end

  defp format_reason(reason), do: inspect(reason)
end
