defmodule Xaas.GraphqlSchemaTest do
  @moduledoc """
  Confirms Xaas.Library's AshGraphql-exposed resources are actually wired
  into Xaas.GraphqlSchema's domain list -- a resource can carry a
  `graphql do type: ... end` block and still be unreachable via GraphQL if
  the owning domain never registers a `queries do get/list ... end` for
  it, and that gap is silent (no compile error, no test failure) unless
  something inspects the compiled schema.

  Deliberately does NOT run a real query through `Absinthe.run/3`: that
  would exercise Absinthe's own query-execution engine and AshGraphql's
  auto-derived resolver to re-fetch `Book` data whose real attribute
  correctness is already proven directly against the resource/domain
  elsewhere in the suite (e.g. curation_test.exs, next_read_test.exs) --
  testing the framework's execution path a second time, not this app's
  own configuration. Inspecting `Xaas.GraphqlSchema`'s compiled query
  type is the actual, real, app-specific thing worth asserting: is the
  field registered at all.
  """
  use ExUnit.Case, async: true

  test "libraryBooks field exists on the real compiled schema's query type" do
    query_type = Absinthe.Schema.lookup_type(Xaas.GraphqlSchema, :query)
    assert Map.has_key?(query_type.fields, :library_books)
  end
end
