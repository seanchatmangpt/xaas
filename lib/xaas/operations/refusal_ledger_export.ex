defmodule Xaas.Operations.RefusalLedgerExport do
  @moduledoc """
  Canonical anti-vacuity refusal ledger regeneration (v26.10.7 WP-6, lane W616).

  Emits `docs/cro/artifacts/refusal-ledger-v26.10.7.jcs.json`: one canonical,
  deterministically-ordered entry per registered refusal variant across the
  four grounded vocabulary sources:

    1. the v26.10.6 refusal ledger
       (`docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json`) projected by
       `Xaas.Semantics.AiroRiskMapping.variants/0` (W984bj/ce),
    2. the eyerun refusal codes (wasm4pm `crates/eu_gate/src/lib.rs`
       `RefusalCode::as_str`, lines 39–43, per W613),
    3. the typed-gap register refusal atoms
       (`lib/xaas/semantics/authority_channel.ex` `@type transmit_result`),
    4. the `Xaas.Semantics.Vkg` refusal atoms (`vkg.ex`,
       `vkg/{witness,replay,query,workspace}.ex`).

  Entry shape (canonical JSON):
  `%{"atom", "sources", "minters", "pinning_court", "mutation_kill"}` where
  `pinning_court` is an in-repo court path that must exist on disk at emit
  time and `"mutation_kill"` is `%{"killed" => boolean, "receipt" => string | nil}`.

  **Anti-vacuity mechanism (fail-closed)**: every entry must cite a pinning
  court that exists on disk. An entry whose court path is missing on disk is
  a typed refusal — the ledger refuses to emit, and nothing is written:

      {:error, {:unpinned_variant, %{atom: ..., court: ...}}}

  Canonicalization reuses the w603 idiom (`Xaas.Operations.AuthorityLedgerExport`):
  RFC 8785 JCS via `Xaas.Semantics.Jcs`, entries sorted by atom, no
  wall-clock timestamp. Content digest: SHA-256 over the canonical bytes.
  BLAKE3 is not in `mix.lock` (checked W616); substitution disclosed here and
  in the artifact as `"hash_algorithm": "sha256"`.

  Pure reads over the real repo (Chicago): real files, real parse, no mocks.
  The mix task `mix xaas.export_refusal_ledger` is a thin shell over this
  module.
  """

  alias Xaas.Semantics.AiroRiskMapping

  @source_ledger_relpath "docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json"
  @out_relpath "docs/cro/artifacts/refusal-ledger-v26.10.7.jcs.json"
  @ledger_version "26.10.7"
  @hash_algorithm "sha256"

  @doc false
  @spec repo_root() :: String.t()
  def repo_root, do: Path.expand("../../..", __DIR__)

  # Grounded W616 census (read from source this session):
  # - eyerun codes: /Users/sac/wasm4pm/crates/eu_gate/src/lib.rs,
  #   RefusalCode::as_str (lines 39-43, per W613). Minted by the external
  #   Rust crate; pinned in-repo by the W706 wire-deepening court.
  # - typed-gap register atoms: lib/xaas/semantics/authority_channel.ex
  #   `@type transmit_result` (:REFUSED_UNKNOWN_CHANNEL at :72,
  #   :REFUSED_NO_INCIDENT_EVIDENCE at :73).
  # - Vkg atoms: lib/xaas/semantics/vkg.ex:56, vkg/witness.ex:152,
  #   vkg/replay.ex:95, vkg/query.ex:151, vkg/workspace.ex:158, and
  #   REFUSED_VKG_MANIFEST (ash_r2rml manifest.ex:49, surfaced at vkg.ex:53,
  #   asserted at test/xaas/semantics/vkg_refusal_negative_test.exs:107).
  @eyerun_court "test/eu_ai_act/eyerun_wire_deepening_test.exs"
  @eyerun_minter "external:wasm4pm/crates/eu_gate/src/lib.rs RefusalCode::as_str (W613)"

  @eyerun [
    "REFUSED_REQUIRED_FIELD_MISSING",
    "REFUSED_ENUM_VIOLATION",
    "REFUSED_RANGE_VIOLATION",
    "REFUSED_FORBIDDEN_FIELD",
    "REFUSED_INFRASTRUCTURE_FAULT"
  ]

  @typed_gap [
    {"REFUSED_UNKNOWN_CHANNEL", "lib/xaas/semantics/authority_channel.ex:72",
     "test/xaas/semantics/authority_channel_test.exs"},
    {"REFUSED_NO_INCIDENT_EVIDENCE", "lib/xaas/semantics/authority_channel.ex:73",
     "test/xaas/semantics/authority_channel_test.exs"}
  ]

  @vkg [
    {"REFUSED_VKG_EMPTY_CATALOG", "lib/xaas/semantics/vkg.ex:56",
     "test/xaas/semantics/vkg_refusal_negative_test.exs"},
    {"REFUSED_VKG_MANIFEST", "lib/xaas/semantics/vkg.ex:53 (ash_r2rml manifest.ex:49)",
     "test/xaas/semantics/vkg_refusal_negative_test.exs:107"},
    {"REFUSED_XAAS_VKG_WITNESS", "lib/xaas/semantics/vkg/witness.ex:152",
     "test/xaas/semantics/vkg_refusal_negative_test.exs"},
    {"REFUSED_XAAS_VKG_REPLAY", "lib/xaas/semantics/vkg/replay.ex:95",
     "test/xaas/semantics/vkg_refusal_negative_test.exs"},
    {"REFUSED_XAAS_VKG_QUERY", "lib/xaas/semantics/vkg/query.ex:151",
     "test/xaas/semantics/vkg/query_test.exs"},
    {"REFUSED_XAAS_VKG_WORKSPACE", "lib/xaas/semantics/vkg/workspace.ex:158",
     "test/xaas/semantics/vkg/workspace_test.exs"}
  ]

  @type entry :: %{
          required(:atom) => String.t(),
          required(:sources) => [atom()],
          required(:minters) => [String.t()],
          required(:pinning_court) => String.t(),
          required(:mutation_kill) => %{String.t() => boolean() | String.t() | nil}
        }

  @doc "Relative output path of the emitted ledger."
  @spec out_relpath() :: String.t()
  def out_relpath, do: @out_relpath

  @doc "Absolute output path of the emitted ledger."
  @spec out_path() :: String.t()
  def out_path, do: Path.join(repo_root(), @out_relpath)

  @doc """
  Full canonical vocabulary: union of the four sources, merged by atom,
  sorted. Raises the fail-closed anti-vacuity gate as a typed error via
  `build/0`; a missing pinning court on disk is `{:error, {:unpinned_variant, _}}`.
  """
  @spec vocabulary() :: [entry()] | no_return()
  def vocabulary do
    case build_entries() do
      {:ok, entries} -> entries
      {:error, {:unpinned_variant, _} = err} -> throw(err)
    end
  end

  @doc """
  Build the ledger map (no write). Fails closed on any unpinned variant.
  """
  @spec build() :: {:ok, map(), String.t()} | {:error, {:unpinned_variant, map()}}
  def build do
    with {:ok, entries} <- build_entries() do
      canon = %{
        "entries" => Enum.map(entries, &entry_json/1),
        "hash_algorithm" => @hash_algorithm,
        "ledger_version" => @ledger_version,
        "counts" => %{
          "declared" => length(entries),
          "refused_atoms" => Enum.count(entries, &String.starts_with?(&1.atom, "REFUSED_")),
          "mutation_kill_verified" => Enum.count(entries, & &1.mutation_kill["killed"]),
          "court_cited" => Enum.count(entries, &is_binary(&1.pinning_court))
        },
        "source_ledger" => @source_ledger_relpath,
        "vocabulary_sources" => [
          "airo_risk_mapping_variants (W984bj/ce)",
          "eyerun_eu_gate_refusal_codes (W613, wasm4pm crates/eu_gate/src/lib.rs:39-43)",
          "typed_gap_register_authority_channel",
          "xaas_semantics_vkg"
        ]
      }

      {:ok, canon, Xaas.Semantics.Jcs.encode(canon)}
    end
  end

  @doc """
  Emit the ledger artifact to disk. Fails closed on any unpinned variant;
  on refusal nothing is written.
  """
  @spec emit() ::
          {:ok, %{path: String.t(), digest: String.t()}}
          | {:error, {:unpinned_variant, map()}}
  def emit do
    with {:ok, _canon, canonical_json} <- build() do
      digest = :crypto.hash(:sha256, canonical_json) |> Base.encode16(case: :lower)
      File.mkdir_p!(Path.dirname(out_path()))
      File.write!(out_path(), canonical_json <> "\n")
      {:ok, %{path: out_path(), digest: digest}}
    end
  end

  @doc """
  Anti-vacuity court. `{:ok, report}` when the full vocabulary emits
  fail-closed-clean; `{:error, reason}` otherwise. Legs:

    1. full-vocabulary emit succeeds (which itself proves every entry cites
       an on-disk court — a missing court refuses the emit),
    2. digest replay: re-read the artifact from disk, recompute the digest,
       byte-identical match,
    3. mutation leg: injecting a fake variant with no court yields the typed
       refusal `{:error, {:unpinned_variant, _}}`.
  """
  @spec court() :: {:ok, map()} | {:error, term()}
  def court do
    with {:ok, %{digest: digest}} <- emit(),
         {:ok, rebuilt} <- rebuild_digest(),
         true <- rebuilt == digest || {:digest_replay_mismatch, rebuilt},
         {:error, {:unpinned_variant, fake}} <- inject_fake() do
      {:ok,
       %{
         emitted: out_relpath(),
         digest: digest,
         digest_replay_match: true,
         fake_injection_refused: fake,
         counts: build_counts()
       }}
    else
      false -> {:error, :digest_replay_mismatch}
      {:error, _} = err -> err
    end
  end

  @doc "Re-read the artifact from disk and recompute its content digest."
  @spec rebuild_digest() :: {:ok, String.t()} | {:error, term()}
  def rebuild_digest do
    with {:ok, body} <- File.read(out_path()) do
      json = Jason.decode!(body)

      {:ok,
       :crypto.hash(:sha256, Xaas.Semantics.Jcs.encode(json))
       |> Base.encode16(case: :lower)}
    end
  end

  @doc """
  Mutation leg: prepend a fake variant with no existing court and run the
  fail-closed pin check. Returns the typed refusal.
  """
  @spec inject_fake(String.t()) :: {:error, {:unpinned_variant, map()}}
  def inject_fake(fake_atom \\ "REFUSED_FAKE_W616_NO_COURT") do
    {:ok, entries} = build_entries()

    injected = %{
      atom: fake_atom,
      sources: [:injected],
      minters: [],
      pinning_court: "test/xaas/w616_does_not_exist_test.exs",
      mutation_kill: %{"killed" => false, "receipt" => nil}
    }

    ([injected | entries] |> Enum.sort_by(& &1.atom) |> assert_all_pinned())
    |> case do
      {:error, _} = err -> err
      _ -> raise "anti-vacuity mutation SURVIVED: fake variant #{fake_atom} was not refused"
    end
  end

  # -- internals --

  defp entry_json(e) do
    %{
      "atom" => e.atom,
      "minters" => Enum.sort(e.minters),
      "mutation_kill" => %{
        "killed" => e.mutation_kill["killed"],
        "receipt" => e.mutation_kill["receipt"]
      },
      "pinning_court" => e.pinning_court,
      "sources" => e.sources |> Enum.map(&Atom.to_string/1) |> Enum.sort()
    }
  end

  defp build_counts do
    {:ok, canon, _} = build()
    canon["counts"]
  end

  defp build_entries do
    with {:ok, source_variants} <- source_variants() do
      entries =
        (source_variants ++ appended_entries())
        |> Enum.sort_by(& &1.atom)
        |> merge_by_atom()

      assert_all_pinned(entries)
    end
  end

  defp source_variants do
    ledger_path = AiroRiskMapping.ledger_path()

    if File.exists?(ledger_path) do
      variants =
        AiroRiskMapping.load_ledger()["variants"]
        |> Enum.map(fn v ->
          variant = v["variant"] || "UNKNOWN_VARIANT"

          %{
            atom: variant,
            sources: [:airo_risk_mapping_variants],
            minters: Enum.map(v["sites"] || [], &site_minter/1),
            pinning_court: v["fixture"],
            mutation_kill: %{
              "killed" => v["mutant_killed"] == true,
              "receipt" =>
                if(v["mutant_killed"] == true, do: kill_receipt(v["note"]), else: nil)
            }
          }
        end)

      {:ok, variants}
    else
      {:error,
       {:unpinned_variant, %{atom: "<entire source ledger>", court: @source_ledger_relpath}}}
    end
  end

  defp appended_entries do
    eyerun =
      Enum.map(@eyerun, fn atom ->
        %{
          atom: atom,
          sources: [:eyerun_eu_gate],
          minters: [@eyerun_minter],
          pinning_court: @eyerun_court,
          mutation_kill: %{"killed" => false, "receipt" => nil}
        }
      end)

    typed_gap =
      Enum.map(@typed_gap, fn {atom, minter, court} ->
        %{
          atom: atom,
          sources: [:typed_gap_register],
          minters: [minter],
          pinning_court: court,
          mutation_kill: %{"killed" => false, "receipt" => nil}
        }
      end)

    vkg =
      Enum.map(@vkg, fn {atom, minter, court} ->
        %{
          atom: atom,
          sources: [:xaas_semantics_vkg],
          minters: [minter],
          pinning_court: court,
          mutation_kill: %{"killed" => false, "receipt" => nil}
        }
      end)

    eyerun ++ typed_gap ++ vkg
  end

  defp site_minter(site) do
    case String.split(site, ":") do
      [path, _line] -> path
      [path] -> path
      _ -> site
    end
  end

  defp kill_receipt(note) when is_binary(note) and note != "", do: note
  defp kill_receipt(_),
    do: "docs/sjira/v26.10.6/plans/w320-anti-vacuity-audit.md (mutation-kill audit)"

  defp merge_by_atom(sorted) do
    sorted
    |> Enum.chunk_by(& &1.atom)
    |> Enum.map(fn
      [single] -> single
      dupes -> Enum.reduce(Enum.drop(dupes, 1), hd(dupes), &merge_entry/2)
    end)
  end

  defp merge_entry(e, acc) do
    %{
      acc
      | sources: Enum.uniq(acc.sources ++ e.sources),
        minters: Enum.uniq(acc.minters ++ e.minters),
        pinning_court: pick_court(acc.pinning_court, e.pinning_court)
    }
  end

  # Sources that carry line-qualified courts keep them; the bare-file court
  # wins only when the other side has none.
  defp pick_court(nil, court) when is_binary(court), do: court
  defp pick_court(court, _), do: court

  # The anti-vacuity gate: every entry must cite a pinning court that exists
  # on disk. An entry without a court (or with a court that is absent from
  # disk) fails closed.
  defp assert_all_pinned(entries) do
    Enum.reduce_while(entries, {:ok, entries}, fn e, acc ->
      court = e.pinning_court
      court_file = court_file(court)

      cond do
        not is_binary(court) or court == "" ->
          {:halt,
           {:error,
            {:unpinned_variant, %{atom: e.atom, court: court, reason: :court_not_a_path}}}}

        not File.exists?(court_file) ->
          {:halt,
           {:error, {:unpinned_variant, %{atom: e.atom, court: court, reason: :court_missing}}}}

        true ->
          {:cont, acc}
      end
    end)
  end

  # Court citations take the forms:
  #   "test/....exs[:LINE]" | "test/....exs (annotation)" — strip any
  #   trailing " (annotation)" suffix, then the ":LINE" suffix, and verify
  #   the resulting file exists on disk.
  defp court_file(court) do
    path =
      court
      |> String.split(" (", parts: 2)
      |> hd()
      |> String.split(":")
      |> Enum.find(&String.contains?(&1, "/"))

    Path.join(repo_root(), path || court)
  end
end
