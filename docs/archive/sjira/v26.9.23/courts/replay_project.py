#!/usr/bin/env python3
"""Episode-time replay state projector (GC-26.9.23 GC23-10; lane V23-R).

An implementation independent of Xaas.Ultracode.SemanticReplay: it reads
ONLY what the episode drive wrote at episode time -- work.json (the work
graph), frontier_after.json (the frontier the drive ended on), receipt.json
(the sealed XaaS receipt), ledger.ndjson (the TransitionLog) and drive.json
(the drive record: subject ref, head, no-LLM guard) -- and projects the state
a cold replay must reconstruct (schema xaas/semantic-replay-state/v1), with
the digest sha256(canonical JSON), canonical = sort_keys, compact, UTF-8.

    replay_project.py <episode_dir>                 print the record JSON
    replay_project.py <episode_dir> --check RECORD  exit 0 iff RECORD equals
                                                    the projection (state and
                                                    digest), else exit 1

No graph side, no git, no network: a cold replay that agrees with this
projection reached, from receipts + TransitionLog + work graph + git refs, the
state the episode recorded.
"""
import hashlib
import json
import sys

SCHEMA = "xaas/semantic-replay-state/v1"
RECORD = "xaas/semantic-replay-record/v1"
SOURCES = ["work.json", "frontier_after.json", "receipt.json", "ledger.ndjson", "drive.json"]


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def digest(value):
    return "sha256:" + hashlib.sha256(canonical(value).encode("utf-8")).hexdigest()


def project(ep):
    load = lambda name: json.load(open(f"{ep}/{name}", encoding="utf-8"))
    work = load("work.json")
    after = load("frontier_after.json")
    receipt = load("receipt.json")
    drive = load("drive.json")
    events = [json.loads(line) for line in open(f"{ep}/ledger.ndjson", encoding="utf-8") if line.strip()]
    events.sort(key=lambda e: e.get("seq") or 0)

    bridge = receipt["bridge"]
    identity = bridge["identity"]
    event = [e for e in events if e["identity"] == identity][-1]

    evidence = [{
        "identity": identity,
        "receipt_digest": receipt["receipt_digest"],
        "base_sha": bridge["base_sha"],
        "head": receipt["final_head"],
        "outcome": receipt["outcome"],
        # at episode time the receipt head IS the subject tip (drive.json)
        "current": drive["subject"]["head"] == receipt["final_head"],
        "changed_paths": [],
        "admitted": True,
        "event_digest": event["event_digest"],
        "standing": event["to"],
    }]

    projection = {}
    for e in events:
        projection[e["identity"]] = e["to"]

    standings = after["standings"]
    return {
        "schema": SCHEMA,
        "episode": work["episode"],
        "checkpoint": work["checkpoint"],
        "subject": {
            "repositories": sorted({wo["repository"] for wo in work["work_orders"]}),
            "ref": drive["subject"]["pinned"],
            "tip": drive["subject"]["head"],
        },
        "evidence": evidence,
        "standing": standings,
        "completed": sorted(i for i, s in standings.items() if s == "ALIVE"),
        "frontier": {
            "eligible": [e["identity"] for e in after["eligible"]],
            "blocked": [{"identity": b["identity"], "reason": b["reason"]} for b in after["blocked"]],
            "events": after["events"],
            "ledger_tail": after["ledger_tail"],
        },
        "replay": {"status": "KNOWN_REPLAY", "standing_projection": projection},
        "divergence": [],
    }


def record(ep):
    state = project(ep)
    files = []
    for name in SOURCES:
        data = open(f"{ep}/{name}", "rb").read()
        files.append({"path": name, "sha256": "sha256:" + hashlib.sha256(data).hexdigest()})
    return {
        "schema": RECORD,
        "digest": digest(state),
        "state": state,
        "projected_from": files,
        "projector": "docs/sjira/v26.9.23/courts/replay_project.py",
    }


def main(argv):
    if len(argv) == 2:
        print(canonical(record(argv[1])))
        return 0
    if len(argv) == 4 and argv[2] == "--check":
        want = record(argv[1])
        got = json.load(open(argv[3], encoding="utf-8"))
        if got != want:
            for key in sorted(set(want) | set(got)):
                if want.get(key) != got.get(key):
                    print(f"REFUSED: record field {key} differs from the episode-time projection")
            return 1
        print(f"record matches the episode-time projection: {want['digest']}")
        return 0
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
