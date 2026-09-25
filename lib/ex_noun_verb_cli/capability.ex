defmodule ExNounVerbCli.Capability do
  @moduledoc """
  Deterministic capability standing, ported from the real Rust
  `CapabilityPackage`/`ProofSurface`/`CapabilityStanding` shape in
  `~/clap-noun-verb/src/capability/registry.rs` (read in full; struct/enum
  field names and the `refresh_standing`/`is_alive` derivation logic below
  are copied from that source, not invented from memory).

  Standing is derived from evidence, never asserted directly: a
  `ExNounVerbCli.Capability.Package`'s `:standing` field is always the
  output of `derive_standing/1` over its `proof_surfaces`, recomputed every
  time a proof surface is recorded via `record_proof/2` — mirroring the
  Rust `CapabilityPackage::record_proof` -> `refresh_standing` sequence.

  ## Worked example (mirrors the Rust README's own "receipt-verify" example)

      package =
        ExNounVerbCli.Capability.Package.new(
          "receipt-verify",
          "Receipt Verification",
          "26.7.62",
          "Verifies one admitted execution receipt"
        )
        |> ExNounVerbCli.Capability.Package.with_default_verb("verify")

      {:ok, package} =
        ExNounVerbCli.Capability.record_proof(
          package,
          ExNounVerbCli.Capability.ProofSurface.new(
            "unit-contract",
            "unit",
            "receipt:unit:001",
            true,
            true
          )
        )

      package.standing
      #=> :alive

  Per the Rust README: "`ALIVE` is refused when any declared proof surface
  is unobserved, unreplayed, or missing its receipt identifier."
  """

  alias ExNounVerbCli.Capability.{Package, ProofSurface}

  @typedoc """
  Operational standing for a capability package.

  The exact six-value set from the real Rust `CapabilityStanding` enum
  (`~/clap-noun-verb/src/capability/registry.rs:12-26`) — deliberately not
  assumed to match this ecosystem's own separate five-value receipt-standing
  vocabulary (`UNKNOWN|PARTIAL_ALIVE|ALIVE|BLOCKED|BUILD_BROKEN|UNSUPPORTED`
  from a different project), even though several names coincide.

  `derive_standing/1` (the pure evidence-derivation rule ported from
  `CapabilityPackage::refresh_standing`) only ever produces `:unknown`,
  `:partial_alive`, `:alive`, or `:blocked` — `:build_broken` and
  `:unsupported` exist in the real type but are set by out-of-band callers
  (e.g. a build step, an environment check), not derived from proof
  surfaces, matching the Rust source (`refresh_standing` never assigns
  either of those two variants).
  """
  @type standing :: :unknown | :partial_alive | :alive | :blocked | :build_broken | :unsupported

  defmodule ProofSurface do
    @moduledoc """
    One executable proof surface for a capability, ported field-for-field
    from the real Rust `ProofSurface` struct
    (`~/clap-noun-verb/src/capability/registry.rs:29-41`).
    """

    @enforce_keys [:name, :rung, :receipt, :observed, :replay_verified]
    defstruct [:name, :rung, :receipt, :observed, :replay_verified]

    @type t :: %__MODULE__{
            name: String.t(),
            rung: String.t(),
            receipt: String.t(),
            observed: boolean(),
            replay_verified: boolean()
          }

    @doc """
    Constructs one proof surface. Mirrors `ProofSurface::new` — positional
    `name`, `rung` (verification rung, e.g. "unit"/"integration"/"e2e"/
    "chaos"/"stress"/"replay"), `receipt` (receipt identifier or content
    hash), `observed`, `replay_verified`.
    """
    @spec new(String.t(), String.t(), String.t(), boolean(), boolean()) :: t()
    def new(name, rung, receipt, observed, replay_verified) do
      %__MODULE__{
        name: name,
        rung: rung,
        receipt: receipt,
        observed: observed,
        replay_verified: replay_verified
      }
    end

    @doc """
    Whether this single proof surface has standing on its own.

    Ports `ProofSurface::is_alive` exactly: observed AND replay-verified AND
    a non-blank receipt identifier.
    """
    @spec alive?(t()) :: boolean()
    def alive?(%__MODULE__{observed: observed, replay_verified: replayed, receipt: receipt}) do
      observed and replayed and String.trim(receipt) != ""
    end
  end

  defmodule Package do
    @moduledoc """
    Capability package metadata and its admitted proof closure, ported
    field-for-field from the real Rust `CapabilityPackage` struct
    (`~/clap-noun-verb/src/capability/registry.rs:70-92`).
    """

    @enforce_keys [:id, :name, :version, :description]
    defstruct id: nil,
              name: nil,
              version: nil,
              description: nil,
              default_verb: nil,
              standing: :unknown,
              proof_surfaces: [],
              dependencies: []

    @type t :: %__MODULE__{
            id: String.t(),
            name: String.t(),
            version: String.t(),
            description: String.t(),
            default_verb: String.t() | nil,
            standing: ExNounVerbCli.Capability.standing(),
            proof_surfaces: [ExNounVerbCli.Capability.ProofSurface.t()],
            dependencies: [String.t()]
          }

    @doc """
    Creates a capability package from its id, name, version, and
    description. Mirrors `CapabilityPackage::new` — starts at `:unknown`
    standing with no proof surfaces and no dependencies.
    """
    @spec new(String.t(), String.t(), String.t(), String.t()) :: t()
    def new(id, name, version, description) do
      %__MODULE__{
        id: id,
        name: name,
        version: version,
        description: description,
        default_verb: nil,
        standing: :unknown,
        proof_surfaces: [],
        dependencies: []
      }
    end

    @doc """
    Binds an ontology-owned default verb. Mirrors
    `CapabilityPackage::with_default_verb`.
    """
    @spec with_default_verb(t(), String.t()) :: t()
    def with_default_verb(%__MODULE__{} = package, verb) do
      %{package | default_verb: verb}
    end

    @doc """
    Adds one dependency capability id if not already present, keeping
    `dependencies` sorted. Mirrors `CapabilityPackage::with_dependency`
    (`~/clap-noun-verb/src/capability/registry.rs:122-131`) exactly,
    including the sort-after-insert behavior.
    """
    @spec with_dependency(t(), String.t()) :: t()
    def with_dependency(%__MODULE__{dependencies: dependencies} = package, capability_id) do
      if capability_id in dependencies do
        package
      else
        %{package | dependencies: Enum.sort([capability_id | dependencies])}
      end
    end

    @doc """
    Validates package metadata and standing invariants. Mirrors
    `CapabilityPackage::validate`
    (`~/clap-noun-verb/src/capability/registry.rs:167-191`): non-blank id,
    name, version; a present-but-blank `default_verb` is refused; no blank
    dependency ids; and `:alive` standing requires at least one proof
    surface and every proof surface to itself be alive.
    """
    @spec validate(t()) :: :ok | {:error, String.t()}
    def validate(%__MODULE__{} = package) do
      cond do
        String.trim(package.id) == "" ->
          {:error, "Package ID cannot be empty"}

        String.trim(package.name) == "" ->
          {:error, "Package name cannot be empty"}

        String.trim(package.version) == "" ->
          {:error, "Package version cannot be empty"}

        package.default_verb == "" ->
          {:error, "Default verb cannot be empty"}

        Enum.any?(package.dependencies, &(String.trim(&1) == "")) ->
          {:error, "Capability dependencies cannot be empty"}

        package.standing == :alive and
            (package.proof_surfaces == [] or
               not Enum.all?(package.proof_surfaces, &ProofSurface.alive?/1)) ->
          {:error, "ALIVE standing requires observed and replayed proof surfaces"}

        true ->
          :ok
      end
    end
  end

  @doc """
  Records or replaces one proof surface on `package`, then recomputes
  standing — mirroring the real Rust `CapabilityPackage::record_proof`
  (dedup by `name` + `rung`, keep `proof_surfaces` sorted by
  `{rung, name}`, then `refresh_standing`).

  Returns `{:error, message}` when `proof.name` or `proof.rung` is blank,
  matching the Rust source's own validation (`record_proof` there returns
  `Err` for the same condition before touching the list).
  """
  @spec record_proof(Package.t(), ProofSurface.t()) :: {:ok, Package.t()} | {:error, String.t()}
  def record_proof(%Package{} = package, %ProofSurface{} = proof) do
    cond do
      String.trim(proof.name) == "" or String.trim(proof.rung) == "" ->
        {:error, "Proof surface name and rung cannot be empty"}

      true ->
        updated_surfaces =
          package.proof_surfaces
          |> Enum.reject(&(&1.name == proof.name and &1.rung == proof.rung))
          |> then(&[proof | &1])
          |> Enum.sort_by(&{&1.rung, &1.name})

        package = %{package | proof_surfaces: updated_surfaces}
        {:ok, %{package | standing: derive_standing(package)}}
    end
  end

  @doc """
  Pure evidence-derivation rule over a package's `proof_surfaces`, ported
  exactly from the real Rust `CapabilityPackage::refresh_standing`
  (`~/clap-noun-verb/src/capability/registry.rs:154-165`):

  - no proof surfaces at all -> `:unknown`
  - every proof surface is individually alive (per `ProofSurface.alive?/1`)
    -> `:alive`
  - at least one, but not all, alive -> `:partial_alive`
  - one or more present but none alive -> `:blocked`

  Accepts either a `Package.t()` (reads its `proof_surfaces`) or a bare
  list of `ProofSurface.t()`.
  """
  @spec derive_standing(Package.t() | [ProofSurface.t()]) :: standing()
  def derive_standing(%Package{proof_surfaces: proof_surfaces}),
    do: derive_standing(proof_surfaces)

  def derive_standing(proof_surfaces) when is_list(proof_surfaces) do
    total = length(proof_surfaces)
    alive_count = Enum.count(proof_surfaces, &ProofSurface.alive?/1)

    cond do
      total == 0 -> :unknown
      alive_count == total -> :alive
      alive_count > 0 -> :partial_alive
      true -> :blocked
    end
  end
end
