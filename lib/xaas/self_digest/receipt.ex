defmodule Xaas.SelfDigest.Receipt do
  @enforce_keys [:id,:subject,:work_id,:before,:after,:evidence]
  defstruct [:id,:subject,:work_id,:before,:after,:evidence,:previous,:authority]
  def seal(subject,work_id,before,after,evidence,opts \\ []) do
    prev=Keyword.get(opts,:previous)
    id=:crypto.hash(:sha256,:erlang.term_to_binary({subject,work_id,before,after,Enum.map(evidence,& &1.digest),prev},[:deterministic])) |> Base.encode16(case: :lower)
    %__MODULE__{id:id,subject:subject,work_id:work_id,before:before,after:after,evidence:evidence,previous:prev,authority:Keyword.get(opts,:authority,:construct_only)}
  end
  def replayable?(r), do: is_binary(r.id) and not is_nil(r.before) and not is_nil(r.after)
end
