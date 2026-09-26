alias Xaas.Ultracode.SubstitutionPolicy

policy = SubstitutionPolicy.policy()

unless policy.admitted_standing == "ALIVE", do: raise("unexpected admitted standing")
unless policy.unknown_standing == "UNKNOWN", do: raise("UNKNOWN must remain explicit")
unless policy.required_fields == MapSet.new(~w(exactSubject verifierEvidenceDigest replayDigest standing)),
  do: raise("required qualification fields drifted")

subject = "seanchatmangpt/xaas@" <> String.duplicate("a", 40)
:ok = SubstitutionPolicy.admit_receipt(%{exact_subject: subject, standing: "ALIVE"})
{:error, :qualification_unknown} =
  SubstitutionPolicy.admit_receipt(%{exact_subject: subject, standing: "UNKNOWN"})

ttl = File.read!("priv/ontology/interchangeable-part-qualification.ttl")

for field <- ~w(exactSubject verifierEvidenceDigest replayDigest standing) do
  changed =
    ttl
    |> String.split("\n")
    |> Enum.reject(&String.contains?(&1, "ce:requiredQualificationField ce:#{field}"))
    |> Enum.join("\n")

  try do
    SubstitutionPolicy.parse!(changed)
    raise("field removal was accepted: #{field}")
  rescue
    ArgumentError -> :ok
  end
end

IO.puts("ALIVE substitution-policy court")
