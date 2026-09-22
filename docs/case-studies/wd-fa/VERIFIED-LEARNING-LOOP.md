# Verified Learning Loop

The live demo now uses an explicit independent repository-local verification receipt before admitting the MachineExperience fixture.

```
UNKNOWN
→ candidate
→ repository-local observed disposition
→ independent verifier
→ SHA-256 receipt
→ MachineExperience
→ future KNOWN replay
```

Negative controls refuse:

- producer/verifier self-certification;
- receipt tampering;
- authority-scope tampering;
- disposition mismatch.

The receipt is bounded to `REPO_LOCAL_FIXTURE`. It does not represent a WD production engineering disposition.
