defmodule ExNounVerbCli.IntrospectTest do
  use ExUnit.Case, async: true

  alias ExNounVerbCli.{Introspect, JsonOutput}
  alias ExNounVerbCli.Test.CalcRegistry

  test "manifest/1 describes every verb in the real registry with JSON-ready shapes" do
    manifest = Introspect.manifest(CalcRegistry)

    verbs = manifest["verbs"]
    assert length(verbs) == length(CalcRegistry.list_verbs())

    add = Enum.find(verbs, &(&1["verb"] == "add"))
    assert add["noun"] == "calc"
    assert add["schema"] == %{"x" => "integer", "y" => "integer"}
    assert add["required"] == ["x", "y"]
    assert add["positional"] == []
    assert add["handler"] == "ExNounVerbCli.Test.CalcFixture.add/2"

    boom = Enum.find(verbs, &(&1["verb"] == "boom"))
    assert boom["schema"] == %{}
    assert boom["handler"] == "ExNounVerbCli.Test.CalcFixture.boom/0"
  end

  test "manifest/1 indexes verbs by noun and documents the chaining tokens" do
    manifest = Introspect.manifest(CalcRegistry)

    assert manifest["nouns"] == %{"calc" => ["add", "boom", "echo-profile", "multiply"]}

    tokens = Enum.map(manifest["chaining"]["tokens"], & &1["token"])
    assert tokens == ["@-", "@-::a.b.c", "@{N.path}"]
    assert manifest["chaining"]["group_separator"] == "++"
  end

  test "manifest/2 filters to one noun's verbs; an unknown noun yields an empty verb table" do
    manifest = Introspect.manifest(CalcRegistry, "calc")

    assert Enum.all?(manifest["verbs"], &(&1["noun"] == "calc"))
    assert manifest["nouns"] == %{"calc" => ["add", "boom", "echo-profile", "multiply"]}

    assert Introspect.manifest(CalcRegistry, "nope")["verbs"] == []
  end

  test "the manifest round-trips through the real JSON envelope, fully serialized" do
    json = JsonOutput.encode_string(JsonOutput.encode(:ok, Introspect.manifest(CalcRegistry)))

    assert %{
             "status" => "ok",
             "result" => %{"schema" => schema, "verbs" => [%{"verb" => "add"} | _]}
           } = Jason.decode!(json)

    assert schema == "https://ggen.dev/ex-noun-verb-cli/introspect/v1"
  end
end
