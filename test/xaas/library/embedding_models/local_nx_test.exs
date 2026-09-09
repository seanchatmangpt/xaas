defmodule Xaas.Library.EmbeddingModels.LocalNxTest do
  use ExUnit.Case, async: true

  alias Xaas.Library.EmbeddingModels.LocalNx

  @dimensions 384

  test "generate/2 returns {:ok, vectors} with @dimensions-length vectors for real strings" do
    texts = [
      "The quick brown fox jumps over the lazy dog",
      "Elixir is a dynamic, functional language for building scalable applications",
      "xaas library embedding pipeline"
    ]

    assert {:ok, vectors} = LocalNx.generate(texts, [])
    assert length(vectors) == length(texts)

    for vector <- vectors do
      assert is_list(vector)
      assert length(vector) == @dimensions
      assert Enum.all?(vector, &is_float/1)
    end
  end
end
