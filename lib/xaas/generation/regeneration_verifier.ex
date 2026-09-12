defmodule Xaas.Generation.RegenerationVerifier do
  @moduledoc """
  Regeneration verifier — the required component checking a projection
  against the projection hash manifest.

  ## What this module honestly implements

  `verify/2` is real: it calls `Xaas.Generation.HashManifest.verify/2`
  against the *actual* current file on disk, and returns `:mismatch`
  whenever the real hash doesn't match — directly closing the ticket's
  third falsifier ("the regeneration verifier passes on a projection
  whose hash does not match the projection hash manifest"). There is no
  code path in this module that can return `:match` for a mismatched
  hash.

  ## Bounded UNSUPPORTED (explicit, not hidden)

  A *real* regeneration verifier would re-run the actual generator
  (`ggen`, an Ash codegen mix task, an HDDL/PDDL toolchain, ...) and diff
  its fresh output against the current file, so it can also catch the
  case where the file matches its recorded hash but the *generator itself*
  would now produce something different (e.g. the canonical graph changed
  since the hash was recorded). This repo has no single, generic
  "invoke the generator that produced this projection" entry point across
  `ggen`/HDDL/Ash codegen/etc. — each has its own CLI and inputs — so that
  half of "regeneration verification" is not implemented here. Calling
  `regenerate_and_diff/1` returns a typed
  `Xaas.Generation.UnsupportedReceipt` rather than faking a diff.
  """

  alias Xaas.Generation.{HashManifest, UnsupportedReceipt}

  @spec verify(String.t(), HashManifest.digest()) :: :match | :mismatch | {:error, term()}
  def verify(projection_path, expected_hash) do
    HashManifest.verify(projection_path, expected_hash)
  end

  @doc """
  Explicit UNSUPPORTED path: this repo cannot yet generically invoke
  "the generator" for an arbitrary manifest entry and diff fresh output.
  Always returns a typed receipt instead of fabricating a result.
  """
  @spec regenerate_and_diff(Xaas.Generation.Manifest.Entry.t()) :: UnsupportedReceipt.t()
  def regenerate_and_diff(%Xaas.Generation.Manifest.Entry{generator_id: generator_id} = entry) do
    UnsupportedReceipt.build(
      generator_id,
      :no_generic_regeneration_entrypoint,
      "no unified invoke-generator API exists in this repo for generator_id=#{generator_id}; " <>
        "cannot actually re-run generation for #{entry.projection_path} to diff against a fresh " <>
        "output, so hash-manifest comparison (verify/2) is the honest bound of this slice"
    )
  end
end
