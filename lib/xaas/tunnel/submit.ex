defmodule Xaas.Tunnel.Submit do
  @moduledoc """
  Run + first-Epoch submission shared by `XaasWeb.ExecutionFabricController`
  (`POST /internal-api/execution/runs`) and `XaasWeb.FabricController`
  (`POST /internal-api/fabric/runs`).

  `create/2` is the Run/Epoch transaction extracted verbatim from the execution
  controller: one `Ash.DataLayer.transaction/5`, cycle 0, state `:running`,
  `org_id` only ever from the authenticated org.

  `submit/2` adds idempotency without a migration: the Epoch's `exact_subject`
  is `"fabric:<org slug>:<idempotency_key>"`. Inside the transaction a
  `pg_advisory_xact_lock` keyed on `(org id, key)` serializes concurrent
  submits of one key; the Epoch `(org_id, exact_subject, cycle 0)` is looked up
  first and, if present, returned with `replay?: true` instead of creating a
  second Run. The key identity is temporary: a real Run idempotency column
  (migration) supersedes it.

  HANDWRITTEN.md: UNSUPPORTED(generator-capability) -- no admitted pack renders
  an idempotent submission transaction over the Ultracode seam.
  """

  require Ash.Query

  alias Xaas.Accounts.Org
  alias Xaas.Ultracode.{Epoch, Run}

  @key ~r/^[A-Za-z0-9._:-]{1,128}$/

  @type result ::
          {:ok, %{run: Run.t(), epoch: Epoch.t(), replay?: boolean()}} | {:error, term()}

  @doc "Idempotency key validity (same rule as the chatgpt-cloud client)."
  @spec valid_key?(term()) :: boolean()
  def valid_key?(key), do: is_binary(key) and Regex.match?(@key, key)

  @doc "The exact subject an idempotency key binds to, per org."
  @spec exact_subject(Org.t(), String.t()) :: String.t()
  def exact_subject(%Org{slug: slug}, key), do: "fabric:#{slug}:#{key}"

  @doc "Idempotent fabric submission; `params[\"idempotency_key\"]` is required."
  @spec submit(Org.t(), map()) :: result()
  def submit(%Org{} = org, params) when is_map(params) do
    key = params["idempotency_key"]

    if valid_key?(key) do
      subject = exact_subject(org, key)
      params = Map.put(params, "exact_subject", subject)

      transact(fn resources ->
        lock!(org, key)

        case existing(org, subject) do
          %Epoch{} = epoch ->
            run = Ash.get!(Run, epoch.run_id, action: :read_unscoped, authorize?: false)
            %{run: run, epoch: epoch, replay?: true}

          nil ->
            case create_rows(org, params) do
              {:ok, {run, epoch}} -> %{run: run, epoch: epoch, replay?: false}
              {:error, reason} -> Ash.DataLayer.rollback(resources, reason)
            end
        end
      end)
    else
      {:error, :idempotency_key_required}
    end
  end

  @doc "Non-idempotent Run + running Epoch creation (the execution surface)."
  @spec create(Org.t(), map()) :: {:ok, {Run.t(), Epoch.t()}} | {:error, term()}
  def create(%Org{} = org, params) when is_map(params) do
    case transact(fn resources ->
           case create_rows(org, params) do
             {:ok, pair} -> pair
             {:error, reason} -> Ash.DataLayer.rollback(resources, reason)
           end
         end) do
      {:ok, {run, epoch}} -> {:ok, {run, epoch}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Default exact subject of a non-idempotent submission."
  def default_exact_subject(%Org{slug: slug}, %Run{id: run_id}), do: "org:#{slug}-run:#{run_id}"

  defp transact(fun) do
    resources = [Run, Epoch]

    Ash.DataLayer.transaction(
      resources,
      fn -> fun.(resources) end,
      nil,
      %{type: :custom, metadata: %{operation: :xaas_execution_fabric_create_run}}
    )
  end

  defp lock!(%Org{id: org_id}, key) do
    Ecto.Adapters.SQL.query!(Xaas.Repo, "SELECT pg_advisory_xact_lock($1)", [
      :erlang.phash2({:xaas_tunnel_submit, org_id, key})
    ])
  end

  defp existing(%Org{id: org_id}, subject) do
    Epoch
    |> Ash.Query.for_read(:read_unscoped, %{}, authorize?: false)
    |> Ash.Query.filter(org_id == ^org_id and exact_subject == ^subject and cycle == 0)
    |> Ash.Query.limit(1)
    |> Ash.read_one!(authorize?: false)
  end

  defp create_rows(org, params) do
    with {:ok, run} <-
           create_run_row(
             params["goal"],
             params["provider"] || "zcode",
             org.id,
             params["verifier_suite"]
           ),
         exact_subject = params["exact_subject"] || default_exact_subject(org, run),
         {:ok, epoch} <- create_running_epoch(run, exact_subject, params["worktree"]) do
      {:ok, {run, epoch}}
    end
  end

  # `verifier_suite` is a NAME the operator registered (`Xaas.Ultracode.Verifier`);
  # `VerifierSuiteRegistered` turns an unknown name into a typed error.
  defp create_run_row(goal, provider, org_id, verifier_suite) do
    Run
    |> Ash.Changeset.for_create(
      :submit,
      %{goal: goal, provider: provider, org_id: org_id, verifier_suite: verifier_suite},
      authorize?: false
    )
    |> Ash.create()
  end

  # Cycle 0, state :running directly, so a submitted run is immediately
  # claim_next-visible to a provider worker; org_id denormalized from the Run.
  defp create_running_epoch(run, exact_subject, worktree) do
    Epoch
    |> Ash.Changeset.for_create(
      :create,
      %{
        run_id: run.id,
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
end
