defmodule Xaas.Library.ILSRepo do
  @moduledoc """
  Behaviour for Integrated Library System (ILS) integration, following
  `Xaas.AwsRepo`'s exact pattern: a real `@behaviour`, a real runtime
  adapter switch via `Application.fetch_env!/2` + `Keyword.fetch!(:adapter)`,
  no compile-time `use` or hardcoded module reference.

  Two families of callbacks:

    * `get_catalog/1` and `get_circulation_history/1` -- the original
      catalog/circulation contract documented in
      `docs/case-studies/next-read/ILS-AND-EXPLANATION-SUBSTITUTION.md`.
    * `patron_status/1` and `item_information/1` -- added for the SIP2
      (Standard Interchange Protocol 2) adapter, mirroring SIP2 message
      pairs 23/24 (Patron Status Request/Response) and 17/18 (Item
      Information Request/Response).

  Adapters:

    * `Xaas.Library.ILSRepo.FixtureAdapter` -- default, seeded in-memory
      demo data. Real, deterministic, not a mock.
    * `Xaas.Library.ILSRepo.SIP2Adapter` -- real `:gen_tcp` SIP2 client,
      protocol-verified against a real local SIP2 test server
      (`test/support/sip2_test_server.ex`). PARTIAL_ALIVE: no live vendor
      endpoint exists to verify end-to-end against a real ILS.
  """

  @callback get_catalog(school_id :: String.t()) :: {:ok, [map()]} | {:error, term()}
  @callback get_circulation_history(student_id :: String.t()) ::
              {:ok, [map()]} | {:error, term()}

  @callback patron_status(patron_id :: String.t()) :: {:ok, map()} | {:error, term()}
  @callback item_information(item_id :: String.t()) :: {:ok, map()} | {:error, term()}

  @spec get_catalog(String.t()) :: {:ok, [map()]} | {:error, term()}
  def get_catalog(school_id), do: adapter().get_catalog(school_id)

  @spec get_circulation_history(String.t()) :: {:ok, [map()]} | {:error, term()}
  def get_circulation_history(student_id), do: adapter().get_circulation_history(student_id)

  @spec patron_status(String.t()) :: {:ok, map()} | {:error, term()}
  def patron_status(patron_id), do: adapter().patron_status(patron_id)

  @spec item_information(String.t()) :: {:ok, map()} | {:error, term()}
  def item_information(item_id), do: adapter().item_information(item_id)

  defp adapter,
    do:
      :xaas
      |> Application.fetch_env!(__MODULE__)
      |> Keyword.fetch!(:adapter)
end
