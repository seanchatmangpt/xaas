# Semantic Work Projection

The running demo now converts case standing into a typed work order.

| Case | Classification | Work standing | Obligation |
|---|---|---|---|
| known_firmware | KNOWN | READY_FOR_ENGINEER_DISPOSITION | prepare known-path diagnostic action |
| partial_firmware | PARTIAL | BLOCKED_ON_EVIDENCE | acquire timeout_waveform |
| novel_x | UNKNOWN | NOVEL_INVESTIGATION_REQUIRED | open bounded novel investigation |

The work order retains `SELECT_CONSTRUCT_ONLY` and `ENGINEER_DISPOSITION_REQUIRED`.

This is the product-level sJira behavior: missing semantic obligations become work automatically instead of requiring a human to translate an AI answer into a ticket.
