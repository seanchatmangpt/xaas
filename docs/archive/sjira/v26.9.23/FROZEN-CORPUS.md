# FROZEN-CORPUS

This directory is a frozen v26.9.23 evidence corpus. It is read-only evidence:
no descriptor, receipt, or ledger file here is edited in place.

## Descriptors predate the three-key requires law

The committed episode descriptors carry the old four-key `bridge.requires`
map (`{courts, acceptance, falsifiers, evidence}`):

- `successor/intake/descriptor.json`
- `episodes/fmt-1/descriptor.json`
- `episodes/me-1/drive/descriptor.json`
- `episodes/me-2/drive/descriptor.json`

The current law is
`Xaas.Ultracode.SemanticWork.AdmissionBinding.bridge_requires_checks/2`
(`lib/xaas/ultracode/semantic_work/admission_binding.ex`), which demands exact
map equality over exactly `{courts, acceptance, falsifiers}`. A four-key
requires map fails that equality, so these descriptors cannot replay under
snapshot binding. Their `requires` shape predates the normalization introduced
by the ggen lineage "ggen descriptor.ex requires normalization, 2d42251".

## Replay

Replay requires regeneration through the current pipeline (descriptor
emission + snapshot binding), not in-place edits to this corpus.

## Receipt files

- `episodes/*/receipt.r.json` (fmt-1, me-1/drive, me-2/drive): hand-extended
  in v26.10.1-loop (X2); they validate ADMITTED under the fleet validator.
- `episodes/*/receipt.json`: native receipts, untouched digest anchors. Never
  rewritten; freeze-and-annotate is the lawful treatment.
