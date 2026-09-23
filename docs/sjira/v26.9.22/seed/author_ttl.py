#!/usr/bin/env python3
"""One-time authoring seed for docs/sjira/v26.9.22/work-orders.ttl.

Provenance only. The TTL is the source of truth for the v26.9.22 cycle; this
script records HOW the first revision of that TTL was authored from the survey
synthesis (/Users/sac/wt/v26922/survey.json, key synth.v26_9_22: 16 repos, one
"ID — title — acceptance — depends_on: [...]" string per order, plus one
release_action per repo) and the exact release/v26.9.22 integration heads.

After the first revision, edit work-orders.ttl directly; do not re-seed over
it (a re-seed would silently discard hand edits to the graph). See
HANDWRITTEN.md: UNSUPPORTED(generator-capability) pending GGEN_IGNITER-26922-08.

Usage: python3 seed/author_ttl.py SURVEY_JSON OUT_TTL
"""
import json
import os
import re
import subprocess
import sys

WT = "/Users/sac/wt/v26922"
BRANCH = "release/v26.9.22"

# survey repo key -> (sj:repository slug, main checkout path, wt dir name)
REPOS = {
    "ggen_igniter": ("seanchatmangpt/ggen_igniter", "/Users/sac/ggen_igniter", "ggen_igniter"),
    "xaas": ("seanchatmangpt/xaas", "/Users/sac/xaas", "xaas"),
    "dev/zcode-cli": ("seanchatmangpt/zcode-cli", "/Users/sac/dev/zcode-cli", "zcode-cli"),
    "ash_a2a": ("seanchatmangpt/ash_a2a", "/Users/sac/ash_a2a", "ash_a2a"),
    "autofde-lab": ("seanchatmangpt/autofde-lab", "/Users/sac/autofde-lab", "autofde-lab"),
    "ggen-marketplace": ("seanchatmangpt/ggen-marketplace", "/Users/sac/ggen-marketplace", "ggen-marketplace"),
    "ggen": ("seanchatmangpt/ggen", "/Users/sac/ggen", "ggen"),
    "gymact": ("seanchatmangpt/gymact", "/Users/sac/gymact", "gymact"),
    "ash_atlassian": ("local/ash_atlassian", "/Users/sac/ash_atlassian", "ash_atlassian"),
    "beam4pm": ("seanchatmangpt/beam4pm", "/Users/sac/beam4pm", "beam4pm"),
    "frozen-duckdb": ("seanchatmangpt/frozen-duckdb", "/Users/sac/frozen-duckdb", "frozen-duckdb"),
    "ggen-ecosystem": ("seanchatmangpt/ggen-ecosystem", "/Users/sac/ggen-ecosystem", "ggen-ecosystem"),
    "ash_surface": ("seanchatmangpt/ash_surface", "/Users/sac/ash_surface", "ash_surface"),
    "ferroplan": ("seanchatmangpt/ferroplan", "/Users/sac/ferroplan", "ferroplan"),
    "gitvan": ("seanchatmangpt/gitvan", "/Users/sac/gitvan", "gitvan"),
    "chatman-ecosystem": ("local/chatman-ecosystem", "/Users/sac/chatman-ecosystem", "chatman-ecosystem"),
}

ID_RE = re.compile(r"^[A-Z][A-Z0-9_]*(?:-[A-Z0-9_]+)*-26922-\d\d$")

# Projection specs this graph uses: verbatim copies of the semantic-jira-pack
# (ontology.ttl, pack 26.9.19) definitions.
PROJECTIONS = [
    ("jira", "Jira/Markdown ticket", "jira/markdown ticket", "md"),
    ("sa2a", "SA2A work/execution package", "sa2a work/execution package", "json"),
    ("worker", "Bounded worker input envelope", "bounded worker input envelope", "json"),
    ("verification", "Verification plan", "verification plan", "json"),
    ("machine", "Machine status view", "machine status view", "json"),
    ("receipt", "Receipt requirement summary", "receipt requirement summary", "json"),
    ("replay", "Replay manifest", "replay manifest", "json"),
]

EVIDENCE = [
    ("source-evidence", "Source evidence", "Exact canonical-source identity evidence."),
    ("generated-artifact-evidence", "Generated artifact evidence", "Evidence binding a consequence to semantic source and generator."),
    ("local-execution-evidence", "Local execution evidence", "Observed repository-local exact-subject execution evidence."),
    ("hosted-ci-evidence", "Hosted CI evidence", "Hosted CI evidence kept distinct from local execution."),
    ("postcondition-evidence", "Postcondition evidence", "Independent evidence that the required consequence holds."),
    ("authority-evidence", "Authority evidence", "Prepared authority evidence for a consequential transition."),
    ("receipt-evidence", "Receipt evidence", "Durable receipt evidence for the exact subject and transition."),
    ("replay-evidence", "Replay evidence", "Fresh replay over pack, dependency, graph, consequence, toolchain, and environment identities."),
    ("publication-evidence", "Publication evidence", "Publication evidence distinct from implementation and verification."),
]


def lit(s):
    s = s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t")
    return f'"{s}"'


def key(ident):
    return ident.lower().replace("_", "-")


def slugify(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")[:48]


def rev(wt_name):
    d = f"{WT}/{wt_name}/int"
    return subprocess.check_output(["git", "-C", d, "rev-parse", BRANCH], text=True).strip()


def short_title(t):
    """First top-level clause (outside parentheses/backticks) that fits 140 chars."""
    if len(t) <= 140:
        return t
    depth, tick, cuts, last_space = 0, False, [], None
    for i, ch in enumerate(t):
        if ch == "`":
            tick = not tick
        elif not tick and ch in "([":
            depth += 1
        elif not tick and ch in ")]":
            depth = max(0, depth - 1)
        top = depth == 0 and not tick
        if top and i >= 30 and any(t.startswith(sep, i) for sep in (": ", "; ", ", ", " (", " — ")):
            cuts.append(i)
        if top and ch == " " and i < 137:
            last_space = i
    fitting = [c for c in cuts if c <= 140]
    if fitting:
        return t[:fitting[-1]] if len(fitting) > 1 and fitting[0] < 60 else t[:fitting[0]]
    return t[:last_space] + " ..."


NEGATIONS = [
    (r"(?i)cmd\s+=\s+cmd|cmd\s+equals\s+cmd", lambda m: "the two compared command outputs differ"),
    (r"prints nothing|prints no\b|no missing|finds nothing", lambda m: "the check prints any line or match (for example a MISSING/STALE marker)"),
    (r"prints 0 (?:for each|four times)", lambda m: "any of the repeated counts is nonzero"),
    (r"prints 0\b", lambda m: "the printed count is nonzero"),
    (r"prints (merged \d+ times|sa2a_import_alive|non-zero)", lambda m: f"the output does not show '{m.group(1)}'"),
    (r"exits? 0|exit code 0", lambda m: "a command in the check exits nonzero"),
    (r"(\d+) passed", lambda m: f"the test run reports other than {m.group(1)} passed"),
    (r"0 failures|0 fail\b|no failures|all pass", lambda m: "the test run reports one or more failures"),
    (r"0 skipped", lambda m: "any test is skipped"),
    (r"shows? no fail", lambda m: "any listed check shows fail"),
    (r"is at least (\d+)", lambda m: f"a counted value is below {m.group(1)}"),
    (r"is at most (\d+)", lambda m: f"a counted value exceeds {m.group(1)}"),
    (r"is below (\d+)", lambda m: f"a counted value is {m.group(1)} or more"),
    (r"(?<=\s)= ?(?!CMD)('[^']*'|\[\"[^\"]*\"\]|[A-Za-z0-9_.]+)", lambda m: f"a compared value is not {m.group(1)}"),
    (r"ends in", lambda m: "the final output line differs from the stated terminal value"),
    (r"byte-identical|identical both times", lambda m: "two runs over the same inputs differ in any byte"),
    (r"contains none of ([0-9, ]+)", lambda m: f"the output still contains one of {m.group(1).strip()}"),
    (r"\bmatches\b|\bequals\b", lambda m: "a compared pair differs"),
    (r"succeeds|\bsuccess\b|\bpasses\b|\bpass\b|\bgreen\b", lambda m: "a named run, job or suite does not succeed"),
    (r"\bresolves\b", lambda m: "the named reference does not resolve"),
    (r"\bexists\b", lambda m: "the named artifact does not exist"),
]


def expected_negations(acc):
    exp = re.sub(r"`[^`]*`", " CMD ", acc)
    low = exp.lower()
    neg = []
    for pat, fmt in NEGATIONS:
        for m in re.finditer(pat, low if "=" not in pat else exp):
            t = fmt(m)
            if t not in neg:
                neg.append(t)
    if not neg and not re.search(r"[a-z]", low.replace("cmd", "")):
        neg.append("a command in the check exits nonzero (the check is its own exit status)")
    if not neg:
        stated = " ".join(acc.split())
        stated = re.sub(r"(,? and)$", "", stated.strip(" :;,")).strip(" :;,")
        neg.append(f"the stated result is not observed: {stated}")
    return "; or ".join(neg)


PATH_TOKEN = re.compile(r"(?:/Users/sac/[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*/)?[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.*-]+)+|[A-Za-z0-9_-]+\.(?:ex|exs|toml|json|md|py|rs|ts|js|yml|yaml|ttl|lock|sh|txt|src|tf)\b")


def path_scope(text, main_path, int_path):
    found = []
    for tok in PATH_TOKEN.findall(text):
        tok = tok.rstrip(".,:;)")
        if tok.startswith(main_path + "/"):
            tok = tok[len(main_path) + 1:]
        elif tok.startswith("/"):
            continue
        tok = tok.split(":")[0]
        if not tok or tok.startswith(("http", "~", "$")):
            continue
        cand = tok.replace("/**", "").replace("*", "").rstrip("/")
        if not cand:
            continue
        p = os.path.join(int_path, cand)
        if os.path.exists(p):
            keep = tok if "*" in tok else cand
        elif "/" in cand and os.path.isdir(os.path.dirname(p)) and "." in os.path.basename(cand):
            keep = cand  # a new file in an existing directory
        else:
            continue
        if keep not in found:
            found.append(keep)
    return found or ["."]


def prereq_node(ident, token, slug):
    t = token.lower()
    if "or a hand-materialized epoch" in t:
        return None
    k = f"ev-{key(ident)}-{slugify(token)}"
    label = f"{ident} prerequisite: {token}"
    if "authority" in t and "decision" not in t:
        kind = token.replace(" authority", "")
        desc = (f"Prepared {kind} authority for {slug}, issued by the operator and "
                f"consumed by the BRCE DO edge that performs the {kind} step {ident} needs. "
                f"The work order itself stays at authority ceiling CONSTRUCT; without the "
                f"prepared authority receipt its standing is BLOCKED:{slugify(token)}.")
    elif "coordination" in t:
        desc = (f"Recorded hand-off with the concurrently active ERRC session on {slug} "
                f"(no second writer on the main checkout) before {ident} verifies and "
                f"pushes; absent => BLOCKED:{slugify(token)}.")
    else:
        desc = (f"The user's recorded {token} for {ident} on {slug}. No default is "
                f"assumed in its absence: the order stays BLOCKED:{slugify(token)} until "
                f"the decision is written to the order's receipt evidence.")
    return k, label, desc


def main():
    survey, out = sys.argv[1], sys.argv[2]
    synth = json.load(open(survey))["synth"]["v26_9_22"]
    orders, heads = [], {}
    for r in synth:
        slug, main_path, wt_name = REPOS[r["repo"]]
        heads[r["repo"]] = rev(wt_name)
        for s in r["work_orders"]:
            parts = [p.strip() for p in s.split(" — ")]
            ident, deps_part = parts[0], parts[-1]
            title, acc = parts[1], " — ".join(parts[2:-1])
            assert ID_RE.match(ident), ident
            m = re.match(r"depends_on:\s*\[(.*)\]\s*$", deps_part)
            assert m, s
            toks = [t.strip() for t in m.group(1).split(",") if t.strip()]
            orders.append(dict(repo=r["repo"], slug=slug, main=main_path, wt=wt_name,
                               ident=ident, title=title, acc=acc, toks=toks,
                               release=r["release_action"]))
    ids = {o["ident"] for o in orders}
    assert len(ids) == len(orders), "duplicate identifiers"
    prefix_of = lambda ident: ident.rsplit("-", 2)[0]

    L = []
    w = L.append
    w("@prefix sj: <https://ggen-igniter.dev/ontology/semantic-jira#> .")
    w("@prefix dcterms: <http://purl.org/dc/terms/> .")
    w("@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .")
    w("@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .")
    w("@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .")
    w("")
    w("# Canonical RDF for the v26.9.22 multi-repo Semantic Jira work graph (16 repositories,")
    w(f"# {len(orders)} work orders). Vocabulary: semantic-jira-pack (ggen_igniter, pack 26.9.19).")
    w("# This graph is the source; wo.json, index.json and jira/*.md are projections (project.py).")
    w("# Standing is UNKNOWN for every order here: observed standing comes from the TransitionLog")
    w("# (GGEN_IGNITER-26922-06/07), never from a literal edited into a projection.")
    w("# baseSha = exact release/v26.9.22 integration head of each repository at authoring time.")
    w("")
    for c in ("WorkOrder", "Court", "EvidenceRequirement", "AcceptanceCriterion", "Falsifier",
              "Action", "Checkpoint", "ProjectionSpec", "DependencyEdge"):
        w(f"sj:{c} a rdfs:Class .")
    w("")
    for k, label, desc in EVIDENCE:
        w(f"sj:{k} a sj:EvidenceRequirement ;\n    rdfs:label {lit(label)} ;\n    dcterms:description {lit(desc)} .")
    w("")
    for t, label, noun, ext in PROJECTIONS:
        w(f"sj:projection-{t} a sj:ProjectionSpec ;\n    rdfs:label {lit(label)} ;\n"
          f"    dcterms:description {lit(f'Deterministic {noun} projection; authority is NONE.')} ;\n"
          f"    sj:projectionType {lit(t)} ;\n    sj:extension {lit(ext)} ;\n"
          f"    sj:generatorIdentity \"ggen_igniter:semantic-jira-pack@26.9.19\" ;\n    sj:authorityClaim \"NONE\" .")
    w("")
    w("# ---- per-repository release checkpoints (release_action of the v26.9.22 synthesis) ----")
    seen = set()
    for r in synth:
        slug, _, wt_name = REPOS[r["repo"]]
        if wt_name in seen:
            continue
        seen.add(wt_name)
        head = heads[r["repo"]]
        w(f"sj:cp-{slugify(wt_name)}-v26922-release a sj:Checkpoint ;\n"
          f"    rdfs:label {lit(f'{slug} v26.9.22 release checkpoint')} ;\n"
          f"    dcterms:description {lit(f'Closes the v26.9.22 cycle for {slug} (integration head {head} on release/v26.9.22 at authoring). Release action: ' + r['release_action'])} .")
    w("")

    for o in orders:
        ident, slug, k = o["ident"], o["slug"], key(o["ident"])
        sha = heads[o["repo"]]
        int_path = f"{WT}/{o['wt']}/int"
        wt, acc = o["wt"], o["acc"]
        edges, prereqs = [], []
        for t in o["toks"]:
            if re.fullmatch(r"\d\d", t):
                edges.append((f"{prefix_of(ident)}-26922-{t}", "requiresReceipt", None))
            elif ID_RE.match(t):
                edges.append((t, "requiresReceipt", None))
            elif " or a hand-materialized epoch" in t:
                up = t.split(" ")[0]
                edges.append((up, "requiresObservation", t))
            else:
                prereqs.append(t)
        for up, _, _ in edges:
            assert up in ids, f"{ident}: unresolved dependency {up}"
        text = f"{o['title']} {o['acc']}"
        low = text.lower()
        evidence = ["source-evidence", "local-execution-evidence", "receipt-evidence", "replay-evidence"]
        classes = ["manufacture", "verification", "replay"]
        if re.search(r"gh pr checks|gh run|\bci\b|ci\.yml|ci-green|ci green|workflow|actions", low):
            evidence.insert(2, "hosted-ci-evidence")
        if re.search(r"ggen sync|generat|render|projection", low):
            evidence.insert(1, "generated-artifact-evidence")
        if "merge-base --is-ancestor" in low or "is-ancestor" in low:
            evidence.append("postcondition-evidence")
            classes.append("postcondition")
        pub = re.search(r"\bpublish|hex\.pm|hex publish|crates\.io|ghcr|\btag\b|homebrew|release pipeline", low)
        if pub:
            evidence.append("publication-evidence")
        pnodes = [prereq_node(ident, t, slug) for t in prereqs]
        pnodes = [p for p in pnodes if p]
        if any("authority" in t.lower() and "decision" not in t.lower() for t in prereqs):
            evidence.append("authority-evidence")
            classes.append("authority_preparation")
        if pub and any("publish" in t.lower() for t in prereqs):
            classes.append("publication")
        scope = path_scope(text, o["main"], int_path)
        ups = [e[0] for e in edges]
        title = short_title(o["title"])
        desc = o["title"].rstrip(".") + ". Acceptance: " + o["acc"].rstrip(".") + "."
        if ups:
            desc += " Upstream work orders: " + ", ".join(ups) + "."
        if prereqs:
            desc += " Non-order prerequisites: " + "; ".join(prereqs) + "."
        promo = (f"{ident} leaves UNKNOWN only through a TransitionLog event whose receipt binds "
                 f"candidateSha and subjectSha on {slug} {BRANCH} descended from {sha}: the court "
                 f"must observe the acceptance check pass at that head, observe it fail when the "
                 f"order's diff is reverted (revert-mutation), and find every upstream edge "
                 f"({', '.join(ups) if ups else 'none'}) ALIVE"
                 + (f", with the prerequisite evidence ({'; '.join(prereqs)}) recorded" if prereqs else "")
                 + ". A passing log without a receipt, a generated projection, or upstream standing alone never promotes.")
        w(f"# ---- {ident} ----")
        w(f"sj:wo-{k}\n    a sj:WorkOrder ;")
        w(f"    rdfs:label {lit(ident + ': ' + title)} ;")
        w(f"    dcterms:identifier {lit(ident)} ;")
        w(f"    dcterms:title {lit(title)} ;")
        w(f"    dcterms:description {lit(desc)} ;")
        w(f"    sj:repository {lit(slug)} ;")
        w(f"    sj:baseSha {lit(sha)} ;")
        w(f"    sj:subject {lit(f'{slug}@{BRANCH}#{ident}')} ;")
        w("    sj:standing \"UNKNOWN\" ;")
        w("    sj:evidenceCeiling \"EXECUTED_VERIFIED\" ;")
        w("    sj:authorityCeiling \"CONSTRUCT\" ;")
        w("    sj:authorityRequirement \"NONE\" ;")
        w(f"    sj:promotionRule {lit(promo)} ;")
        w(f"    sj:replayIdentity {lit(f'semantic-jira:v26.9.22:{ident}')} ;")
        w("    sj:pathScope " + ", ".join(lit(p) for p in scope) + " ;")
        w("    sj:requiresReceiptClass " + ", ".join(lit(c) for c in classes) + " ;")
        if edges:
            w("    sj:dependsOn " + ", ".join(f"sj:edge-{k}-on-{key(u)}" for u, _, _ in edges) + " ;")
        w(f"    sj:requiresCourt sj:court-{k} ;")
        w("    sj:requiresEvidence " + ", ".join([f"sj:{e}" for e in evidence] + [f"sj:{p[0]}" for p in pnodes]) + " ;")
        w(f"    sj:acceptance sj:acc-{k}-check, sj:acc-{k}-subject ;")
        w(f"    sj:falsifier sj:fal-{k}-outcome, sj:fal-{k}-mutation ;")
        w("    sj:projection " + ", ".join(f"sj:projection-{t}" for t, *_ in PROJECTIONS) + " ;")
        w(f"    sj:nextAction sj:act-{k}-court ;")
        w(f"    sj:nextCheckpoint sj:cp-{slugify(o['wt'])}-v26922-release .")
        w("")
        w(f"sj:court-{k} a sj:Court ;\n    rdfs:label {lit(f'{ident} exact-head court')} ;\n"
          f"    dcterms:description {lit(f'Independent court for {ident} ({slug}): re-runs the acceptance check against the {BRANCH} integration head in {int_path}, applies a revert-mutation of the order diff that must make the check fail, applies the doctrine lens, and writes /Users/sac/wt/v26922/court/{wt}/{ident}.json binding candidateSha, subjectSha, toolchain and receipt identity.')} .")
        w(f"sj:acc-{k}-check a sj:AcceptanceCriterion ;\n    rdfs:label {lit(f'{ident} runnable check')} ;\n"
          f"    dcterms:description {lit(o['acc'])} .")
        w(f"sj:acc-{k}-subject a sj:AcceptanceCriterion ;\n    rdfs:label {lit(f'{ident} exact-subject binding')} ;\n"
          f"    dcterms:description {lit(f'The check runs at a recorded head of {slug} {BRANCH} that has {sha} as an ancestor (git merge-base --is-ancestor {sha[:12]} HEAD exits 0); that head is the receipt subjectSha.')} .")
        w(f"sj:fal-{k}-outcome a sj:Falsifier ;\n    rdfs:label {lit(f'{ident} check refuted')} ;\n"
          f"    dcterms:description {lit(f'Refutes {ident}: at the court head, {expected_negations(acc)}.')} .")
        w(f"sj:fal-{k}-mutation a sj:Falsifier ;\n    rdfs:label {lit(f'{ident} vacuous acceptance')} ;\n"
          f"    dcterms:description {lit(f'Refutes the acceptance of {ident} as evidence: after reverting only the order diff on the court head, the same check still passes, so it does not observe this order consequence.')} .")
        w(f"sj:act-{k}-court a sj:Action ;\n    rdfs:label {lit(f'Run the {ident} court')} ;\n"
          f"    dcterms:description {lit(f'Take /Users/sac/wt/v26922/{wt}/.merge.lock per COORDINATION.md, build in an own worktree off {BRANCH} ({sha[:12]}), run the acceptance check, write receipts/v26.9.22/{ident}.json (validate_receipt.py) and the court verdict, then append the standing transition to the TransitionLog.')} .")
        for pk, plabel, pdesc in pnodes:
            w(f"sj:{pk} a sj:EvidenceRequirement ;\n    rdfs:label {lit(plabel)} ;\n    dcterms:description {lit(pdesc)} .")
        for u, typ, note in edges:
            if note:
                edesc = (f"{ident} needs the observation that {u} would produce: {note}. "
                         f"The edge is satisfied by {u}'s receipt or by a directly observed hand-materialized epoch.")
            else:
                edesc = (f"{ident} starts only after {u} holds a durable receipt at its own exact head; "
                         f"{u}'s standing is read from the TransitionLog, not inherited.")
            w(f"sj:edge-{k}-on-{key(u)} a sj:DependencyEdge ;\n    rdfs:label {lit(f'{ident} depends on {u}')} ;\n"
              f"    dcterms:description {lit(edesc)} ;\n    sj:dependencyType {lit(typ)} ;\n"
              f"    sj:upstreamWorkOrder sj:wo-{key(u)} ;\n    sj:requiredStanding \"ALIVE\" .")
        w("")
    with open(out, "w") as f:
        f.write("\n".join(L) + "\n")
    print(f"authored {len(orders)} work orders from {len(synth)} repositories into {out}")


if __name__ == "__main__":
    main()
