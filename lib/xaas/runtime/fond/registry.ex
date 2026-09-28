defmodule Xaas.Runtime.FOND.Registry do
 use GenServer
 def start_link(opts \\ []), do: GenServer.start_link(__MODULE__,%{},Keyword.put_new(opts,:name,__MODULE__))
 def register(s \\ __MODULE__,id,e), do: GenServer.call(s,{:register,id,e})
 def all(s \\ __MODULE__), do: GenServer.call(s,:all)
 def init(s), do: {:ok,s}
 def handle_call({:register,id,e},_,s), do: {:reply,:ok,Map.put(s,id,e)}
 def handle_call(:all,_,s), do: {:reply,s,s}
end
