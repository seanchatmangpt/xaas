import sys
p='lib/xaas/ultracode/semantic_work/admission_binding.ex'
s=open(p).read()
m=sys.argv[1]
muts={
 'M2-infer-undeclared': ('      {nil, _snapshot} -> refuse(:digest_form_undeclared)', '      {nil, _snapshot} -> {:ok, "sjira-digest/2"}'),
 'M3-no-definition-self-check': ('    if @digest_forms[form].embeds_definition_digest do\n      recomputed = definition_digest(snapshot, form)', '    if false do\n      recomputed = definition_digest(snapshot, form)'),
 'M4-no-form-shape': ('    if ok?, do: :ok, else: refuse({:digest_form_mismatch, form, :definition_digest})', '    _ = ok?\n    :ok'),
 'M5-v2-computes-legacy': ('      snapshot_drop: ["definition_digest" | @legacy_digest_fields],', '      snapshot_drop: @legacy_digest_fields,'),
}
old,new=muts[m]
assert s.count(old)==1, m
open(p,'w').write(s.replace(old,new))
print('mutated',m)
