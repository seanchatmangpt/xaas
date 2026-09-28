defmodule Xaas.Sjira.AtlassianTest do
  use ExUnit.Case, async: true
  alias Xaas.Sjira.{Atlassian,AtlassianCursor,DeliveryBatch}
  defp item(id,deps\\[]), do: %{"identity"=>id,"project_key"=>"XAAS","issue_type"=>"Task","summary"=>"Deliver "<>id,"description"=>"semantic work","depends_on"=>deps,"labels"=>["Semantic Jira"]}
  test "deterministic create and update envelopes" do
    assert {:ok,a}=Atlassian.project(item("SJ-1")); assert {:ok,b}=Atlassian.project(item("SJ-1")); assert a==b
    assert a.method==:post; assert a.path=="/rest/api/3/issue"; assert a.idempotency_key=~"sha256:"
    assert {:ok,u}=Atlassian.project(Map.put(item("SJ-1"),"provider_key","XAAS-42"))
    assert u.method==:put; assert u.path=="/rest/api/3/issue/XAAS-42"; assert u.semantic_id=="SJ-1"
  end
  test "response recovery classes are explicit" do
    {:ok,e}=Atlassian.project(item("SJ-1"))
    assert Atlassian.classify_response(201,%{"key"=>"XAAS-1"},e).disposition==:accepted
    assert Atlassian.classify_response(400,%{"errors"=>%{"summary"=>"bad"}},e).disposition==:refused
    assert Atlassian.classify_response(412,%{},e).disposition==:reconcile
    assert Atlassian.classify_response(429,%{"retryAfter"=>2},e).retry_after_ms==2000
    assert Atlassian.classify_response(503,nil,e).retry==true
  end
  test "dependency closure orders and partitions" do
    assert {:ok,p}=DeliveryBatch.plan([item("C",["B"]),item("A"),item("B",["A"])],max_batch: 2)
    assert (for b<-p.batches,e<-b.envelopes,do: e.semantic_id)==["A","B","C"]
    assert Enum.map(p.batches,& &1.count)==[2,1]
    assert {:error,{:missing_dependencies,[{"A","X"}]}}=DeliveryBatch.plan([item("A",["X"])])
    assert {:error,{:dependency_cycle,["A","B"]}}=DeliveryBatch.plan([item("A",["B"]),item("B",["A"])])
  end
  test "checkpoint supports accepted, failed, JSON and resume" do
    {:ok,p}=DeliveryBatch.plan([item("A"),item("B"),item("C")])
    cp=DeliveryBatch.record(p.checkpoint,"A",%{disposition: :accepted}); cp=DeliveryBatch.record(cp,"B",%{disposition: :retry,retry: true})
    assert {:ok,decoded}=cp|>DeliveryBatch.checkpoint_json()|>DeliveryBatch.checkpoint_from_json(); assert decoded==cp
    assert {:ok,r}=DeliveryBatch.resume(p,cp,max_batch: 1,retry_failed: true); assert r.count==2
  end
  test "offset and token cursors normalize pages" do
    o=AtlassianCursor.initial(mode: :offset)
    assert {:ok,o,[1,2]}=AtlassianCursor.advance(o,%{"issues"=>[1,2],"startAt"=>0,"maxResults"=>2,"total"=>3}); refute o.exhausted
    assert {:ok,o,[3]}=AtlassianCursor.advance(o,%{"issues"=>[3],"startAt"=>2,"maxResults"=>2,"total"=>3}); assert o.exhausted
    t=AtlassianCursor.initial(mode: :token)
    assert {:ok,t,[:a]}=AtlassianCursor.advance(t,%{"values"=>[:a],"nextPageToken"=>"next"}); assert AtlassianCursor.params(t,50).nextPageToken=="next"
  end
end
