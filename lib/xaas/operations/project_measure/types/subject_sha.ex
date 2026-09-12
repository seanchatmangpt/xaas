defmodule Xaas.Operations.ProjectMeasure.Types.SubjectSha do
  @moduledoc """
  Ash type for an exact Git commit object identity.

  The type admits exactly forty hexadecimal characters. It deliberately does not
  resolve refs, branch names, tags, prefixes, or synthetic merge identities.
  """

  use Ash.Type.NewType,
    subtype_of: :string,
    constraints: [match: ~r/\A[0-9a-fA-F]{40}\z/, min_length: 40, max_length: 40]
end
