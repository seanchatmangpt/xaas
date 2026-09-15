defmodule Xaas.Telemetry.OcelRealOtelSpanTest do
  @moduledoc """
  Chicago-school test: proves OCEL v2 event data reaches a REAL, actually
  exported OpenTelemetry span -- not `priv/ocel/ash-actions.ndjson` (the
  log file `ocel_ash_emitter_test.exs` already covers), and not a mock.

  Real finding this test exists to check: `mix.lock` carried only
  `opentelemetry_api`/`opentelemetry_ash`/`opentelemetry_process_propagator`
  before this session -- never the real `opentelemetry` SDK application.
  Without it, `OpenTelemetry.Tracer.set_attributes/1`
  (`Xaas.Telemetry.OcelAshEmitter`'s real span-enrichment call) runs
  against the API package's no-op default tracer: the call succeeds, but
  produces no real, observable span anywhere.

  CONFIRMED, once the real SDK was added (test-only, this session): OCEL
  v2 event data really does reach a real exported OTel span, as real
  dot-namespaced attributes (`ocel.eid`, `ocel.activity`, `ocel.action`,
  `ocel.domain`, `ocel.resource`, `ocel.outcome`, `ocel.duration_ms`,
  `ocel.actor_present?`, `ocel.authorize?`,
  `ocel.public_attribute_count`) -- NOT the colon-prefixed
  `"ocel:eid"`/`"ocel:activity"` JSON-OCEL keys the ndjson log file and
  the network-forwarded envelope use (OTel attribute-key convention is
  dot-namespaced, confirmed empirically, not assumed from either format).
  A real Ash `create` action produces exactly one span carrying this
  enrichment (the top-level `:action`-type span); nested spans (a
  `changeset`-kind span, an `ash_ai_update_embeddings` follow-on action
  span) are real, separate, distinct spans in the same export batch.

  Uses `opentelemetry`'s own real, built-in test exporter
  (`otel_exporter_pid`, `deps/opentelemetry/src/otel_exporter_pid.erl`) --
  ships with the SDK for exactly this purpose (send real exported spans as
  real Erlang messages to a pid), not a hand-rolled mock and not
  interaction-based: assertions below are on the real, decoded span
  record's real attribute list, real state.
  """
  use Xaas.DataCase, async: false

  alias Xaas.Accounts.User
  alias Xaas.Library.Book

  setup do
    {:ok, _} = Application.ensure_all_started(:opentelemetry)

    # Real SDK wiring: a real simple (synchronous) span processor backed
    # by the real otel_exporter_pid test exporter, pointed at THIS test
    # process. `:otel_simple_processor` flushes on every span end, so the
    # `{:span, span}` message arrives before the Ash action call returns
    # (Ash.Tracer.telemetry_span's :stop is where the span is ended).
    :ok = :otel_simple_processor.set_exporter(:otel_exporter_pid, self())

    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
    :ok
  end

  test "a real Ash create action's OTel span carries real OCEL v2 attributes, not just the log file" do
    actor =
      Ash.Seed.seed!(User, %{
        email: "ocel-real-otel-#{System.unique_integer([:positive])}@example.com"
      })

    {:ok, _book} =
      Book
      |> Ash.Changeset.for_create(
        :create,
        %{title: "Real OTel Span OCEL Fixture", isbn: "978-0-0000-0000-0", author: "Test Author"},
        actor: actor
      )
      |> Ash.create()

    # Real, decoded spans -- not a log line, not a mock call assertion.
    # Ash real-action tracing fires more than one real span per action
    # (an outer action span plus inner changeset/query spans); collect
    # every one the SDK actually exported in a short real window and
    # search across all of them for the OCEL-enriched one, rather than
    # assuming message order. If OpentelemetryAsh/the SDK never actually
    # exports anything, `collect_spans/1` returns an empty list and the
    # assertion below fails with a real, honest failure -- not a
    # silent pass.
    spans = collect_spans([])

    assert spans != [], "no real OTel spans were exported at all"

    ocel_attrs =
      spans
      |> Enum.map(&span_attributes_map/1)
      |> Enum.find(&Map.has_key?(&1, "ocel.eid"))

    refute is_nil(ocel_attrs),
           "none of the #{length(spans)} real exported spans carried an ocel.eid " <>
             "attribute; real attribute sets seen: #{inspect(Enum.map(spans, &span_attributes_map/1))}"

    assert ocel_attrs["ocel.activity"] == "book.create"
    assert ocel_attrs["ocel.resource"] == "Xaas.Library.Book"
    assert ocel_attrs["ocel.outcome"] == "ok"
    assert ocel_attrs["ocel.domain"] == "Xaas.Library"
    assert is_binary(ocel_attrs["ocel.eid"]) and ocel_attrs["ocel.eid"] != ""
  end

  defp collect_spans(acc) do
    receive do
      {:span, span} -> collect_spans([span | acc])
    after
      500 -> acc
    end
  end

  # `span` is the real `:opentelemetry.span()` record tuple (Erlang
  # record, no Elixir struct, 16 fields per
  # deps/opentelemetry/include/otel_span.hrl's real -record(span, {...})
  # definition, read directly rather than assumed): trace_id, span_id,
  # tracestate, parent_span_id, parent_span_is_remote, name, kind,
  # start_time, end_time, attributes, events, links, status, trace_flags,
  # is_recording, instrumentation_scope. Elixir tuples are 0-indexed and
  # element 0 is the :span tag, so field N (1-based among the 16 fields)
  # sits at elem(span, N) -- attributes is field 10, confirmed empirically
  # (element 11 was actually `events`, off-by-one from an initial wrong
  # guess, fixed against the real FunctionClauseError this produced).
  defp span_attributes_map(span) do
    attrs = elem(span, 10)

    # attrs is an :otel_attributes record wrapping a plain map -- real
    # introspection via its own public accessor rather than assuming
    # internal shape.
    :otel_attributes.map(attrs)
    |> Map.new(fn {k, v} -> {to_string(k), v} end)
  end
end
