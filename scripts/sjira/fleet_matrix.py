#!/usr/bin/env python3
"""GC23-11 bounded fleet: universe, observation, classification court, matrix, standing court.

PRD v26.9.23 section 12 GC23-11 ("every repo relevant to the checkpoint has exact-subject
standing or an explicit non-required classification"), section 10 (making every repository
ALIVE is a non-goal), ARD section 4 (repository responsibilities), ARD section 26 F6/F7.

Subcommands (deterministic; stdlib + rdflib; no LLM, no model API):

  universe  --fleet-ttl P --survey P --prose P --out universe.json
            The declared finite fleet: union of the sj:ObservedRepository rows of fleet.ttl,
            the survey perRepo list and the ARD section 4 repository headings of the prose.
  observe   --universe U --out observations.json --observed-at ISO [--no-network]
            [--int NAME=PATH ...]
            Per repo: git fetch --all --tags --no-prune (network only; output captured, not
            --quiet, so rejected refs are recorded), HEAD, symbolic ref,
            default-branch SHA, ahead/behind, dirty path count, open PRs (gh, network only).
            Nothing is written to an observed repository except what fetch writes.
  emit      --classification C --observations O --out-ttl T --out-md M
            Sorted fleet matrix; byte-identical output for identical inputs.
  check-classification --classification C --universe U [--courts-dir D]
            [--expect-critical NAME ...]
            Exit 1 naming every universe repo without exactly one classification (ARD F7),
            every classification whose repo is not in the universe, and every malformed row.
  check-standing --classification C --receipts-dir D ... --int NAME=PATH ...
            Exit 0 only when every CriticalPath repo has a validator-ADMITTED ALIVE R receipt
            whose identity.subject_sha equals the exact HEAD of its --int checkout (ARD F6).

Exit codes: 0 holds, 1 refused / not holding (only from an explicit refusal), 2 cannot run
(bad arguments, unreadable inputs, absent validator, or an internal error with its traceback).
Unreadable receipt files are reported as REFUSED(unreadable_receipt), never skipped silently.
"""

import argparse
import concurrent.futures
import hashlib
import json
import os
import re
import subprocess
import sys
import traceback
from pathlib import Path

SJ = "https://ggen-igniter.dev/ontology/semantic-jira#"
V23 = "https://ggen-igniter.dev/sjira/v26.9.23#"
DCT = "http://purl.org/dc/terms/"
RDF_TYPE = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"

CLASSES = ("CriticalPath", "Successor", "Blocked", "Unsupported", "Refused")
SUCCESSOR_TARGET = V23 + "GC-26.9.24"
CHECKPOINT = "GC-26.9.23"
GATE = "GC23-11"
DEFAULT_VALIDATOR = str(Path.home() / ".claude/dfcm/validate_receipt.py")
SHA_RE = re.compile(r"^[0-9a-f]{40}$")


class CannotRun(Exception):
    """Inputs unreadable or arguments invalid: exit 2."""


# ── small deterministic helpers ─────────────────────────────────────────────


def sha256_file(path):
    return "sha256:" + hashlib.sha256(Path(path).read_bytes()).hexdigest()


def dump_json(obj):
    return json.dumps(obj, indent=2, sort_keys=True, ensure_ascii=False) + "\n"


def write_text(path, text):
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_bytes(text.encode("utf-8"))


def load_json(path):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        raise CannotRun(f"cannot read JSON {path}: {exc}") from exc


def run(argv, cwd=None, timeout=60, env=None):
    """Runs argv; returns (exit, stdout, stderr). Timeout -> exit 124."""
    try:
        cp = subprocess.run(
            argv, cwd=cwd, capture_output=True, text=True, timeout=timeout, env=env
        )
        return cp.returncode, cp.stdout, cp.stderr
    except subprocess.TimeoutExpired:
        return 124, "", "timeout"
    except OSError as exc:
        return 127, "", str(exc)


def git(path, *args, timeout=60):
    # --no-optional-locks: status must not refresh the index of an observed repository.
    return run(["git", "--no-optional-locks", "-C", path, *args], timeout=timeout)


def ttl_lit(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    s = str(value)
    s = (
        s.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t")
    )
    return f'"{s}"'


def local_name(name):
    return re.sub(r"[^A-Za-z0-9_-]", "_", name)


def slug_from_url(url):
    m = re.match(r"^(?:https://github\.com/|git@github\.com:|ssh://git@github\.com/)([^/]+)/([^/]+?)(?:\.git)?/?$", url)
    return f"{m.group(1)}/{m.group(2)}" if m else None


def require_rdflib():
    """rdflib absent is "cannot run" (exit 2), never a refusal."""
    try:
        import rdflib
    except ImportError as exc:
        raise CannotRun(f"rdflib not importable by {sys.executable}: {exc}") from exc
    return rdflib


def parse_kv(pairs, flag):
    out = {}
    for item in pairs or []:
        if "=" not in item:
            raise CannotRun(f"{flag} expects NAME=PATH, got {item!r}")
        k, v = item.split("=", 1)
        if not k or not v:
            raise CannotRun(f"{flag} expects NAME=PATH, got {item!r}")
        if k in out:
            raise CannotRun(f"{flag} names {k} twice")
        out[k] = v
    return out


# ── universe ────────────────────────────────────────────────────────────────


def fleet_ttl_rows(path):
    rdflib = require_rdflib()

    g = rdflib.Graph()
    try:
        g.parse(path, format="turtle")
    except Exception as exc:  # rdflib raises several parser exception types
        raise CannotRun(f"cannot parse {path}: {exc}") from exc
    sj = rdflib.Namespace(SJ)
    rows = []
    for s in g.subjects(rdflib.RDF.type, sj.ObservedRepository):
        label = g.value(s, rdflib.RDFS.label)
        rpath = g.value(s, sj.repositoryPath)
        role = g.value(s, sj.fleetRole)
        if label is None:
            raise CannotRun(f"{path}: {s} has no rdfs:label")
        rows.append(
            {
                "name": str(label),
                "path": str(rpath) if rpath is not None else None,
                "fleet_role": str(role) if role is not None else None,
                "iri": str(s),
            }
        )
    return rows


def survey_rows(path):
    data = load_json(path)
    rows = []
    for entry in data.get("perRepo", []):
        s = entry.get("survey", {})
        raw = str(s.get("repo", "")).strip()
        m = re.match(r"^(\S+)\s+\(([^)]+)\)$", raw)
        name, slug = (m.group(1), m.group(2)) if m else (raw, None)
        if not name:
            raise CannotRun(f"{path}: perRepo entry without a repo name")
        rows.append(
            {
                "name": name,
                "path": s.get("path"),
                "relevant": s.get("relevant"),
                "slug_hint": slug,
            }
        )
    return rows


def ard_section4_repos(prose_path):
    """`## <name>` headings between '# 4. Repository Responsibilities' and the next '# ' heading."""
    try:
        lines = Path(prose_path).read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        raise CannotRun(f"cannot read prose {prose_path}: {exc}") from exc
    names, inside = [], False
    for line in lines:
        if line.startswith("# "):
            if inside:
                break
            inside = line.strip() == "# 4. Repository Responsibilities"
            continue
        if inside and line.startswith("## "):
            names.append(line[3:].strip())
    if not names:
        raise CannotRun(f"{prose_path}: no ARD section 4 repository headings found")
    return names


def git_toplevel(path):
    code, out, _ = run(["git", "-C", path, "rev-parse", "--show-toplevel"], timeout=20)
    return out.strip() if code == 0 else None


def remotes_of(path):
    code, out, _ = run(["git", "-C", path, "remote", "-v"], timeout=20)
    remotes = {}
    if code == 0:
        for line in out.splitlines():
            parts = line.split()
            if len(parts) >= 3 and parts[2] == "(fetch)":
                remotes[parts[0]] = parts[1]
    return remotes


def choose_remote(remotes, owner, slug_hint):
    """The fleet's own remote: owner-matching origin, then any owner-matching remote, else origin."""
    slugs = {name: slug_from_url(url) for name, url in remotes.items()}
    if slug_hint:
        for name in sorted(slugs):
            if slugs[name] == slug_hint:
                return name, slugs[name]
    owned = [n for n in sorted(slugs) if slugs[n] and slugs[n].split("/")[0] == owner]
    if "origin" in owned:
        return "origin", slugs["origin"]
    if owned:
        return owned[0], slugs[owned[0]]
    if "origin" in slugs:
        return "origin", slugs["origin"]
    return None, None


def gh_repo_view(slug):
    argv = ["gh", "repo", "view", slug, "--json", "nameWithOwner,defaultBranchRef,visibility"]
    code, out, err = run(argv, timeout=60)
    probe = {"cmd": " ".join(argv), "exit": code}
    if code == 0:
        try:
            d = json.loads(out)
            probe["name_with_owner"] = d.get("nameWithOwner")
            probe["default_branch"] = (d.get("defaultBranchRef") or {}).get("name")
            probe["visibility"] = d.get("visibility")
        except ValueError:
            probe["exit"] = 65
    else:
        probe["error"] = (err.strip().splitlines() or ["?"])[-1][:200]
    return probe


def cmd_universe(a):
    fleet = fleet_ttl_rows(a.fleet_ttl)
    survey = survey_rows(a.survey)
    ard = ard_section4_repos(a.prose)
    repos = {}

    def entry(name):
        return repos.setdefault(
            name,
            {
                "name": name,
                "path": None,
                "github": None,
                "default_remote": None,
                "sources": [],
                "fleet_role": None,
                "survey_relevant": None,
                "ard_section4": False,
            },
        )

    for r in fleet:
        e = entry(r["name"])
        e["sources"].append("fleet.ttl")
        e["path"] = e["path"] or r["path"]
        e["fleet_role"] = r["fleet_role"]
    for r in survey:
        e = entry(r["name"])
        e["sources"].append("survey.json")
        if e["path"] and r["path"] and e["path"] != r["path"]:
            raise CannotRun(f"{r['name']}: fleet.ttl path {e['path']} != survey path {r['path']}")
        e["path"] = e["path"] or r["path"]
        e["survey_relevant"] = r["relevant"]
        e["_slug_hint"] = r["slug_hint"]
    for name in ard:
        e = entry(name)
        e["sources"].append("ard-4")
        e["ard_section4"] = True

    roots = [str(Path(p).expanduser()) for p in (a.search_root or ["~", "~/dev"])]
    for name, e in repos.items():
        if e["path"] is None:
            for root in roots:
                cand = str(Path(root) / name)
                if Path(cand).is_dir() and git_toplevel(cand) == cand:
                    e["path"] = cand
                    e["sources"].append("local-checkout")
                    break
        slug_hint = e.pop("_slug_hint", None)
        if e["path"]:
            if git_toplevel(e["path"]) is None:
                raise CannotRun(f"{name}: {e['path']} is not a git checkout")
            rname, slug = choose_remote(remotes_of(e["path"]), a.owner, slug_hint)
            e["default_remote"] = rname
            e["github"] = slug
        if (e["github"] is None or e["github"].split("/")[0] != a.owner) and not a.no_network:
            probe = gh_repo_view(slug_hint or f"{a.owner}/{name}")
            e["github_probe"] = probe
            if probe["exit"] == 0 and e["github"] is None:
                e["github"] = probe.get("name_with_owner")
        e["sources"] = sorted(set(e["sources"]))

    universe = {
        "schema": "xaas.fleet.universe/v1",
        "checkpoint": CHECKPOINT,
        "gate": GATE,
        "sources": [
            {"id": "fleet.ttl", "path": a.fleet_ttl, "sha256": sha256_file(a.fleet_ttl)},
            {"id": "survey.json", "path": a.survey, "sha256": sha256_file(a.survey)},
            {
                "id": "ard-4",
                "path": a.prose_path or a.prose,
                "sha256": sha256_file(a.prose),
                "section": "# 4. Repository Responsibilities",
            },
        ],
        "repositories": [repos[k] for k in sorted(repos)],
    }
    write_text(a.out, dump_json(universe))
    print(f"universe: {len(repos)} repositories -> {a.out}")
    return 0


def load_universe(path):
    u = load_json(path)
    repos = u.get("repositories")
    if not isinstance(repos, list):
        raise CannotRun(f"{path}: no repositories list")
    names = [r.get("name") for r in repos]
    if any(not n for n in names):
        raise CannotRun(f"{path}: repository without a name")
    dup = sorted({n for n in names if names.count(n) > 1})
    if dup:
        raise CannotRun(f"{path}: duplicate universe names {dup}")
    return u


# ── observe ─────────────────────────────────────────────────────────────────


def observe_repo(repo, network, timeout):
    name, path = repo["name"], repo.get("path")
    obs = {
        "name": name,
        "path": path,
        "github": repo.get("github"),
        "head_sha": None,
        "branch": None,
        "default_remote": repo.get("default_remote"),
        "default_ref": None,
        "default_ref_source": None,
        "default_sha": None,
        "ahead": None,
        "behind": None,
        "dirty_paths": None,
        "fetch": None,
        "open_prs": None,
        "open_prs_probe": None,
        "errors": [],
    }
    slug = repo.get("github")
    if path is None:
        obs["fetch"] = {"status": "skipped", "reason": "no local checkout"}
        if network and slug:
            code, out, _ = run(["git", "ls-remote", "--symref", f"https://github.com/{slug}.git", "HEAD"], timeout=timeout)
            if code == 0:
                for line in out.splitlines():
                    if line.startswith("ref: "):
                        obs["default_ref"] = line.split()[1].replace("refs/heads/", "")
                    elif line.endswith("\tHEAD") and SHA_RE.match(line.split("\t")[0]):
                        obs["default_sha"] = line.split("\t")[0]
                obs["default_ref_source"] = "ls-remote --symref"
            else:
                obs["errors"].append(f"ls-remote exit {code}")
    else:
        if network:
            code, _, err = run(
                [
                    "git",
                    "-c",
                    "gc.auto=0",
                    "-c",
                    "maintenance.auto=false",
                    "-C",
                    path,
                    "fetch",
                    "--all",
                    "--tags",
                    "--no-prune",
                    "--no-recurse-submodules",
                ],
                timeout=timeout,
            )
            obs["fetch"] = {"status": "ok" if code == 0 else "failed", "exit": code}
            if code != 0:
                obs["fetch"]["error"] = (err.strip().splitlines() or ["?"])[-1][:200]
                obs["fetch"]["failed_remotes"] = sorted(
                    {m.group(1) for m in re.finditer(r"^error: could not fetch (\S+)", err, re.M)}
                )
                rejected = [ln for ln in err.splitlines() if "[rejected]" in ln]
                if rejected:
                    # Never forced: a rejected ref (e.g. a tag that would be clobbered) stays as found.
                    obs["fetch"]["rejected_refs"] = len(rejected)
                    obs["fetch"]["rejected_reasons"] = sorted(
                        {m.group(1) for ln in rejected for m in [re.search(r"\(([^)]*)\)\s*$", ln)] if m}
                    )
        else:
            obs["fetch"] = {"status": "skipped", "reason": "--no-network"}
        code, out, _ = git(path, "rev-parse", "--verify", "HEAD")
        if code == 0 and SHA_RE.match(out.strip()):
            obs["head_sha"] = out.strip()
        else:
            obs["errors"].append(f"rev-parse HEAD exit {code}")
        code, out, _ = git(path, "symbolic-ref", "--quiet", "--short", "HEAD")
        obs["branch"] = out.strip() if code == 0 else None
        remote = repo.get("default_remote")
        if remote:
            code, out, _ = git(path, "symbolic-ref", "--quiet", f"refs/remotes/{remote}/HEAD")
            if code == 0:
                obs["default_ref"] = out.strip().replace(f"refs/remotes/{remote}/", "")
                obs["default_ref_source"] = f"symbolic-ref refs/remotes/{remote}/HEAD"
            elif network:
                code, out, _ = git(path, "ls-remote", "--symref", remote, "HEAD", timeout=timeout)
                for line in out.splitlines() if code == 0 else []:
                    if line.startswith("ref: "):
                        obs["default_ref"] = line.split()[1].replace("refs/heads/", "")
                        obs["default_ref_source"] = f"ls-remote --symref {remote} HEAD"
            if obs["default_ref"]:
                code, out, _ = git(path, "rev-parse", "--verify", "--quiet", f"refs/remotes/{remote}/{obs['default_ref']}")
                if code == 0:
                    obs["default_sha"] = out.strip()
                else:
                    obs["errors"].append(f"{remote}/{obs['default_ref']} not fetched")
            else:
                obs["errors"].append(f"{remote} default branch unresolved")
        else:
            obs["errors"].append("no remote")
            if network and slug:
                # The GitHub repository exists but this checkout has no remote for it: read its
                # default branch without adding a remote (the checkout is not modified).
                code, out, _ = run(["git", "ls-remote", "--symref", f"https://github.com/{slug}.git", "HEAD"], timeout=timeout)
                for line in out.splitlines() if code == 0 else []:
                    if line.startswith("ref: "):
                        obs["default_ref"] = line.split()[1].replace("refs/heads/", "")
                    elif line.endswith("\tHEAD") and SHA_RE.match(line.split("\t")[0]):
                        obs["default_sha"] = line.split("\t")[0]
                if obs["default_sha"]:
                    obs["default_ref_source"] = f"ls-remote --symref https://github.com/{slug}.git HEAD"
                    code, _, _ = git(path, "cat-file", "-e", obs["default_sha"] + "^{commit}")
                    if code != 0:
                        obs["errors"].append("default-branch commit absent locally (unrelated lineage or unfetched)")
                        obs["default_sha_local"] = False
        if obs["head_sha"] and obs["default_sha"] and obs.get("default_sha_local", True):
            code, out, _ = git(path, "rev-list", "--left-right", "--count", f"{obs['head_sha']}...{obs['default_sha']}")
            if code == 0 and len(out.split()) == 2:
                obs["ahead"], obs["behind"] = (int(x) for x in out.split())
        code, out, _ = git(path, "status", "--porcelain=v1", "--untracked-files=normal", timeout=timeout)
        if code == 0:
            obs["dirty_paths"] = len([ln for ln in out.splitlines() if ln.strip()])
        else:
            obs["errors"].append(f"status exit {code}")
    if network and slug:
        argv = ["gh", "pr", "list", "--repo", slug, "--state", "open", "--limit", "200", "--json", "number,title,headRefName"]
        code, out, err = run(argv, timeout=timeout)
        obs["open_prs_probe"] = {"cmd": " ".join(argv), "exit": code}
        if code == 0:
            try:
                prs = json.loads(out)
                obs["open_prs"] = sorted(
                    ({"number": p["number"], "title": p["title"], "headRefName": p["headRefName"]} for p in prs),
                    key=lambda p: p["number"],
                )
            except (ValueError, KeyError):
                obs["open_prs_probe"]["exit"] = 65
        else:
            obs["open_prs_probe"]["error"] = (err.strip().splitlines() or ["?"])[-1][:200]
    return obs


def observe_subject(name, path):
    s = {"name": name, "path": path, "head_sha": None, "branch": None, "dirty_paths": None}
    code, out, _ = git(path, "rev-parse", "--verify", "HEAD")
    if code != 0 or not SHA_RE.match(out.strip()):
        raise CannotRun(f"--int {name}={path}: not a git checkout with a HEAD")
    s["head_sha"] = out.strip()
    code, out, _ = git(path, "symbolic-ref", "--quiet", "--short", "HEAD")
    s["branch"] = out.strip() if code == 0 else None
    code, out, _ = git(path, "status", "--porcelain=v1", "--untracked-files=normal")
    s["dirty_paths"] = len([ln for ln in out.splitlines() if ln.strip()]) if code == 0 else None
    return s


def cmd_observe(a):
    u = load_universe(a.universe)
    ints = parse_kv(a.int, "--int")
    network = not a.no_network
    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, a.jobs)) as pool:
        rows = list(pool.map(lambda r: observe_repo(r, network, a.timeout), u["repositories"]))
    subjects = [observe_subject(k, ints[k]) for k in sorted(ints)]
    doc = {
        "schema": "xaas.fleet.observations/v1",
        "checkpoint": CHECKPOINT,
        "gate": GATE,
        "observed_at": a.observed_at,
        "universe_sha256": sha256_file(a.universe),
        "network": network,
        "repositories": sorted(rows, key=lambda r: r["name"]),
        "subjects": subjects,
    }
    write_text(a.out, dump_json(doc))
    failed = [r["name"] for r in rows if r["fetch"] and r["fetch"].get("status") == "failed"]
    print(f"observe: {len(rows)} repositories, {len(subjects)} subjects, fetch failed: {failed or 'none'} -> {a.out}")
    return 0


# ── classification ──────────────────────────────────────────────────────────


def load_classification(path):
    rdflib = require_rdflib()

    g = rdflib.Graph()
    try:
        g.parse(path, format="turtle")
    except Exception as exc:
        raise CannotRun(f"cannot parse {path}: {exc}") from exc
    sj = rdflib.Namespace(SJ)
    dct = rdflib.Namespace(DCT)
    rows = []
    for node in sorted(g.subjects(rdflib.RDF.type, sj.FleetClassification), key=str):
        ids = sorted(str(x) for x in g.objects(node, dct.identifier))
        classes = sorted(str(x) for x in g.objects(node, sj.fleetClass))
        required = [x.toPython() for x in g.objects(node, sj.requiredForCheckpoint)]
        rows.append(
            {
                "node": str(node),
                "ids": ids,
                "classes": classes,
                "required": required,
                "role": sorted(str(x) for x in g.objects(node, sj.fleetRole)),
                "reason": sorted(str(x) for x in g.objects(node, sj.classificationReason)),
                "evidence": sorted(str(x) for x in g.objects(node, sj.evidence)),
                "successor": sorted(str(x) for x in g.objects(node, sj.successorCheckpoint)),
                "under": sorted(str(x) for x in g.objects(node, sj.classifiedUnder)),
            }
        )
    return rows


def env_var_for(name):
    return re.sub(r"[^A-Za-z0-9]", "_", name).upper() + "_DIR"


def court_references(courts_dir, repo):
    """Court scripts that lexically name this repo's checkout (path, ~/name, $HOME/name, NAME_DIR)."""
    name, path = repo["name"], repo.get("path")
    tail = r"(?![A-Za-z0-9_.-])"
    pats = [re.escape("$" + env_var_for(name)) + tail, re.escape("${" + env_var_for(name)) + r"[}:]"]
    for prefix in ("~/", "$HOME/", "${HOME}/"):
        pats.append(re.escape(prefix + name) + tail)
    if path:
        pats.append(re.escape(path) + tail)
    rx = re.compile("|".join(pats))
    hits = []
    for script in sorted(Path(courts_dir).glob("*.sh")):
        if rx.search(script.read_text(encoding="utf-8", errors="replace")):
            hits.append(script.name)
    return hits


def classification_violations(rows, universe, courts_dir=None, expect_critical=()):
    names = [r["name"] for r in universe["repositories"]]
    v = []
    by_name = {}
    for row in rows:
        if len(row["ids"]) != 1:
            v.append(f"REFUSED(malformed): {row['node']} has {len(row['ids'])} dcterms:identifier values")
            continue
        by_name.setdefault(row["ids"][0], []).append(row)
    for name in sorted(set(names) - set(by_name)):
        v.append(f"REFUSED(unclassified): universe repository {name} has no classification (ARD F7)")
    for name in sorted(by_name):
        if name not in names:
            v.append(f"REFUSED(not_in_universe): classification {name} names no universe repository")
        if len(by_name[name]) > 1:
            nodes = ", ".join(r["node"] for r in by_name[name])
            v.append(f"REFUSED(duplicate): {name} has {len(by_name[name])} classifications ({nodes})")
    critical = set()
    for name in sorted(by_name):
        for row in by_name[name]:
            cls = [c[len(SJ):] if c.startswith(SJ) else c for c in row["classes"]]
            if len(cls) != 1 or cls[0] not in CLASSES:
                v.append(f"REFUSED(bad_class): {name} fleetClass {row['classes']} is not exactly one of {list(CLASSES)}")
                continue
            if row["required"] not in ([True], [False]):
                v.append(f"REFUSED(malformed): {name} needs exactly one boolean sj:requiredForCheckpoint")
            elif row["required"][0] != (cls[0] == "CriticalPath"):
                v.append(f"REFUSED(required_mismatch): {name} class {cls[0]} with requiredForCheckpoint {row['required'][0]}")
            if cls[0] == "CriticalPath":
                critical.add(name)
            if cls[0] == "Successor" and row["successor"] != [SUCCESSOR_TARGET]:
                v.append(f"REFUSED(successor_target): {name} Successor must carry sj:successorCheckpoint v23:GC-26.9.24")
            if cls[0] != "Successor" and row["successor"]:
                v.append(f"REFUSED(malformed): {name} class {cls[0]} carries sj:successorCheckpoint")
            for field in ("role", "reason", "evidence"):
                if not row[field] or not all(x.strip() for x in row[field]):
                    v.append(f"REFUSED(missing_field): {name} has no {field}")
            if row["under"] != [V23 + CHECKPOINT]:
                v.append(f"REFUSED(malformed): {name} must be sj:classifiedUnder v23:{CHECKPOINT}")
    for name in sorted(set(expect_critical) - critical):
        v.append(f"REFUSED(critical_path_missing): {name} must be classified CriticalPath")
    if courts_dir:
        if not Path(courts_dir).is_dir():
            raise CannotRun(f"--courts-dir {courts_dir} is not a directory")
        for repo in universe["repositories"]:
            hits = court_references(courts_dir, repo)
            if hits and repo["name"] not in critical:
                v.append(
                    f"REFUSED(court_executes_nonrequired): {repo['name']} is named by {', '.join(hits)} "
                    "but is not CriticalPath"
                )
    return v


def cmd_check_classification(a):
    universe = load_universe(a.universe)
    rows = load_classification(a.classification)
    v = classification_violations(rows, universe, a.courts_dir, a.expect_critical or ())
    for line in v:
        print(line)
    if v:
        print(f"check-classification: REFUSED ({len(v)} violations)")
        return 1
    counts = {}
    for row in rows:
        c = row["classes"][0][len(SJ):]
        counts[c] = counts.get(c, 0) + 1
    summary = ", ".join(f"{k}={counts[k]}" for k in sorted(counts))
    print(f"check-classification: OK {len(rows)} repositories classified exactly once ({summary})")
    return 0


# ── emit ────────────────────────────────────────────────────────────────────


def cmd_emit(a):
    obs = load_json(a.observations)
    rows = load_classification(a.classification)
    universe_like = {"repositories": [{"name": r["name"]} for r in obs.get("repositories", [])]}
    v = classification_violations(rows, universe_like)
    if v:
        for line in v:
            print(line)
        print("emit: REFUSED (classification does not cover the observations exactly once)")
        return 1
    cls = {r["ids"][0]: r for r in rows}
    subjects = {s["name"]: s for s in obs.get("subjects", [])}
    matrix = []
    for o in sorted(obs["repositories"], key=lambda r: r["name"]):
        c = cls[o["name"]]
        s = subjects.get(o["name"])
        matrix.append(
            {
                "name": o["name"],
                "path": o.get("path"),
                "head_sha": o.get("head_sha"),
                "branch": o.get("branch"),
                "default_ref": o.get("default_ref"),
                "default_sha": o.get("default_sha"),
                "ahead": o.get("ahead"),
                "behind": o.get("behind"),
                "dirty": o.get("dirty_paths"),
                "open_prs": None if o.get("open_prs") is None else len(o["open_prs"]),
                "fetch": (o.get("fetch") or {}).get("status"),
                "class": c["classes"][0][len(SJ):],
                "required": c["required"][0],
                "reason": c["reason"][0],
                "subject_path": s["path"] if s else None,
                "subject_sha": s["head_sha"] if s else None,
            }
        )
    digests = {
        "classification": sha256_file(a.classification),
        "observations": sha256_file(a.observations),
    }
    write_text(a.out_ttl, render_ttl(matrix, obs, digests))
    write_text(a.out_md, render_md(matrix, obs, digests))
    print(f"emit: {len(matrix)} rows -> {a.out_ttl}, {a.out_md}")
    return 0


def render_ttl(matrix, obs, digests):
    out = [
        f"@prefix sj: <{SJ}> .",
        f"@prefix v23: <{V23}> .",
        "@prefix dcterms: <http://purl.org/dc/terms/> .",
        "@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .",
        "",
        "# GENERATED by xaas scripts/sjira/fleet_matrix.py emit (GC23-11 bounded fleet). Do not hand-edit.",
        f"# classification {digests['classification']}",
        f"# observations   {digests['observations']}",
        "# A projection of observations + classification; it asserts no standing and no receipt.",
        "",
        "v23:fleet-matrix a sj:FleetMatrix ;",
        f"    sj:classifiedUnder v23:{CHECKPOINT} ;",
        f"    sj:observedAt {ttl_lit(obs.get('observed_at'))}^^xsd:dateTime ;",
        f"    sj:classificationDigest {ttl_lit(digests['classification'])} ;",
        f"    sj:observationsDigest {ttl_lit(digests['observations'])} ;",
        f"    sj:rowCount {len(matrix)} .",
        "",
    ]
    for m in matrix:
        props = [
            ("a", "sj:FleetMatrixRow"),
            ("sj:matrixOf", "v23:fleet-matrix"),
            ("dcterms:identifier", ttl_lit(m["name"])),
            ("sj:fleetClass", "sj:" + m["class"]),
            ("sj:requiredForCheckpoint", ttl_lit(m["required"])),
            ("sj:classificationReason", ttl_lit(m["reason"])),
        ]
        optional = [
            ("sj:repositoryPath", m["path"]),
            ("sj:observedSha", m["head_sha"]),
            ("sj:observedBranch", m["branch"]),
            ("sj:defaultBranch", m["default_ref"]),
            ("sj:defaultBranchSha", m["default_sha"]),
            ("sj:aheadCount", m["ahead"]),
            ("sj:behindCount", m["behind"]),
            ("sj:dirtyEntryCount", m["dirty"]),
            ("sj:openPullRequestCount", m["open_prs"]),
            ("sj:fetchStatus", m["fetch"]),
            ("sj:subjectPath", m["subject_path"]),
            ("sj:subjectSha", m["subject_sha"]),
        ]
        props += [(k, ttl_lit(val)) for k, val in optional if val is not None]
        body = " ;\n    ".join(f"{k} {val}" for k, val in props)
        out.append(f"v23:fleet-matrix-{local_name(m['name'])} {body} .")
        out.append("")
    return "\n".join(out)


def md_cell(value):
    if value is None:
        return "-"
    return str(value).replace("|", "\\|").replace("\n", " ")


def render_md(matrix, obs, digests):
    counts = {}
    for m in matrix:
        counts[m["class"]] = counts.get(m["class"], 0) + 1
    lines = [
        "# GC23-11 fleet matrix",
        "",
        "GENERATED by `python3 scripts/sjira/fleet_matrix.py emit` from `classification.ttl` and",
        "`observations.json`; do not hand-edit. Standing is not asserted here: the GC23-11 court",
        "(`docs/sjira/v26.9.23/courts/GC23-11.sh`) derives it from receipts at exact heads.",
        "",
        f"- observed at: {obs.get('observed_at')} (network: {str(obs.get('network')).lower()})",
        f"- classification: `{digests['classification']}`",
        f"- observations: `{digests['observations']}`",
        f"- classes: {', '.join(f'{k} {counts[k]}' for k in sorted(counts))}",
        "",
        "| repo | path | head sha | default-branch sha | ahead/behind | dirty | open PRs | class | required | reason |",
        "|---|---|---|---|---|---|---|---|---|---|",
    ]
    for m in matrix:
        ab = "-" if m["ahead"] is None else f"{m['ahead']}/{m['behind']}"
        head = m["head_sha"][:12] if m["head_sha"] else "-"
        dflt = f"{m['default_ref']}@{m['default_sha'][:12]}" if m["default_sha"] else md_cell(m["default_ref"])
        lines.append(
            "| "
            + " | ".join(
                [
                    md_cell(m["name"]),
                    md_cell(m["path"]),
                    head,
                    dflt,
                    ab,
                    md_cell(m["dirty"]),
                    md_cell(m["open_prs"]),
                    m["class"],
                    "yes" if m["required"] else "no",
                    md_cell(m["reason"]),
                ]
            )
            + " |"
        )
    subj = [m for m in matrix if m["subject_sha"]]
    if subj:
        lines += ["", "## Subjects under judgement", "", "| repo | subject path | subject sha |", "|---|---|---|"]
        for m in subj:
            lines.append(f"| {md_cell(m['name'])} | {md_cell(m['subject_path'])} | {m['subject_sha']} |")
    return "\n".join(lines) + "\n"


# ── check-standing ──────────────────────────────────────────────────────────


def receipt_names_repo(receipt_repo, name, int_path, universe_paths):
    """A receipt names the repo by name, slug tail, its universe path or its --int checkout.

    Paths are compared after realpath, so a relative --int or a /tmp -> /private/tmp alias
    still binds (the subject identity is the SHA check that follows, not the spelling)."""
    r = receipt_repo.rstrip("/")
    paths = {os.path.realpath(p) for p in (int_path, *universe_paths) if p}
    return (
        r == name
        or os.path.basename(r) == name
        or r.endswith("/" + name)
        or (os.path.isabs(r) and os.path.realpath(r) in paths)
    )


def load_receipts(dirs):
    """Reads every *.json under each receipts dir; nothing is dropped silently.

    Returns (receipts, unreadable, not_r): R receipts as (path, doc); files that could not be
    read or parsed, each printed as REFUSED(unreadable_receipt) with its exception (it cannot
    be evidence for any repository, so it can only lower standing, never raise it); and JSON
    files without an identity object, each printed as IGNORED(not_r_receipt)."""
    receipts, unreadable, not_r = [], [], []
    for d in dirs:
        if not Path(d).is_dir():
            print(f"note: receipts dir {d} absent")
            continue
        for p in sorted(Path(d).glob("*.json")):
            try:
                r = json.loads(p.read_text(encoding="utf-8"))
            except (OSError, ValueError) as exc:
                print(f"REFUSED(unreadable_receipt): {p}: {type(exc).__name__}: {exc}")
                unreadable.append(str(p))
                continue
            if isinstance(r, dict) and isinstance(r.get("identity"), dict):
                receipts.append((str(p), r))
            else:
                print(f"IGNORED(not_r_receipt): {p} has no identity object")
                not_r.append(str(p))
    return receipts, unreadable, not_r


def cmd_check_standing(a):
    rows = load_classification(a.classification)
    ints = parse_kv(a.int, "--int")
    universe_paths = {}
    if a.universe:
        for r in load_universe(a.universe)["repositories"]:
            if r.get("path"):
                universe_paths[r["name"]] = r["path"].rstrip("/")
    critical = sorted(
        r["ids"][0] for r in rows if len(r["ids"]) == 1 and r["classes"] == [SJ + "CriticalPath"]
    )
    if not critical:
        print("check-standing: REFUSED no CriticalPath repository classified (admission would be vacuous)")
        return 1
    validator = a.validator or DEFAULT_VALIDATOR
    if not Path(validator).is_file():
        raise CannotRun(f"validator {validator} not found")
    receipts, unreadable, not_r = load_receipts(a.receipts_dir or [])
    failures = 0
    for name in critical:
        if name not in ints:
            print(f"UNKNOWN: {name} is CriticalPath but no --int {name}=PATH names its subject")
            failures += 1
            continue
        head = observe_subject(name, ints[name])["head_sha"]
        cands = [
            (p, r)
            for p, r in receipts
            if receipt_names_repo(str(r["identity"].get("repo", "")), name, ints[name], {universe_paths.get(name, "")} - {""})
            and not any(str(r["identity"].get("subject", "")).startswith(x) for x in (a.exclude_subject_prefix or []))
        ]
        alive_exact = []
        for p, r in cands:
            sha = r["identity"].get("subject_sha")
            standing = (r.get("standing") or {}).get("value")
            if standing != "ALIVE":
                continue
            if sha != head:
                print(f"REFUSED(stale_subject): {p} ALIVE at {sha} but {name} head is {head} (ARD F6)")
                continue
            code, out, _ = run([sys.executable, validator, p], timeout=60)
            if code == 0 and out.startswith("ADMITTED"):
                alive_exact.append(p)
            else:
                print(f"REFUSED(not_admitted): {p} validator exit {code}: {out.strip().splitlines()[-1:] or ''}")
        if alive_exact:
            print(f"ALIVE: {name} head {head} <- {alive_exact[0]}")
        else:
            print(
                f"UNKNOWN: {name} has no admitted ALIVE receipt at exact head {head} "
                f"({len(cands)} receipts name it; {len(unreadable)} unreadable receipts bind no repository)"
            )
            failures += 1
    tally = f"receipts: {len(receipts)} read, {len(unreadable)} unreadable, {len(not_r)} not R"
    if failures:
        print(
            f"check-standing: NOT ALIVE ({failures} of {len(critical)} CriticalPath repositories lack "
            f"exact-head standing; {tally})"
        )
        return 1
    print(f"check-standing: ALIVE ({len(critical)} CriticalPath repositories at exact heads; {tally})")
    return 0


# ── CLI ─────────────────────────────────────────────────────────────────────


def main(argv=None):
    ap = argparse.ArgumentParser(prog="fleet_matrix.py", description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("universe")
    p.add_argument("--fleet-ttl", required=True)
    p.add_argument("--survey", required=True)
    p.add_argument("--prose", required=True)
    p.add_argument("--prose-path", help="repo-relative path recorded for the prose source")
    p.add_argument("--owner", default="seanchatmangpt")
    p.add_argument("--search-root", action="append")
    p.add_argument("--no-network", action="store_true")
    p.add_argument("--out", required=True)

    p = sub.add_parser("observe")
    p.add_argument("--universe", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--observed-at", required=True)
    p.add_argument("--no-network", action="store_true")
    p.add_argument("--int", action="append", metavar="NAME=PATH")
    p.add_argument("--timeout", type=int, default=180)
    p.add_argument("--jobs", type=int, default=4)

    p = sub.add_parser("emit")
    p.add_argument("--classification", required=True)
    p.add_argument("--observations", required=True)
    p.add_argument("--out-ttl", required=True)
    p.add_argument("--out-md", required=True)

    p = sub.add_parser("check-classification")
    p.add_argument("--classification", required=True)
    p.add_argument("--universe", required=True)
    p.add_argument("--courts-dir")
    p.add_argument("--expect-critical", action="append", metavar="NAME")

    p = sub.add_parser("check-standing")
    p.add_argument("--classification", default="docs/sjira/v26.9.23/fleet/classification.ttl")
    p.add_argument("--universe")
    p.add_argument("--receipts-dir", action="append")
    p.add_argument("--int", action="append", metavar="NAME=PATH")
    p.add_argument("--exclude-subject-prefix", action="append", metavar="PREFIX")
    p.add_argument("--validator")

    a = ap.parse_args(argv)
    handlers = {
        "universe": cmd_universe,
        "observe": cmd_observe,
        "emit": cmd_emit,
        "check-classification": cmd_check_classification,
        "check-standing": cmd_check_standing,
    }
    try:
        return handlers[a.cmd](a)
    except CannotRun as exc:
        print(f"{a.cmd}: CANNOT RUN: {exc}", file=sys.stderr)
        return 2
    except Exception:
        # An uncaught exception would exit 1, the REFUSED code; a crash is "cannot run" (2),
        # printed with its traceback, so exit 1 only ever comes from an explicit refusal.
        traceback.print_exc()
        print(f"{a.cmd}: CANNOT RUN: internal error (traceback above)", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
