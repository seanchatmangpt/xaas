defmodule Xaas.Ultracode.CapabilityResolver.PackGenerator do
  @moduledoc """
  The generation executor for the capability court's `:generate` /
  `:compose` / `:extend` verdicts (v26.9.27).

  It does not reimplement pack qualification. It runs the marketplace's
  canonical harness, `scripts/qualify_packs.py`'s `qualify_pack/3` (real
  `ggen sync run` twice in a scratch consumer, byte-identical replay check,
  probe presence, and the harness's own build verification where it
  applies), for exactly the named pack, and returns its typed record:

    * `{:generated, record}` -- the harness returned `status: "ALIVE"` (or
      `"WARN"`) for the pack: the generator produced a deterministic
      projection from the pack's semantic source.
    * `{:refused, code, record}` -- the harness refused (e.g.
      `REFUSED:GGEN_PACK_SYNC_FAILED`, `REFUSED:GGEN_PACK_NONDETERMINISTIC_REPLAY`).
    * `{:error, reason}` -- the executor could not run: `:marketplace_not_configured`,
      `{:unknown_pack, id}`, `:ggen_not_found`, `{:harness_failed, exit, output}`.

  Configuration: `:ultracode_ggen_marketplace_root` (a checkout of
  ggen-marketplace; default `~/ggen-marketplace` when present) and
  `:ultracode_ggen_bin` (default `ggen` on PATH).

  Authority: CONSTRUCT only. Generation happens in the harness's temporary
  consumer directory; nothing is written to any work surface and no DO is
  performed. The caller records the outcome as an execution receipt.
  """

  @harness """
  import json, shutil, sys
  sys.path.insert(0, "scripts")
  import qualify_packs as q
  name, ggen, timeout = sys.argv[1], sys.argv[2], float(sys.argv[3])
  packs = {p.name: p for p in q.require_admitted()}
  if name not in packs:
      print(json.dumps({"status": "UNKNOWN_PACK", "name": name}))
      sys.exit(0)
  print(json.dumps(q.qualify_pack(packs[name], ggen, timeout), sort_keys=True))
  """

  @type result ::
          {:generated, map()}
          | {:refused, String.t(), map()}
          | {:error, term()}

  @doc "Runs the canonical marketplace qualification for `pack_id`."
  @spec generate(String.t(), keyword()) :: result()
  def generate(pack_id, opts \\ []) when is_binary(pack_id) do
    with {:ok, root} <- marketplace_root(opts),
         {:ok, ggen} <- ggen_bin(opts) do
      timeout = Keyword.get(opts, :timeout_seconds, 5)

      args = ["-c", @harness, pack_id, ggen, to_string(timeout)]

      case System.cmd("python3", args, cd: root, stderr_to_stdout: false) do
        {out, 0} -> interpret(pack_id, out)
        {out, code} -> {:error, {:harness_failed, code, String.slice(out, -2000, 2000)}}
      end
    end
  rescue
    error in ErlangError -> {:error, {:harness_failed, :enoent, Exception.message(error)}}
  end

  defp interpret(pack_id, out) do
    line = out |> String.split("\n", trim: true) |> List.last()

    case line && Jason.decode(line) do
      {:ok, %{"status" => "UNKNOWN_PACK"}} ->
        {:error, {:unknown_pack, pack_id}}

      {:ok, %{"status" => status} = record} when status in ["ALIVE", "WARN"] ->
        {:generated, record}

      {:ok, %{"status" => _} = record} ->
        {:refused, Map.get(record, "code", "REFUSED:UNKNOWN"), record}

      _ ->
        {:error, {:harness_failed, :unparseable, String.slice(out, -2000, 2000)}}
    end
  end

  @doc false
  def marketplace_root(opts) do
    root =
      Keyword.get(opts, :marketplace_root) ||
        Application.get_env(:xaas, :ultracode_ggen_marketplace_root) ||
        Path.expand("~/ggen-marketplace")

    if File.regular?(Path.join(root, "scripts/qualify_packs.py")),
      do: {:ok, root},
      else: {:error, :marketplace_not_configured}
  end

  defp ggen_bin(opts) do
    bin =
      Keyword.get(opts, :ggen_bin) ||
        Application.get_env(:xaas, :ultracode_ggen_bin) ||
        System.find_executable("ggen")

    if is_binary(bin) and File.exists?(bin), do: {:ok, bin}, else: {:error, :ggen_not_found}
  end
end
