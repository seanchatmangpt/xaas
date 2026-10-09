# Round 6 — Standing Note

## Status

**repair-ALIVE; canonical gate pending post-[130] re-audit.**

## Repair reproduced at repair-time extractor

The [60] repair is reproduced at the repair-time extractor. Witness:
`/tmp/m8-xaas-final/audit.5eb.txt`, exit 0:

```
PASS  coverage value=0.9509 threshold=0.9000
PASS  phantom value=0.0000 (threshold=0.0010)
PASS  density value=1.0000 threshold=0.6500
audit_exit=0
```

## HEAD-extractor refusal witnessed

The HEAD extractor is refused (witness `/tmp/m8-xaas-final/audit.head.txt`,
exit 1):

```
FAIL  phantom value=0.2333 threshold=0.0010
      offending_claims=[13601, 2316, 2317]
audit_exit=1
```

Class: [130] surface-expansion.

## [130] str_keys + config-surface docs landed

[130] str_keys fix + config-surface reference docs landed at `3ed88241`
("docs(reference): config-surface reference (generated)").

## Official post-[130] re-audit

Pending. Until that re-audit passes, standing is repair-ALIVE, not canonical.
