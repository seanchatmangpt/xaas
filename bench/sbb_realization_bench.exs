# Real benchmark for Xaas.Ultracode.SbbRealization (RFC v26.9.26).
# Pure in-process court: no DB, no network. Run with either env:
#
#   MIX_ENV=test mix run --no-start bench/sbb_realization_bench.exs
#   MIX_ENV=dev  mix run --no-start bench/sbb_realization_bench.exs  # + Benchee
#
# Always prints a deterministic median/p99 table (:timer.tc over fixed
# iteration counts); additionally runs Benchee when it is loaded (:dev only).
#
# Measures admit (SELECT), realize (CONSTRUCT), ledger deliver (append +
# duplicate), provider substitution, and crash/restart replay of a 1_000-entry
# ledger. The regression bound is enforced by the deterministic timing test in
# test/xaas/ultracode/sbb_realization_test.exs ("benchmark regression bound").

alias Xaas.Ultracode.SbbRealization, as: S
alias Xaas.Ultracode.SbbRealization.{Abb, ArchitectureContract, Ledger, Manifest}
alias Xaas.Ultracode.SubstitutionCourt.{PartPassport, QualificationReceipt, WorkIdentity}

d = fn c -> "sha256:" <> String.duplicate(c, 64) end
sha = fn c -> String.duplicate(c, 40) end

abb = %Abb{
  abb_id: "abb:q",
  exact_subject: "o/xaas@#{sha.("a")}",
  layer: :runtime,
  capability: "queue"
}

contract = %ArchitectureContract{
  contract_id: "contract:q/1",
  abb_id: "abb:q",
  exact_subject: "o/xaas@#{sha.("a")}",
  allowed_behaviors: [:enqueue, :dequeue, :ack],
  authority_ceiling: [:observe, :select, :construct],
  consequence_schema_digest: d.("1"),
  receipt_schema_digest: d.("2")
}

mk = fn id, s, q ->
  impl = %PartPassport{
    part_id: id,
    kind: :provider,
    exact_subject: "o/#{id}@#{s}",
    part_digest: d.("6"),
    producer_digest: d.("4"),
    consequence_schema_digest: d.("1"),
    receipt_schema_digest: d.("2"),
    authority_ceiling: [:observe, :select, :construct],
    qualification_receipt: q
  }

  %Manifest{
    sbb_id: "sbb:" <> id,
    abb_id: "abb:q",
    abb_digest: S.abb_digest(abb),
    contract_subject: contract.exact_subject,
    contract_digest: S.contract_digest(contract),
    qualification_digest: S.qualification_digest(q),
    qualification_receipt: q,
    implementation: impl,
    requested_behaviors: [:enqueue, :ack],
    requested_authority: [:select, :construct]
  }
end

qa = %QualificationReceipt{
  receipt_digest: d.("3"),
  verifier_evidence_digest: d.("4"),
  replay_digest: d.("5"),
  passed: true
}

qb = %{qa | receipt_digest: d.("7")}
ma = mk.("provider-a", sha.("b"), qa)
mb = mk.("provider-b", sha.("c"), qb)
{:ok, a} = S.admit(ma, abb, contract)
{:ok, b} = S.admit(mb, abb, contract)

work = %WorkIdentity{
  work_order_id: "urn:work:bench",
  exact_subject: "o/xaas@#{sha.("a")}",
  origin_authority: "sj:bench",
  consequence_schema_digest: d.("1"),
  receipt_schema_digest: d.("2"),
  execution_manifest_digest: d.("3")
}

{:ok, r1} = S.realize(a, work, 1)
{:admitted, l1} = Ledger.deliver(Ledger.new(), r1)

big =
  Enum.reduce(1..1_000, Ledger.new(), fn i, l ->
    {:ok, r} = S.realize(a, work, i)
    {:admitted, l} = Ledger.deliver(l, r)
    l
  end)

persisted = Ledger.entries(big)

jobs = %{
  "admit" => fn -> {:ok, _} = S.admit(ma, abb, contract) end,
  "realize" => fn -> {:ok, _} = S.realize(a, work, 7) end,
  "deliver_append" => fn -> {:admitted, _} = Ledger.deliver(Ledger.new(), r1) end,
  "deliver_duplicate" => fn -> {:duplicate, _} = Ledger.deliver(l1, r1) end,
  "substitute" => fn -> {:ok, _} = S.substitute(a, b, work) end,
  "replay_1000" => fn -> {:ok, _} = Ledger.replay(persisted) end
}

iters = fn
  "replay_1000" -> 200
  _ -> 5_000
end

IO.puts("job\titers\tmedian_us\tp99_us")

for {name, f} <- Enum.sort(jobs) do
  for _ <- 1..100, do: f.()
  n = iters.(name)
  samples = for(_ <- 1..n, do: elem(:timer.tc(f), 0)) |> Enum.sort()
  median = Enum.at(samples, div(n, 2))
  p99 = Enum.at(samples, min(n - 1, round(n * 0.99)))
  IO.puts("#{name}\t#{n}\t#{median}\t#{p99}")
end

if Code.ensure_loaded?(Benchee) do
  apply(Benchee, :run, [jobs, [time: 2, warmup: 1, memory_time: 0.5]])
end
