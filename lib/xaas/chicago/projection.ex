defmodule Xaas.Chicago.Projection do
  @moduledoc """
  Loader and identity validator for the Chicago projections at
  `priv/chicago/chicago.{machine,verification,executive,replay}.json`.

  Identity validation fails closed. A projection is admitted only when:

  * `"generated"` is the literal `true` (a hand-written file is not a render)
  * `"authorityClaim"` is exactly `"NONE"` (R4/R8 — a projection mints no DO)
  * `"subject"` is the exact subject literal (`Xaas.Chicago.Subject`)
  * `"projectionType"` matches the file being loaded
  * `"generatorIdentity"` carries the pack prefix
    `ggen-marketplace/chicago-xaas-surface-pack@` (typed UNSUPPORTED upstream
    until the pack qualifies; the consumer binds to the identity, not to PATH)
  * `"sourceDigests"` is an array of `%{"path" => _, "sha256" => 64-hex}`

  The machine projection additionally validates its body per R2: `rootGoal`
  (7 required fields), `layers` — exactly the 10 contract slugs, each carrying
  the R2 keys with `required: true` and `status` defaulting to `"UNKNOWN"` —
  and `cases` carrying the R2 case keys with `candidateOnly: true`,
  `authorityClaim: "NONE"` and `observedStanding: "UNKNOWN"` (no pre-judged
  outcomes; the pradyot hardcoded-outcome class is refused by construction).

  Results (including refusals) are memoized in `:persistent_term` keyed by
  `{type, path}`; `clear_memo/0` (facade `reload/0`) invalidates.
  """

  alias Xaas.Chicago.{Layer, Subject}

  @types [:machine, :verification, :executive, :replay]
  @generator_identity_prefix "ggen-marketplace/chicago-xaas-surface-pack@"
  @root_goal_keys ~w(identifier label repository baseSha authorityCeiling evidenceHorizon replayIdentity)
  @hex ~r/^[0-9a-f]{64}$/

  @spec types :: [atom]
  def types, do: @types

  @spec generator_identity_prefix :: String.t()
  def generator_identity_prefix, do: @generator_identity_prefix

  @doc "Load without memoization. Primary entry for tests and the render task gate."
  @spec load(atom, String.t()) :: {:ok, map} | {:refused, {atom, term}}
  def load(type, path) when type in @types and is_binary(path) do
    with {:ok, body} <- read(path),
         {:ok, decoded} <- decode(path, body),
         :ok <- validate_header(path, decoded, type),
         {:ok, doc} <- validate_body(path, decoded, type) do
      {:ok, doc}
    end
  end

  @doc "Memoized load: the same result is served from :persistent_term until cleared."
  @spec load_memoized(atom, String.t()) :: {:ok, map} | {:refused, {atom, term}}
  def load_memoized(type, path) do
    key = memo_key(type, path)

    case :persistent_term.get(key, :missing) do
      :missing ->
        result = load(type, path)
        :persistent_term.put(key, result)
        result

      result ->
        result
    end
  end

  @doc "Drop every memoized Chicago projection (used by facade reload and the render task)."
  @spec clear_memo :: :ok
  def clear_memo do
    for {key, _value} <- :persistent_term.get(),
        match?({__MODULE__, t, _p} when t in @types, key) do
      :persistent_term.erase(key)
    end

    :ok
  end

  @doc "Erase the memo entry for one loaded path."
  @spec clear_memo(atom, String.t()) :: :ok
  def clear_memo(type, path) do
    :persistent_term.erase(memo_key(type, path))
    :ok
  end

  defp memo_key(type, path), do: {__MODULE__, type, path}

  # -- readers ---------------------------------------------------------------

  defp read(path) do
    if File.exists?(path) do
      {:ok, File.read!(path)}
    else
      {:refused, {:chicago_projection_missing, path}}
    end
  end

  defp decode(path, body) do
    case Jason.decode(body) do
      {:ok, %{} = decoded} ->
        {:ok, decoded}

      {:ok, _other} ->
        invalid(path, :not_object)

      {:error, %Jason.DecodeError{} = err} ->
        invalid(path, {:json_decode, Exception.message(err)})
    end
  end

  # -- header identity -------------------------------------------------------

  defp validate_header(path, %{"generated" => true} = doc, type) do
    with :ok <- authority_none?(path, doc),
         :ok <- exact_subject?(path, doc),
         :ok <- projection_type?(path, doc, type),
         :ok <- generator_identity?(path, doc) do
      source_digests?(path, doc)
    end
  end

  defp validate_header(path, _doc, _type), do: invalid(path, :generated_not_true)

  defp authority_none?(_path, %{"authorityClaim" => "NONE"}), do: :ok
  defp authority_none?(path, _), do: invalid(path, :authority_claim_not_none)

  defp exact_subject?(path, %{"subject" => subject}) do
    if Subject.matches?(subject), do: :ok, else: invalid(path, {:subject_mismatch, subject})
  end

  defp exact_subject?(path, _), do: invalid(path, :subject_missing)

  defp projection_type?(path, %{"projectionType" => pt}, type) do
    if pt == Atom.to_string(type), do: :ok, else: invalid(path, {:projection_type_mismatch, pt})
  end

  defp projection_type?(path, _, _), do: invalid(path, :projection_type_missing)

  defp generator_identity?(path, %{"generatorIdentity" => gi}) do
    if is_binary(gi) and String.starts_with?(gi, @generator_identity_prefix),
      do: :ok,
      else: invalid(path, {:generator_identity_mismatch, gi})
  end

  defp generator_identity?(path, _), do: invalid(path, :generator_identity_missing)

  defp source_digests?(path, %{"sourceDigests" => digests}) do
    cond do
      not is_list(digests) ->
        invalid(path, :source_digests_not_array)

      Enum.all?(digests, &digest_entry?/1) ->
        :ok

      true ->
        invalid(path, :source_digest_entry_invalid)
    end
  end

  defp source_digests?(path, _), do: invalid(path, :source_digests_missing)

  defp digest_entry?(%{"path" => p, "sha256" => h}) when is_binary(p) and is_binary(h),
    do: Regex.match?(@hex, h)

  defp digest_entry?(_), do: false

  # -- machine body ----------------------------------------------------------

  defp validate_body(path, doc, :machine) do
    with :ok <- root_goal(path, doc),
         :ok <- layers(path, doc),
         :ok <- cases(path, doc) do
      {:ok, doc}
    end
  end

  defp validate_body(_path, doc, _other), do: {:ok, doc}

  defp root_goal(path, %{"rootGoal" => %{} = rg}) do
    missing = Enum.filter(@root_goal_keys, fn k -> not is_binary(rg[k]) end)

    if missing == [] do
      :ok
    else
      invalid(path, {:root_goal_invalid, missing})
    end
  end

  defp root_goal(path, _), do: invalid(path, {:root_goal_invalid, :absent})

  defp layers(path, %{"layers" => layers}) when is_list(layers) do
    ids = Enum.map(layers, fn l -> l && Map.get(l, "id") end)

    cond do
      layers == [] ->
        invalid(path, {:layer_set_invalid, :empty})

      not Enum.all?(ids, &Layer.known?/1) ->
        invalid(path, {:unknown_layer_id, Enum.find(ids, fn id -> not Layer.known?(id) end)})

      Enum.uniq(ids) != ids ->
        invalid(path, {:layer_set_invalid, :duplicate})

      true ->
        with :ok <- layer_objects(path, layers) do
          missing =
            Layer.required_ids()
            |> Enum.filter(fn id -> Atom.to_string(id) not in ids end)

          if missing == [] do
            :ok
          else
            invalid(path, {:layer_set_invalid, {:missing, missing}})
          end
        end
    end
  end

  defp layers(path, _), do: invalid(path, {:layer_set_invalid, :not_array})

  defp layer_objects(path, layers) do
    bad =
      Enum.find(layers, fn l ->
        Enum.any?(Layer.required_keys(), fn k -> not is_binary(Map.get(l, k)) end) or
          not is_boolean(Map.get(l, "required")) or
          not refs?(Map.get(l, "evidenceRefs")) or
          not refs?(Map.get(l, "receiptRefs")) or
          not valid_status?(Map.get(l, "status"))
      end)

    if bad, do: invalid(path, {:layer_invalid, bad["id"]}), else: :ok
  end

  defp valid_status?(nil), do: true
  defp valid_status?(s) when is_binary(s), do: true
  defp valid_status?(_), do: false

  defp refs?(refs), do: is_list(refs) and Enum.all?(refs, &is_binary/1)

  defp cases(path, %{"cases" => cases}) when is_list(cases) do
    ids = Enum.map(cases, fn c -> c && Map.get(c, "id") end)

    cond do
      Enum.uniq(ids) != ids ->
        invalid(path, {:case_id_duplicate, :duplicate})

      true ->
        bad =
          Enum.find(cases, fn c ->
            not text_keys?(c) or
              Map.get(c, "candidateOnly") != true or
              Map.get(c, "authorityClaim") != "NONE" or
              Map.get(c, "observedStanding") != "UNKNOWN" or
              not Subject.matches?(Map.get(c, "subject"))
          end)

        if bad, do: invalid(path, {:case_invalid, bad["id"]}), else: :ok
    end
  end

  defp cases(path, _), do: invalid(path, {:case_set_invalid, :not_array})

  defp text_keys?(c) do
    Enum.all?(~w(id label description subject authorityClaim observedStanding), fn k ->
      is_binary(Map.get(c, k))
    end)
  end

  defp invalid(path, reason), do: {:refused, {:chicago_projection_invalid, {path, reason}}}
end
