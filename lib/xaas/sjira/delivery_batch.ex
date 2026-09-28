defmodule Xaas.Sjira.DeliveryBatch do
  @moduledoc "Pure dependency ordering, bounded batching, checkpoints, and resume."
  alias Xaas.Sjira.Atlassian

  def plan(items, opts \\ []) when is_list(items) do
    max=Keyword.get(opts,:max_batch,50)
    with :ok<-batch_size(max), {:ok,idx}<-index(items), {:ok,ordered}<-topo(idx), {:ok,envs}<-project(ordered,opts) do
      digest=Atlassian.digest(Enum.map(envs,& &1.idempotency_key))
      {:ok,%{version: 1,digest: digest,count: length(envs),batches: chunks(envs,max),
        checkpoint: %{version: 1,batch_digest: digest,completed: [],pending: Enum.map(envs,& &1.semantic_id),failed: %{}}}}
    end
  end

  def resume(plan,cp,opts \\ []) do
    if cp.batch_digest != plan.digest, do: {:error,{:checkpoint_digest_mismatch,cp.batch_digest,plan.digest}}, else: begin_resume(plan,cp,opts)
  end
  defp begin_resume(plan,cp,opts) do
    completed=MapSet.new(cp.completed); retry? = Keyword.get(opts,:retry_failed,true)
    envs=plan.batches|>Enum.flat_map(& &1.envelopes)|>Enum.reject(&MapSet.member?(completed,&1.semantic_id))
    envs=if retry?,do: envs,else: Enum.reject(envs,&Map.has_key?(cp.failed,&1.semantic_id))
    max=Keyword.get(opts,:max_batch,50)
    {:ok,%{plan|count: length(envs),batches: chunks(envs,max)}}
  end
  def record(cp,id,%{disposition: :accepted}), do: %{cp|completed: Enum.sort(Enum.uniq([id|cp.completed])),pending: List.delete(cp.pending,id),failed: Map.delete(cp.failed,id)}
  def record(cp,id,outcome), do: %{cp|pending: List.delete(cp.pending,id),failed: Map.put(cp.failed,id,outcome)}
  def complete?(cp), do: cp.pending==[] and map_size(cp.failed)==0
  def checkpoint_json(cp), do: Jason.encode!(cp)
  def checkpoint_from_json(bytes) do
    with {:ok,m}<-Jason.decode(bytes),1<-m["version"],d when is_binary(d)<-m["batch_digest"],
      c when is_list(c)<-m["completed"],p when is_list(p)<-m["pending"],f when is_map(f)<-m["failed"] do
      {:ok,%{version: 1,batch_digest: d,completed: c,pending: p,failed: f}}
    else {:error,r}->{:error,{:invalid_checkpoint_json,r}}; _->{:error,:invalid_checkpoint} end
  end

  defp index(items), do: Enum.reduce_while(items,{:ok,%{}},fn item,{:ok,acc}->
    id=item["identity"]||item[:identity]
    cond do is_nil(id)->{:halt,{:error,{:missing_identity,item}}}; Map.has_key?(acc,to_string(id))->{:halt,{:error,{:duplicate_identity,to_string(id)}}}; true->{:cont,{:ok,Map.put(acc,to_string(id),item)}} end
  end)
  defp topo(idx) do
    ids=Map.keys(idx)|>MapSet.new()
    missing=for {id,item}<-idx,d<-List.wrap(item["depends_on"]||item[:depends_on])|>Enum.map(&to_string/1),not MapSet.member?(ids,d),do: {id,d}
    if missing != [],do: {:error,{:missing_dependencies,missing}},else: kahn(idx,Map.new(idx,fn {id,item}->{id,MapSet.new(List.wrap(item["depends_on"]||item[:depends_on])|>Enum.map(&to_string/1))} end),[])
  end
  defp kahn(idx,deps,acc) when map_size(deps)==0, do: {:ok,Enum.map(Enum.reverse(acc),&Map.fetch!(idx,&1))}
  defp kahn(idx,deps,acc) do
    ready=deps|>Enum.filter(fn {_,s}->MapSet.size(s)==0 end)|>Enum.map(&elem(&1,0))|>Enum.sort()
    if ready==[],do: {:error,{:dependency_cycle,Map.keys(deps)|>Enum.sort()}},else: (
      rs=MapSet.new(ready); rest=Map.drop(deps,ready); next=Map.new(rest,fn {id,s}->{id,MapSet.difference(s,rs)} end)
      kahn(idx,next,Enum.reverse(ready)++acc))
  end
  defp project(items,opts), do: (Enum.reduce_while(items,{:ok,[]},fn item,{:ok,acc}->case Atlassian.project(item,opts) do {:ok,e}->{:cont,{:ok,[e|acc]}}; {:error,r}->{:halt,{:error,{:projection_failed,item["identity"]||item[:identity],r}}} end end)|>case do {:ok,r}->{:ok,Enum.reverse(r)}; x->x end)
  defp chunks(envs,max), do: envs|>Enum.chunk_every(max)|>Enum.with_index(1)|>Enum.map(fn {es,i}->%{index: i,digest: Atlassian.digest(Enum.map(es,& &1.idempotency_key)),count: length(es),envelopes: es} end)
  defp batch_size(n) when is_integer(n) and n>0 and n<=100, do: :ok
  defp batch_size(n), do: {:error,{:invalid_batch_size,n}}
end
