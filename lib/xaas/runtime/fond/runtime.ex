defmodule Xaas.Runtime.FOND.Runtime do
 def new(es \\ []), do: Xaas.Runtime.FOND.Graph.new(es)
 def dispatch(g,c,i,opts \\ []), do: Xaas.Runtime.FOND.Router.dispatch(g,c,i,Xaas.Runtime.FOND.Policy.new(opts))
end
