#!/usr/bin/env python3
"""Live OCEL 2.0 bridge: xaas/zcode OCEL -> beam4pm ingest (POST /ocel/events, /ocel/objects).

Sources (both OCEL 2.0 JSON):
  * priv/ocel/ash-actions.ndjson  -- xaas OcelAshEmitter, one OCEL doc per line, appended live
  * ~/.zcode/ocel/*.jsonocel      -- zcode session logs (tap writes atomically at session end)
Only data appended after start is forwarded (--from-start to replay). Prints per-type counts
and ingest refusals; exit with ctrl-c. Hand-written residue: UNSUPPORTED(generator-capability).
"""
import argparse, glob, json, os, sys, time, urllib.request, collections

def post(base, path, payload):
    req = urllib.request.Request(base + path, json.dumps(payload).encode(), {"content-type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()
    except Exception as e:
        return 0, str(e).encode()

def norm_rel(r):
    return {"qualifier": r.get("qualifier") or "", "object_id": r.get("objectId") or r.get("object_id") or r.get("id")}

def to_events(doc):
    evs = doc.get("ocel:events") or doc.get("events") or []
    out = []
    for e in evs:
        out.append({"event_id": e.get("id"), "event_type": e.get("type"), "event_time": e.get("time"),
                    "attributes": e.get("attributes") if isinstance(e.get("attributes"), dict) else {},
                    "relationships": [norm_rel(r) for r in e.get("relationships", [])]})
    return out

def to_objects(doc):
    objs = doc.get("ocel:objects") or doc.get("objects") or []
    return [{"object_id": o.get("id"), "object_type": o.get("type"),
             "attributes": o.get("attributes") if isinstance(o.get("attributes"), dict) else {},
             "relationships": [norm_rel(r) for r in o.get("relationships", [])]} for o in objs]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default="http://localhost:4210")
    ap.add_argument("--ndjson", default=os.path.expanduser("~/xaas/priv/ocel/ash-actions.ndjson"))
    ap.add_argument("--zcode-dir", default=os.path.expanduser("~/.zcode/ocel"))
    ap.add_argument("--from-start", action="store_true")
    ap.add_argument("--interval", type=float, default=1.0)
    a = ap.parse_args()
    seen_objects, counts, refused = set(), collections.Counter(), collections.Counter()
    pos = 0 if a.from_start else (os.path.getsize(a.ndjson) if os.path.exists(a.ndjson) else 0)
    known = set() if a.from_start else set(glob.glob(a.zcode_dir + "/*.jsonocel"))
    last = time.time()

    def forward(doc, src):
        objs = [o for o in to_objects(doc) if o["object_id"] not in seen_objects]
        for o in objs: seen_objects.add(o["object_id"])
        evs = to_events(doc)
        for path, key, items in (("/ocel/objects", "objects", objs), ("/ocel/events", "events", evs)):
            for i in range(0, len(items), 200):
                st, body = post(a.base, path, {key: items[i:i+200]})
                if st not in (200, 201):
                    refused[(src, path, st)] += 1
                    if refused[(src, path, st)] <= 3: print(f"REFUSED {src} {path} {st} {body[:200]!r}", flush=True)
        for e in evs: counts[(src, e["event_type"])] += 1

    while True:
        if os.path.exists(a.ndjson) and os.path.getsize(a.ndjson) > pos:
            with open(a.ndjson, "rb") as f:
                f.seek(pos); chunk = f.read(); 
            nl = chunk.rfind(b"\n")
            if nl >= 0:
                pos += nl + 1
                for line in chunk[:nl].splitlines():
                    if line.strip():
                        try: forward(json.loads(line), "xaas")
                        except Exception as e: print("bad line", e, flush=True)
        for p in sorted(set(glob.glob(a.zcode_dir + "/*.jsonocel")) - known):
            known.add(p)
            try: forward(json.load(open(p)), "zcode:" + os.path.basename(p)[:13])
            except Exception as e: print("bad zcode log", p, e, flush=True)
        if time.time() - last > 10 and counts:
            last = time.time()
            print("--- forwarded:", sum(counts.values()), "refused:", sum(refused.values()), flush=True)
            for (src, t), n in counts.most_common(8): print(f"  {src:22} {t:32} {n}", flush=True)
        time.sleep(a.interval)

if __name__ == "__main__":
    try: main()
    except KeyboardInterrupt: sys.exit(0)
