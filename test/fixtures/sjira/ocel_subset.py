#!/usr/bin/env python3
"""Deterministic real subset of a v26.9.22 OCEL log: every agent span in REPOS
(agent_started + agent_completed) plus its first TOOLS tool_call events, and the
objects those events reference. Usage: ocel_subset.py IN OUT"""
import json, sys
REPOS = {"repo:ash_a2a", "repo:autofde-lab", "repo:ferroplan", "repo:gymact", "repo:xaas"}
TOOLS = 2
src, out = sys.argv[1], sys.argv[2]
d = json.load(open(src))
keep_agents = set()
for e in d["events"]:
    if e["type"] in ("agent_started", "agent_completed"):
        rel = {r["qualifier"]: r["objectId"] for r in e["relationships"]}
        if rel.get("repo") in REPOS:
            keep_agents.add(rel["actor"])
events, per_agent = [], {}
for e in d["events"]:
    actors = [r["objectId"] for r in e["relationships"] if r["qualifier"] == "actor"]
    if not actors or actors[0] not in keep_agents:
        continue
    if e["type"] == "tool_call":
        n = per_agent.get(actors[0], 0)
        if n >= TOOLS:
            continue
        per_agent[actors[0]] = n + 1
    events.append(e)
ref = {r["objectId"] for e in events for r in e["relationships"]}
objects = [o for o in d["objects"] if o["id"] in ref]
ref |= {r["objectId"] for o in objects for r in o["relationships"]}
objects = [o for o in d["objects"] if o["id"] in ref]
ocel = {
    "objectTypes": [t for t in d["objectTypes"] if any(o["type"] == t["name"] for o in objects)],
    "eventTypes": [t for t in d["eventTypes"] if any(e["type"] == t["name"] for e in events)],
    "objects": sorted(objects, key=lambda o: o["id"]),
    "events": sorted(events, key=lambda e: (e["time"], e["id"])),
}
open(out, "w").write(json.dumps(ocel, indent=1, sort_keys=True) + "\n")
print(f"subset objects={len(objects)} events={len(events)} agents={len(keep_agents)} -> {out}")
