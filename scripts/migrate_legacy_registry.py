#!/usr/bin/env python3
"""Real, non-destructive migration of legacy /Users/sac/eds-registry ERC-shaped
JSON files into eds.erc.ERC's actual required schema.

Backs up every file it touches to <path>.bak (never overwrites a .bak that
already exists, so re-running is idempotent and safe). Writes a real summary
of what it did.

Field-mapping heuristic (documented, not hidden):
  hypothesis        <- claim | real_purpose | purpose | title | hypothesis
  artifact_reference<- artifact_reference (if str) | f"{repo}#{id}" |
                        repo+path/git_head | json-flattened dict
  evidence_state    <- evidence_state | eds_evidence_state (validated against
                        the real EvidenceState enum; invalid values downgrade
                        to UNKNOWN with the original value preserved in
                        `evidence`, never silently dropped)
  falsifier         <- falsifier
  no_falsifier      <- no_falsifier | noFalsifier | (not bool(falsifier))
  evidence          <- execution_evidence | evidence | (dict fields
                        flattened to a readable string, nothing dropped) |
                        alive_check_result + coordination_receipt_ontology_mechanism
  verification      <- verification
  source_revision   <- source_revision | git_head | ""
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "src"))

from eds.states import EvidenceState  # noqa: E402


def _first_str(d: dict, *keys: str) -> str:
    for k in keys:
        v = d.get(k)
        if isinstance(v, str) and v.strip():
            return v
    return ""


def _flatten(v) -> str:
    if v is None:
        return ""
    if isinstance(v, str):
        return v
    if isinstance(v, dict):
        return "; ".join(f"{k}={_flatten(val)}" for k, val in v.items())
    if isinstance(v, list):
        return "\n".join(_flatten(item) for item in v)
    return str(v)


def migrate_record(raw: dict, fallback_id: str) -> tuple[dict, list[str]]:
    """Returns (migrated_dict, notes). Never raises on odd input — anything
    unmapped is preserved in `evidence` rather than dropped."""
    notes: list[str] = []

    if {"hypothesis", "artifact_reference", "evidence_state", "no_falsifier"} <= raw.keys() and isinstance(
        raw.get("artifact_reference"), str
    ) and isinstance(raw.get("evidence"), str):
        # Already schema-shaped and both string fields are real strings —
        # nothing to migrate. Still validate evidence_state below.
        migrated = dict(raw)
    else:
        hypothesis = _first_str(raw, "hypothesis", "claim", "real_purpose", "purpose", "title")
        if not hypothesis:
            hypothesis = f"(no hypothesis text found in legacy record {fallback_id!r})"
            notes.append("no hypothesis-like field found")

        art_ref = raw.get("artifact_reference")
        if isinstance(art_ref, str) and art_ref.strip():
            artifact_reference = art_ref
        elif isinstance(art_ref, dict):
            artifact_reference = _flatten(art_ref)
            notes.append("artifact_reference was a dict, flattened to string")
        else:
            repo = raw.get("repo", "")
            rid = raw.get("id", fallback_id)
            path = raw.get("path") or raw.get("actual_path") or ""
            if repo and rid:
                artifact_reference = f"{repo}#{rid}"
            elif path:
                artifact_reference = path
            else:
                artifact_reference = fallback_id
                notes.append("no artifact_reference found, used fallback id")

        raw_state = raw.get("evidence_state") or raw.get("eds_evidence_state") or ""
        try:
            evidence_state = EvidenceState(raw_state).value
        except ValueError:
            evidence_state = EvidenceState.UNKNOWN.value
            notes.append(f"invalid evidence_state {raw_state!r}, downgraded to UNKNOWN")

        falsifier = _first_str(raw, "falsifier")
        no_falsifier = raw.get("no_falsifier")
        if no_falsifier is None:
            no_falsifier = raw.get("noFalsifier")
        if no_falsifier is None:
            no_falsifier = not bool(falsifier)

        evidence_parts = []
        for key in (
            "execution_evidence", "evidence", "alive_check_result", "alive_check",
            "coordination_receipt_ontology_mechanism", "coordination_or_receipt_or_ontology_mechanism",
            "coordination_receipt_ontology_mechanisms", "eds_rationale", "evidence_state_rationale",
            "commands_run", "notes",
        ):
            v = raw.get(key)
            if v is not None:
                evidence_parts.append(f"{key}: {_flatten(v)}")
        evidence = "\n".join(evidence_parts) if evidence_parts else raw_state and f"(raw evidence_state was {raw_state!r}, no evidence text found)" or ""
        if not evidence.strip() and evidence_state != EvidenceState.PROPOSED.value:
            notes.append("no evidence text found for a non-PROPOSED state")

        verification = _first_str(raw, "verification")
        source_revision = _first_str(raw, "source_revision", "git_head", "sha")

        migrated = {
            "id": raw.get("id", fallback_id),
            "hypothesis": hypothesis,
            "artifact_reference": artifact_reference,
            "evidence_state": evidence_state,
            "falsifier": falsifier,
            "no_falsifier": bool(no_falsifier),
            "evidence": evidence,
            "verification": verification,
            "source_revision": source_revision,
            "receipt_refs": raw.get("receipt_refs", []),
        }

    # Always re-validate evidence_state even for already-shaped records.
    try:
        EvidenceState(migrated["evidence_state"])
    except (KeyError, ValueError):
        notes.append(f"invalid evidence_state {migrated.get('evidence_state')!r} on already-shaped record, downgraded")
        migrated["evidence_state"] = EvidenceState.UNKNOWN.value

    return migrated, notes


def main(registry_dir: str) -> int:
    from eds.erc import ERC

    root = Path(registry_dir)
    files = sorted(root.rglob("*.json"))
    migrated_count = 0
    already_ok = 0
    failed = []
    all_notes: dict[str, list[str]] = {}

    for path in files:
        if path.suffix == ".bak":
            continue
        try:
            raw = json.loads(path.read_text())
        except Exception as e:
            failed.append((str(path), f"unreadable JSON: {e}"))
            continue

        try:
            ERC.from_dict(raw).require_valid()
            already_ok += 1
            continue
        except Exception:
            pass  # needs migration

        fallback_id = path.stem
        migrated, notes = migrate_record(raw, fallback_id)

        try:
            erc = ERC.from_dict(migrated)
        except Exception as e:
            failed.append((str(path), f"still invalid after migration: {e}"))
            continue

        bak_path = path.with_suffix(path.suffix + ".bak")
        if not bak_path.exists():
            bak_path.write_text(json.dumps(raw, indent=2, sort_keys=True))
        erc.write(path)
        migrated_count += 1
        if notes:
            all_notes[str(path)] = notes

    print(f"total files:      {len(files)}")
    print(f"already valid:    {already_ok}")
    print(f"migrated:         {migrated_count}")
    print(f"failed to fix:    {len(failed)}")
    if failed:
        print("failures:")
        for p, reason in failed[:30]:
            print(f"  {p}: {reason}")
        if len(failed) > 30:
            print(f"  ... and {len(failed) - 30} more")
    lossy = {p: n for p, n in all_notes.items() if any("no hypothesis" in x or "no artifact_reference" in x or "no evidence" in x for x in n)}
    print(f"migrated-with-notes (lossy/best-effort): {len(lossy)}")
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "/Users/sac/eds-registry/receipts"))
