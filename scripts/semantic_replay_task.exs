# The graph-side law of a cold replay (Xaas.Ultracode.SemanticReplay,
# GC-26.9.23 GC23-10 / PRD PR-013 / ARD sections 7 and 16): runs the REAL
# GgenIgniter.SemanticJira functions no mix semantic_jira.* task exposes.
# Nothing here decides a standing; it only evaluates the graph side's own law.
#
# Run from a ggen_igniter checkout (the replay does this as an OS process):
#
#   MIX_ENV=test mix run --no-start /abs/path/scripts/semantic_replay_task.exs \
#     digest <out.json> <receipt.json>...
#   MIX_ENV=test mix run --no-start /abs/path/scripts/semantic_replay_task.exs \
#     replay_check <expected.json> <observed.json> <out.json>
#
# `digest` writes {"digests": {<path>: SemanticJira.digest(<decoded json>)}}:
# the digest the Reconciler binds a transition event's `receipt_digest` to.
#
# `replay_check` writes SemanticJira.replay_check/2 over the two manifests:
# {"ok": true, "receipt": <the KNOWN_REPLAY receipt>} or
# {"ok": false, "reason": <the typed refusal, JSON-rendered>}.
#
# Exit 0 with one JSON line {"ok": true, ...} on stdout when the law ran
# (a refused replay is still exit 0: the refusal IS the law's answer);
# exit 1 on unreadable input; exit 2 on a usage error.

alias GgenIgniter.SemanticJira

jsonable = fn jsonable, value ->
  cond do
    is_tuple(value) -> value |> Tuple.to_list() |> Enum.map(&jsonable.(jsonable, &1))
    is_list(value) -> Enum.map(value, &jsonable.(jsonable, &1))
    is_map(value) -> Map.new(value, fn {k, v} -> {to_string(k), jsonable.(jsonable, v)} end)
    is_atom(value) and value not in [nil, true, false] -> Atom.to_string(value)
    true -> value
  end
end

read = fn path ->
  with {:ok, body} <- File.read(path),
       {:ok, decoded} <- Jason.decode(body) do
    decoded
  else
    error ->
      IO.puts(Jason.encode!(%{"ok" => false, "reason" => "unreadable", "path" => path, "error" => inspect(error)}))
      System.halt(1)
  end
end

case System.argv() do
  ["digest", out | paths] when paths != [] ->
    digests = Map.new(paths, fn path -> {path, SemanticJira.digest(read.(path))} end)
    File.write!(out, Jason.encode!(%{"digests" => digests}))
    IO.puts(Jason.encode!(%{"ok" => true, "digests" => map_size(digests)}))

  ["replay_check", expected, observed, out] ->
    result =
      case SemanticJira.replay_check(read.(expected), read.(observed)) do
        {:ok, receipt} -> %{"ok" => true, "receipt" => receipt}
        {:error, reason} -> %{"ok" => false, "reason" => jsonable.(jsonable, reason)}
      end

    File.write!(out, Jason.encode!(result))
    IO.puts(Jason.encode!(%{"ok" => true, "replay_check" => result["ok"]}))

  other ->
    IO.puts(Jason.encode!(%{"ok" => false, "reason" => "usage", "argv" => other}))
    System.halt(2)
end
