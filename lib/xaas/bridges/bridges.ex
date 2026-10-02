defmodule Xaas.Bridges do
  @moduledoc """
  Shared types and identity for the Chicago agentic-payment sibling bridges.

  Each bridge module under `Xaas.Bridges.*` wraps one admitted sibling engine
  (ash_pplan, ash_graphlaw, ex4pm, ash_a2a evidence) and projects its real
  outcome — `{:ok, envelope}` or `{:refused, reason}` — into a common envelope.
  Bridges never authorize: `authority_ceiling` is `:none` on every surface, and
  standing stays `"UNKNOWN"` unless a real receipt from this session's observed
  execution backs it (RESOLUTIONS R8).

  The registry of bridge capability across all Chicago layers lives in
  `Xaas.Bridges.Registry`.
  """

  @subject "urn:chicago:agentic-payment:purchase-001"

  @typedoc "The exact Chicago demo subject, as a byte-stable URN literal."
  @type subject :: String.t()

  @typedoc """
  Common evidence envelope projected by every bridge.

  `standing` uses the rendered string vocabulary (`"UNKNOWN"`, `"PARTIAL_ALIVE"`,
  `"UNSUPPORTED"`) so envelopes project byte-stably into the machine JSON
  (RESOLUTIONS R2/R8). `authority_ceiling` is always `:none` — a bridge observes,
  it never actuates.
  """
  @type envelope :: %{
          required(:subject) => subject(),
          required(:claim) => String.t(),
          required(:state) => atom(),
          required(:provenance) => map(),
          required(:evidence_ref) => String.t() | nil,
          required(:receipt_ref) => String.t() | nil,
          required(:authority_ceiling) => :none,
          required(:standing) => String.t()
        }

  @typedoc "Typed refusal passthrough from the owning sibling engine."
  @type refused :: {:refused, %{required(:code) => atom(), optional(atom()) => term()}}

  @doc "The exact Chicago demo subject (RESOLUTIONS R2 literal)."
  @spec subject() :: subject()
  def subject, do: @subject

  @doc """
  Builds a base envelope for `subject` in `state`.

  Standing defaults to `"UNKNOWN"` (R8: no inherited standing). Bridges may
  raise it to `"PARTIAL_ALIVE"` only when they attach a receipt produced by an
  observed execution in this session.
  """
  @spec envelope(subject(), atom(), String.t(), String.t()) :: envelope()
  def envelope(subject, claim, state, standing \\ "UNKNOWN") when is_binary(standing) do
    %{
      subject: subject,
      claim: claim,
      state: state,
      provenance: %{},
      evidence_ref: nil,
      receipt_ref: nil,
      authority_ceiling: :none,
      standing: standing
    }
  end

  @doc """
  Resolves the current repository subject SHA without spawning a process.

  Reads `.git/HEAD` and the referenced ref file directly. Returns `nil` when the
  repository state cannot be resolved; callers must treat a missing pin as
  `:unknown` provenance, never guess.
  """
  @spec head_sha(String.t()) :: String.t() | nil
  def head_sha(git_dir \\ ".git") do
    case File.read(Path.join(git_dir, "HEAD")) do
      {:ok, "ref: " <> ref} ->
        ref = String.trim(ref)

        case File.read(Path.join(git_dir, ref)) do
          {:ok, sha} -> String.trim(sha)
          _ -> packed_ref(git_dir, ref)
        end

      {:ok, sha} ->
        sha = String.trim(sha)
        if String.match?(sha, ~r/^[0-9a-f]{40}$/), do: sha, else: nil

      _ ->
        nil
    end
  end

  defp packed_ref(git_dir, ref) do
    case File.read(Path.join([git_dir, "packed-refs"])) do
      {:ok, body} ->
        body
        |> String.split("\n")
        |> Enum.find_value(fn line ->
          case String.split(String.trim(line), " ") do
            [sha, ^ref] -> sha
            _ -> nil
          end
        end)

      _ ->
        nil
    end
  end
end
