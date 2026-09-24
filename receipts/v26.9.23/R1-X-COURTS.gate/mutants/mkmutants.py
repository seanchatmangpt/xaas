#!/usr/bin/env python3
"""R1-X-COURTS lane evidence: episode-directory mutants of the committed fmt-1 episode.

Mirrors the CE23-12 MSA p3 constructions (receipt_mutants.py, hops-allforged) but is built
here, from the committed artifacts of this lane's worktree, into this lane's scratch only.
"""
import copy, hashlib, json, os, shutil, sys

src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)


def digest(value):
    t = dict(value)
    t["exclusions"] = sorted(t["exclusions"])
    b = json.dumps(t, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return "sha256:" + hashlib.sha256(b.encode("utf-8")).hexdigest()


def episode(name):
    d = os.path.join(out, "ep-" + name)
    if os.path.exists(d):
        shutil.rmtree(d)
    shutil.copytree(src, d)
    return d


# GC23-4: hops.json forged consistently at every hop
d = episode("allforged")
hops = json.load(open(os.path.join(d, "hops.json")))
for hop in hops["hops"]:
    for carrier in ("tuple", "request"):
        hop[carrier]["postcondition"] += " (all-hop forgery)"
    hop["digest"] = digest(hop["tuple"])
    hop["request_digest"] = digest(hop["request"])
json.dump(hops, open(os.path.join(d, "hops.json"), "w"), indent=2)

# GC23-7: the seven court-owned receipt mutants of the MSA scan
r0 = json.load(open(os.path.join(src, "receipt.r.json")))


def m(fn):
    r = copy.deepcopy(r0)
    fn(r)
    return r


muts = {
    "native_digest_forged": m(lambda r: r["native"].__setitem__("receipt_digest", "sha256:" + "0" * 64)),
    "court_acceptance_false_but_alive": m(lambda r: r["court"]["acceptance_results"].update(
        {k: False for k in r["court"]["acceptance_results"]})),
    "consequence_commit_not_subject": m(lambda r: r["consequence"].__setitem__(
        "commits", ["80a8a4c71b331a39771ad65d1149eb835645d17c"])),
    "files_changed_outside_scope": m(lambda r: r["consequence"].__setitem__(
        "files_changed", ["mix.lock", "priv/secret.key"])),
    "actor_llm": m(lambda r: r["authority"].__setitem__("actor", "claude-opus")),
    "replay_cmd_swapped": m(lambda r: r["replay"]["commands"][0].__setitem__("cmd", "true")),
    "subject_sha_is_base": m(lambda r: r["identity"].__setitem__("subject_sha", r["identity"]["base_sha"])),
}
for name, rec in muts.items():
    d = episode(name)
    json.dump(rec, open(os.path.join(d, "receipt.r.json"), "w"), indent=1)
print("allforged " + " ".join(muts))
