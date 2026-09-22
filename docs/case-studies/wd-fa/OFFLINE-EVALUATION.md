# Offline Evaluation Report

The XaaS WD reference executes six repository-local controls:

1. known case is admitted;
2. partial case stays unadmitted;
3. novel case remains UNKNOWN;
4. self-certification is refused;
5. tampered receipt is refused;
6. independently verified replay becomes KNOWN.

The dedicated workflow emits `wd-cs2-evaluation.json`.

Production outcome metrics such as MTTR, false-KNOWN rate and engineer touches are explicitly emitted as `UNMEASURED`, preserving the evidence ceiling.
