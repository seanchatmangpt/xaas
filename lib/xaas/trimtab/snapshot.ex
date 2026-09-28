defmodule Xaas.Trimtab.Snapshot do
  alias Xaas.Trimtab.{Hash,ContextWindow}
  def of(%ContextWindow{}=w) do
    p=%{subject:w.subject.digest,observations:Enum.map(w.observations,& &1.digest),budget:%{items:w.budget.max_items,bytes:w.budget.max_bytes}}
    Map.put(p,:digest,Hash.sha256(p))
  end
end