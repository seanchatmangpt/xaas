defmodule Xaas.Tunnel.Fabric do
  @moduledoc """
  Pure server-side state machine of the bounded runtime fabric
  (protocol `xaas-fabric/1`):

      new -> probed -> admitted -> submitted -> executing -> sealed -> replayed

  `transition/2` is total: every legal event yields `{:ok, state}`, every other
  `(phase, event)` pair is `{:error, {:illegal_transition, phase, event_tag}}`.
  `actuate` is refused in every phase (`{:refused, {:authority_ceiling, "actuate"}}`)
  and never changes the state -- the fabric's authority ceiling is CONSTRUCT.

  `reconcile/1` decides what to do after a crash, from durable facts only (the
  epoch row, its sealed receipts, an external actuation intent and whether a
  prepared receipt exists). No I/O happens here; the controller and
  `Xaas.Tunnel.Submit` gather the facts.

  HANDWRITTEN.md: UNSUPPORTED(generator-capability) -- no admitted pack renders a
  pure Elixir state machine from the tunnel ontology.
  """

  alias Xaas.Tunnel.{Capabilities, Receipt}

  @protocol "xaas-fabric/1"
  @long_poll_max_ms 25_000

  defstruct phase: :new, capabilities: [], run_id: nil, epoch_id: nil, digest: nil

  @type phase ::
          :new
          | :probed
          | :admitted
          | :submitted
          | :executing
          | :sealed
          | :replayed
          | {:refused, term()}
          | {:blocked, term()}

  @type t :: %__MODULE__{phase: phase()}

  @type event ::
          {:probed, [String.t()]}
          | {:admitted, %{admitted: [String.t()]}}
          | {:submitted, String.t(), String.t()}
          | :lease_observed
          | {:sealed, String.t()}
          | {:replayed, String.t()}
          | :actuate
          | {:actuate, term()}

  @type decision ::
          :not_submitted
          | {:await_execution, String.t()}
          | {:lease_expired, String.t()}
          | {:sealed, String.t()}
          | {:resume_external_seal, term()}
          | {:refused, :receipt_missing_for_succeeded_intent}

  def protocol, do: @protocol
  def long_poll_max_ms, do: @long_poll_max_ms

  @doc "Clamp a requested long-poll wait to `[0, 25000]` ms; junk becomes the max."
  @spec wait_ms(term()) :: non_neg_integer()
  def wait_ms(v) when is_integer(v), do: v |> max(0) |> min(@long_poll_max_ms)

  def wait_ms(v) when is_binary(v) do
    case Integer.parse(v) do
      {n, ""} -> wait_ms(n)
      _ -> @long_poll_max_ms
    end
  end

  def wait_ms(_), do: @long_poll_max_ms

  @doc "A fresh fabric state."
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc "Apply one event; see the moduledoc for the legal sequence."
  @spec transition(t(), event()) ::
          {:ok, t()}
          | {:error, {:illegal_transition, phase(), atom()}}
          | {:refused, {:authority_ceiling, String.t()}}
  def transition(%__MODULE__{}, :actuate), do: {:refused, {:authority_ceiling, "actuate"}}
  def transition(%__MODULE__{}, {:actuate, _}), do: {:refused, {:authority_ceiling, "actuate"}}

  def transition(%__MODULE__{phase: :new} = s, {:probed, caps}) when is_list(caps) do
    if Enum.sort(caps) == Enum.sort(Capabilities.allowlist()),
      do: {:ok, %{s | phase: :probed, capabilities: caps}},
      else: {:ok, %{s | phase: {:refused, :contract_mismatch}}}
  end

  def transition(%__MODULE__{phase: :probed} = s, {:admitted, %{admitted: admitted}})
      when is_list(admitted) do
    if Enum.sort(admitted) == Enum.sort(Capabilities.allowlist()),
      do: {:ok, %{s | phase: :admitted}},
      else: {:ok, %{s | phase: {:refused, :capability_not_admitted}}}
  end

  def transition(%__MODULE__{phase: :admitted} = s, {:submitted, run_id, epoch_id})
      when is_binary(run_id) and is_binary(epoch_id),
      do: {:ok, %{s | phase: :submitted, run_id: run_id, epoch_id: epoch_id}}

  def transition(%__MODULE__{phase: :submitted} = s, :lease_observed),
    do: {:ok, %{s | phase: :executing}}

  def transition(%__MODULE__{phase: p} = s, {:sealed, digest})
      when p in [:submitted, :executing] and is_binary(digest),
      do: {:ok, %{s | phase: :sealed, digest: digest}}

  def transition(%__MODULE__{phase: :sealed, digest: d} = s, {:replayed, digest})
      when is_binary(digest) do
    if digest == d,
      do: {:ok, %{s | phase: :replayed}},
      else: {:ok, %{s | phase: {:refused, :replay_digest_mismatch}}}
  end

  def transition(%__MODULE__{phase: phase}, event),
    do: {:error, {:illegal_transition, phase, event_tag(event)}}

  defp event_tag(event) when is_atom(event), do: event
  defp event_tag(event) when is_tuple(event) and is_atom(elem(event, 0)), do: elem(event, 0)
  defp event_tag(_), do: :unknown

  @doc """
  Crash-window decision from durable facts:

    * `intent` `:executing` with a prepared receipt -> `{:resume_external_seal, id}`
      (re-prepare with the same key must report `resumed?: true`, then seal);
    * `intent` `:succeeded` with no sealed receipt -> refused;
    * any sealed receipt -> `{:sealed, digest}` (digest of the newest wire receipt);
    * no epoch -> `:not_submitted` (safe to resubmit with the same key);
    * a running epoch whose lease expired -> `{:lease_expired, id}` (`claim_next`
      re-claims expired leases);
    * otherwise -> `{:await_execution, id}`.
  """
  @spec reconcile(map()) :: decision()
  def reconcile(facts) when is_map(facts) do
    intent = Map.get(facts, :intent)
    receipts = Map.get(facts, :receipts, [])
    epoch = Map.get(facts, :epoch)
    now = Map.get(facts, :now) || DateTime.utc_now()

    cond do
      match?(%{status: :executing}, intent) and Map.get(facts, :prepared_receipt?, false) ->
        {:resume_external_seal, Map.get(intent, :id)}

      match?(%{status: :succeeded}, intent) and receipts == [] ->
        {:refused, :receipt_missing_for_succeeded_intent}

      receipts != [] ->
        {:sealed, receipts |> List.last() |> Receipt.digest()}

      is_nil(epoch) ->
        :not_submitted

      lease_expired?(epoch, now) ->
        {:lease_expired, epoch.id}

      true ->
        {:await_execution, epoch.id}
    end
  end

  defp lease_expired?(%{state: :running, leased_to: who, lease_expires_at: %DateTime{} = at}, now)
       when not is_nil(who),
       do: DateTime.compare(at, now) == :lt

  defp lease_expired?(_epoch, _now), do: false
end
