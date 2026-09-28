defmodule Xaas.Runtime.FOND.Router do
 alias Xaas.Runtime.FOND.{Executor,Policy}
 def dispatch(g,c,i,p \\ %Policy{}), do: case Executor.run(g,c,i) do {:fail_local,id,r,g2} when p.retry_local?->{:retry_local,id,r,g2}; x->x end
end
