defmodule Xaas.Library.EmbeddingsTest do
  use ExUnit.Case, async: true

  alias Xaas.Library.Embeddings

  test "embed/1 returns {:ok, vector} with 384 float dimensions for a real book synopsis" do
    synopsis =
      "A young orphan discovers a hidden library beneath her village and must decode " <>
        "ancient manuscripts to save her town from a spreading plague of forgetfulness."

    assert {:ok, vector} = Embeddings.embed(synopsis)

    assert is_list(vector)
    assert length(vector) == 384
    assert Enum.all?(vector, &is_float/1)
  end
end
