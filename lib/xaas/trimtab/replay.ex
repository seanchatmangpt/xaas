defmodule Xaas.Trimtab.Replay do
  alias Xaas.Trimtab.{Hash, Receipt, Subject}

  def verify(%Receipt{} = r, %Subject{digest: d}, i, o) do
    cond do
      r.subject_digest != d -> {:error, :subject_mismatch}
      r.input_digest != Hash.sha256(i) -> {:error, :input_drift}
      r.output_digest != Hash.sha256(o) -> {:error, :output_drift}
      true -> :ok
    end
  end
end
