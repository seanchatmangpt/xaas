defmodule Xaas.Sjira.EngineerWorkflow do
  @moduledoc """
  Pure delivery projection from admitted semantic work to engineer queues.

  This module does not originate work and does not execute consequences. It adds
  deterministic identity, routing, ordering, deduplication, dependency closure,
  pagination, recovery metadata, and provider-neutral upsert commands.
  """

  alias Xaas.Sjira.EngineerWorkflow.Codec

  @schema "xaas.sjira.engineer-work/v1"
  @standing_rank %{"READY_FOR_ENGINEER_DISPOSITION" => 0, "NOVEL_INVESTIGATION_REQUIRED" => 1,
    "BLOCKED_ON_EVIDENCE" => 2, "UNKNOWN" => 3, "UNSUPPORTED(provider_capability)" => 4}
  @classification_rank %{"KNOWN" => 0, "PARTIAL" => 1, "UNKNOWN" => 2, "Successor" => 3}
  @default_page_size 50
  @max_page_size 500

  @spec project(map(), keyword()) :: {:ok, map()} | {:refused, atom(), term()}
  def project(%{} = work, opts \\ []) do
    with {:ok, w} <- normalize(work),
         :ok <- require_identity(w),
         :ok <- require_authority_boundary(w),
         {:ok, deps} <- normalize_strings(w["dependencies"], :invalid_dependencies),
         {:ok, labels} <- normalize_strings(list(w["labels"]) ++ list(opts[:labels]), :invalid_labels) do
      body = %{
        "schema" => @schema, "work_id" => w["id"], "subject" => w["subject"],
        "classification" => w["classification"], "standing" => w["standing"],
        "obligation" => w["obligation"], "owner" => w["owner"],
        "next_action" => w["next_action"], "required_evidence" => list(w["required_evidence"]),
        "supporting_evidence" => list(w["supporting_evidence"]), "human_gate" => w["human_gate"],
        "authority" => w["authority"], "dependencies" => deps, "labels" => labels,
        "delivery" => %{"provider" => string_opt(opts, :provider) || "semantic-jira",
          "project" => string_opt(opts, :project), "queue" => string_opt(opts, :queue),
          "priority" => priority(w, opts), "assignee" => string_opt(opts, :assignee) || w["owner"]},
        "recovery" => %{"max_attempts" => positive(opts[:max_attempts], 3),
          "backoff_ms" => positive(opts[:backoff_ms], 1_000),
          "max_backoff_ms" => positive(opts[:max_backoff_ms], 60_000),
          "jitter" => opts[:jitter] != false}
      }
      digest = Codec.digest(body)
      {:ok, body |> Map.put("work_digest", digest) |> Map.put("idempotency_key", "sjira:" <> digest)}
    end
  end
  def project(other, _opts), do: {:refused, :work_not_map, other}

  @spec project_many(Enumerable.t(), keyword()) :: {:ok, [map()]} | {:refused, atom(), term()}
  def project_many(items, opts \\ []) do
    Enum.reduce_while(items, {:ok, %{}}, fn item, {:ok, acc} ->
      case project(item, opts) do
        {:ok, e} ->
          id = e["work_id"]
          digest = e["work_digest"]
          case acc[id] do
            nil -> {:cont, {:ok, Map.put(acc, id, e)}}
            %{"work_digest" => ^digest} -> {:cont, {:ok, acc}}
            prior -> {:halt, {:refused, :duplicate_identity_conflict,
              %{work_id: id, first_digest: prior["work_digest"], second_digest: e["work_digest"]}}}
          end
        refusal -> {:halt, refusal}
      end
    end)
    |> case do
      {:ok, by_id} -> {:ok, by_id |> Map.values() |> sort()}
      refusal -> refusal
    end
  end

  @spec sort([map()]) :: [map()]
  def sort(items) do
    Enum.sort_by(items, fn e ->
      {get_in(e, ["delivery", "priority"]) || 999, Map.get(@standing_rank, e["standing"], 999),
       Map.get(@classification_rank, e["classification"], 999), e["work_id"]}
    end)
  end

  @spec dependency_batch([map()], keyword()) :: {:ok, [map()]} | {:refused, atom(), term()}
  def dependency_batch(items, opts \\ []) do
    limit = positive(opts[:limit], length(items))
    satisfied = MapSet.new(Keyword.get(opts, :satisfied, []))
    known = MapSet.union(MapSet.new(items, & &1["work_id"]), satisfied)
    missing = for e <- items, dep <- e["dependencies"], not MapSet.member?(known, dep),
      do: {e["work_id"], dep}

    if missing == [] do
      close(sort(items), satisfied, [], limit)
    else
      {:refused, :missing_dependencies, missing |> Enum.uniq() |> Enum.sort()}
    end
  end

  @spec page([map()], keyword()) :: {:ok, map()} | {:refused, atom(), term()}
  def page(items, opts \\ []) do
    size = clamp_page(opts[:page_size])
    ordered = sort(items)
    with {:ok, rest} <- after_cursor(ordered, opts[:cursor]) do
      {page, tail} = Enum.split(rest, size)
      cursor = if page != [] and tail != [], do: cursor_for(List.last(page)), else: nil
      {:ok, %{items: page, next_cursor: cursor}}
    end
  end

  @spec partitions([map()]) :: map()
  def partitions(items) do
    items
    |> Enum.group_by(fn e -> d = e["delivery"]; {d["provider"], d["project"], d["queue"]} end)
    |> Map.new(fn {k, v} -> {k, sort(v)} end)
  end

  @spec upsert_command(map()) :: map()
  def upsert_command(e) do
    %{"op" => "upsert", "idempotency_key" => e["idempotency_key"], "external_key" => e["work_id"],
      "provider" => get_in(e, ["delivery", "provider"]), "project" => get_in(e, ["delivery", "project"]),
      "queue" => get_in(e, ["delivery", "queue"]), "authority" => "INTENT_ONLY",
      "payload" => %{"title" => "[#{e["classification"]}] #{e["subject"]}: #{e["next_action"]}",
        "description" => description(e), "priority" => get_in(e, ["delivery", "priority"]),
        "assignee" => get_in(e, ["delivery", "assignee"]), "labels" => e["labels"],
        "metadata" => %{"schema" => e["schema"], "work_digest" => e["work_digest"],
          "subject" => e["subject"], "standing" => e["standing"], "authority" => e["authority"],
          "dependencies" => e["dependencies"]}}}
  end

  @spec encode_jsonl([map()]) :: iodata()
  def encode_jsonl(items), do: items |> sort() |> Enum.map(&[Codec.encode(&1), "\n"])

  defp normalize(work) do
    s = Map.new(work, fn {k, v} -> {to_string(k), v} end)
    {:ok, %{"id" => s["id"] || s["identity"] || s["order"],
      "subject" => s["subject"] || s["checkpoint_of"] || s["iri"],
      "classification" => s["classification"] || "UNKNOWN", "standing" => s["standing"] || "UNKNOWN",
      "obligation" => s["obligation"] || s["reason"] || "inspect typed work",
      "owner" => s["owner"] || s["provider"] || "unassigned",
      "next_action" => s["next_action"] || "engineer disposition",
      "required_evidence" => s["required_evidence"] || [], "supporting_evidence" => s["supporting_evidence"] || [],
      "human_gate" => Map.get(s, "human_gate", true), "authority" => s["authority"] || "SELECT_CONSTRUCT_ONLY",
      "dependencies" => s["dependencies"] || s["depends_on"] || [], "labels" => s["labels"] || []}}
  end

  defp require_identity(w) do
    missing = Enum.reject(~w(id subject classification standing obligation), &(is_binary(w[&1]) and String.trim(w[&1]) != ""))
    if missing == [], do: :ok, else: {:refused, :missing_identity_fields, missing}
  end
  defp require_authority_boundary(%{"authority" => a}) when a in ["SELECT_CONSTRUCT_ONLY", "NONE"], do: :ok
  defp require_authority_boundary(%{"authority" => a}), do: {:refused, :consequential_authority_not_deliverable, a}

  defp normalize_strings(values, reason) do
    values = list(values)
    if Enum.all?(values, &(is_binary(&1) and String.trim(&1) != "")),
      do: {:ok, values |> Enum.map(&String.trim/1) |> Enum.uniq() |> Enum.sort()},
      else: {:refused, reason, values}
  end

  defp close(_remaining, _satisfied, acc, 0), do: {:ok, Enum.reverse(acc)}
  defp close([], _satisfied, acc, _limit), do: {:ok, Enum.reverse(acc)}
  defp close(remaining, satisfied, acc, limit) do
    {ready, blocked} = Enum.split_with(remaining, fn e -> Enum.all?(e["dependencies"], &MapSet.member?(satisfied, &1)) end)
    case ready do
      [] -> {:refused, :dependency_cycle_or_unsatisfied_closure,
        Enum.map(blocked, &{&1["work_id"], &1["dependencies"]}) |> Enum.sort()}
      _ ->
        take = Enum.take(ready, limit)
        next = MapSet.union(satisfied, MapSet.new(take, & &1["work_id"]))
        close(Enum.drop(ready, length(take)) ++ blocked, next, Enum.reverse(take) ++ acc, limit - length(take))
    end
  end

  defp after_cursor(ordered, nil), do: {:ok, ordered}
  defp after_cursor(ordered, cursor) when is_binary(cursor) do
    with {:ok, %{"work_id" => id, "work_digest" => digest}} <- Codec.decode_cursor(cursor),
         index when is_integer(index) <- Enum.find_index(ordered, &(&1["work_id"] == id and &1["work_digest"] == digest)) do
      {:ok, Enum.drop(ordered, index + 1)}
    else
      nil -> {:refused, :stale_cursor, cursor}
      {:ok, other} -> {:refused, :invalid_cursor_payload, other}
      refusal -> refusal
    end
  end
  defp after_cursor(_ordered, cursor), do: {:refused, :invalid_cursor, cursor}
  defp cursor_for(e), do: Codec.encode_cursor(%{"work_id" => e["work_id"], "work_digest" => e["work_digest"]})

  defp priority(w, opts), do: (opts[:priority] || case {w["standing"], w["classification"]} do
    {"READY_FOR_ENGINEER_DISPOSITION", "KNOWN"} -> 10
    {"NOVEL_INVESTIGATION_REQUIRED", _} -> 20
    {"BLOCKED_ON_EVIDENCE", _} -> 30
    {"UNSUPPORTED(provider_capability)", _} -> 40
    _ -> 50
  end)

  defp description(e), do: [e["obligation"], "", "Standing: #{e["standing"]}", "Authority: #{e["authority"]}",
    "Required evidence: #{Enum.join(e["required_evidence"], ", ")}", "Dependencies: #{Enum.join(e["dependencies"], ", ")}",
    "Work digest: #{e["work_digest"]}"] |> Enum.join("\n")
  defp list(nil), do: []
  defp list(v) when is_list(v), do: v
  defp list(v), do: [v]
  defp string_opt(opts, key), do: (case opts[key] do v when is_binary(v) and v != "" -> v; _ -> nil end)
  defp positive(v, _default) when is_integer(v) and v > 0, do: v
  defp positive(_v, default), do: default
  defp clamp_page(v) when is_integer(v) and v > 0, do: min(v, @max_page_size)
  defp clamp_page(_), do: @default_page_size
end
