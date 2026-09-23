"""Chicago tests for scripts/sjira/fleet_matrix.py (GC23-11 bounded fleet).

Real collaborators only: real temporary git repositories (bare origin + clone), the real
script run as a subprocess, real rdflib parsing, and the real receipt validator
(~/.claude/dfcm/validate_receipt.py). No test doubles of any kind. Network is never used:
remotes are local bare repositories and gh is never reached (no GitHub slug in the fixtures).
"""

import json
import os
import shutil
import site
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "fleet_matrix.py"
VALIDATOR = Path.home() / ".claude/dfcm/validate_receipt.py"
COURT = SCRIPT.parents[2] / "docs/sjira/v26.9.23/courts/GC23-11.sh"
SJ = "https://ggen-igniter.dev/ontology/semantic-jira#"
V23 = "https://ggen-igniter.dev/sjira/v26.9.23#"


class Fixture:
    """A temp dir with an isolated git config (no user hooks, no signing)."""

    def __init__(self):
        self._tmp = tempfile.TemporaryDirectory(prefix="fleet-matrix-")
        self.root = Path(self._tmp.name).resolve()
        cfg = self.root / "gitconfig"
        cfg.write_text(
            "[user]\n\tname = fleet test\n\temail = fleet@test.invalid\n"
            "[init]\n\tdefaultBranch = main\n[commit]\n\tgpgsign = false\n"
            "[tag]\n\tgpgsign = false\n[core]\n\thooksPath = /dev/null\n"
        )
        self.env = dict(os.environ, GIT_CONFIG_GLOBAL=str(cfg), GIT_CONFIG_NOSYSTEM="1")

    def close(self):
        self._tmp.cleanup()

    def git(self, cwd, *args):
        cp = subprocess.run(["git", *args], cwd=cwd, env=self.env, capture_output=True, text=True)
        if cp.returncode != 0:
            raise AssertionError(f"git {args} failed: {cp.stderr}")
        return cp.stdout.strip()

    def commit(self, repo, name, text):
        (Path(repo) / name).write_text(text)
        self.git(repo, "add", name)
        self.git(repo, "commit", "-q", "-m", f"add {name}")
        return self.git(repo, "rev-parse", "HEAD")

    def repo(self, name):
        """seed -> bare origin -> working clone with origin/HEAD set; returns the clone path."""
        seed = self.root / f"{name}-seed"
        seed.mkdir()
        self.git(seed, "init", "-q")
        self.commit(seed, "README", f"{name}\n")
        bare = self.root / f"{name}.git"
        self.git(self.root, "clone", "-q", "--bare", str(seed), str(bare))
        work = self.root / name
        self.git(self.root, "clone", "-q", str(bare), str(work))
        return work

    def run(self, *args):
        cp = subprocess.run(
            [sys.executable, str(SCRIPT), *map(str, args)],
            cwd=self.root,
            env=self.env,
            capture_output=True,
            text=True,
        )
        return cp.returncode, cp.stdout + cp.stderr

    def write(self, name, text):
        p = self.root / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)
        return p


def universe(fx, repos):
    doc = {
        "schema": "xaas.fleet.universe/v1",
        "repositories": [
            {"name": n, "path": str(p) if p else None, "github": None, "default_remote": "origin" if p else None}
            for n, p in sorted(repos.items())
        ],
    }
    return fx.write("universe.json", json.dumps(doc, indent=2, sort_keys=True) + "\n")


def classification(fx, rows, name="classification.ttl"):
    """rows: list of (repo, class, required[, successor_target])."""
    out = [
        f"@prefix sj: <{SJ}> .",
        f"@prefix v23: <{V23}> .",
        "@prefix dcterms: <http://purl.org/dc/terms/> .",
        "",
    ]
    for i, row in enumerate(rows):
        repo, cls, required = row[:3]
        succ = row[3] if len(row) > 3 else ("v23:GC-26.9.24" if cls == "Successor" else None)
        lines = [
            f"v23:fleet-{i} a sj:FleetClassification",
            f'dcterms:identifier "{repo}"',
            "sj:classifiedUnder v23:GC-26.9.23",
            f"sj:fleetClass sj:{cls}",
            f"sj:requiredForCheckpoint {'true' if required else 'false'}",
            'sj:fleetRole "test role"',
            f'sj:classificationReason "test reason for {repo}"',
            'sj:evidence "test evidence"',
        ]
        if succ:
            lines.append(f"sj:successorCheckpoint {succ}")
        out.append(" ;\n    ".join(lines) + " .\n")
    return fx.write(name, "\n".join(out))


def receipt(fx, name, repo, sha, standing="ALIVE", subject="fleet/test"):
    doc = {
        "identity": {"subject": subject, "repo": str(repo), "subject_sha": sha, "base_sha": sha},
        "authority": {"ceiling": "OBSERVE", "grant": "NONE", "actor": "test_fleet_matrix"},
        "consequence": {"commits": [], "files_changed": [], "remote_effects": []},
        "replay": {"commands": [{"cmd": "git rev-parse HEAD", "exit": 0, "cwd": str(repo)}]},
        "standing": {"value": standing, "derived_from": f"git rev-parse HEAD at {sha}"},
    }
    return fx.write(f"receipts/{name}.json", json.dumps(doc, indent=2) + "\n")


class FleetMatrixTest(unittest.TestCase):
    def setUp(self):
        self.fx = Fixture()
        self.addCleanup(self.fx.close)

    # ── universe ────────────────────────────────────────────────────────────

    def test_universe_is_the_sorted_union_of_fleet_survey_and_ard_section_4(self):
        fx = self.fx
        alpha = fx.repo("alpha")
        delta = fx.repo("delta")  # found only through --search-root (ARD heading, no fleet/survey row)
        fx.write(
            "fleet.ttl",
            f"@prefix sj: <{SJ}> .\n@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .\n"
            f'<file://{alpha}> a sj:ObservedRepository ; rdfs:label "alpha" ; sj:fleetRole "relevant" ; '
            f'sj:repositoryPath "{alpha}" .\n',
        )
        fx.write(
            "survey.json",
            json.dumps({"perRepo": [{"survey": {"repo": "alpha", "path": str(alpha), "relevant": True}},
                                    {"survey": {"repo": "beta (someone/beta)", "path": None, "relevant": False}}]}),
        )
        fx.write(
            "prose.md",
            "# 4. Product Goal\n## notarepo\n# 4. Repository Responsibilities\n## delta\n\n## alpha\n# 5. Next\n## notrepo\n",
        )
        code, out = fx.run(
            "universe", "--fleet-ttl", "fleet.ttl", "--survey", "survey.json", "--prose", "prose.md",
            "--search-root", fx.root, "--no-network", "--out", "u.json",
        )
        self.assertEqual(code, 0, out)
        u = json.loads((fx.root / "u.json").read_text())
        self.assertEqual([r["name"] for r in u["repositories"]], ["alpha", "beta", "delta"])
        by = {r["name"]: r for r in u["repositories"]}
        self.assertEqual(by["alpha"]["sources"], ["ard-4", "fleet.ttl", "survey.json"])
        self.assertEqual(by["beta"]["sources"], ["survey.json"])
        self.assertIsNone(by["beta"]["path"])
        self.assertEqual(by["delta"]["path"], str(delta))
        self.assertEqual(by["delta"]["sources"], ["ard-4", "local-checkout"])
        # deterministic: a second run is byte-identical
        code, out = fx.run(
            "universe", "--fleet-ttl", "fleet.ttl", "--survey", "survey.json", "--prose", "prose.md",
            "--search-root", fx.root, "--no-network", "--out", "u2.json",
        )
        self.assertEqual(code, 0, out)
        self.assertEqual((fx.root / "u.json").read_bytes(), (fx.root / "u2.json").read_bytes())

    # ── check-classification (ARD F7) ───────────────────────────────────────

    def test_complete_classification_is_admitted(self):
        fx = self.fx
        u = universe(fx, {"alpha": None, "beta": None})
        c = classification(fx, [("alpha", "CriticalPath", True), ("beta", "Successor", False)])
        code, out = fx.run("check-classification", "--classification", c, "--universe", u)
        self.assertEqual(code, 0, out)
        self.assertIn("CriticalPath=1, Successor=1", out)

    def test_f7_unclassified_repository_fails_the_fleet_checkpoint(self):
        fx = self.fx
        c = classification(fx, [("alpha", "CriticalPath", True), ("beta", "Successor", False)])
        u = universe(fx, {"alpha": None, "beta": None, "gamma": None})
        code, out = fx.run("check-classification", "--classification", c, "--universe", u)
        self.assertEqual(code, 1, out)
        self.assertIn("REFUSED(unclassified): universe repository gamma", out)
        self.assertNotIn("repository alpha", out)

    def test_duplicate_classification_is_refused(self):
        fx = self.fx
        u = universe(fx, {"alpha": None, "beta": None})
        c = classification(
            fx, [("alpha", "CriticalPath", True), ("beta", "Successor", False), ("beta", "Blocked", False)]
        )
        code, out = fx.run("check-classification", "--classification", c, "--universe", u)
        self.assertEqual(code, 1, out)
        self.assertIn("REFUSED(duplicate): beta has 2 classifications", out)

    def test_classification_outside_the_universe_is_refused(self):
        fx = self.fx
        u = universe(fx, {"alpha": None})
        c = classification(fx, [("alpha", "CriticalPath", True), ("zeta", "Refused", False)])
        code, out = fx.run("check-classification", "--classification", c, "--universe", u)
        self.assertEqual(code, 1, out)
        self.assertIn("REFUSED(not_in_universe): classification zeta", out)

    def test_required_flag_and_successor_target_are_checked(self):
        fx = self.fx
        u = universe(fx, {"alpha": None, "beta": None, "gamma": None})
        c = classification(
            fx,
            [
                ("alpha", "Successor", True),
                ("beta", "Successor", False, "v23:GC-26.9.23"),
                ("gamma", "Sideways", False),
            ],
        )
        code, out = fx.run("check-classification", "--classification", c, "--universe", u)
        self.assertEqual(code, 1, out)
        self.assertIn("REFUSED(required_mismatch): alpha class Successor with requiredForCheckpoint True", out)
        self.assertIn("REFUSED(successor_target): beta", out)
        self.assertIn("REFUSED(bad_class): gamma", out)

    def test_court_executing_a_nonrequired_repository_is_refused(self):
        fx = self.fx
        beta = fx.repo("beta")
        u = universe(fx, {"alpha": None, "beta": beta})
        fx.write("courts/GC23-9.sh", 'python3 "$BETA_DIR/run.py"\n')
        fx.write("courts/GC23-1.sh", 'echo "UNKNOWN: GC23-1 machinery lands in lane V23-B"\nexit 3\n')
        c = classification(fx, [("alpha", "CriticalPath", True), ("beta", "Successor", False)])
        code, out = fx.run(
            "check-classification", "--classification", c, "--universe", u, "--courts-dir", fx.root / "courts"
        )
        self.assertEqual(code, 1, out)
        self.assertIn("REFUSED(court_executes_nonrequired): beta is named by GC23-9.sh", out)
        c2 = classification(fx, [("alpha", "CriticalPath", True), ("beta", "CriticalPath", True)], "c2.ttl")
        code, out = fx.run(
            "check-classification", "--classification", c2, "--universe", u, "--courts-dir", fx.root / "courts",
            "--expect-critical", "alpha",
        )
        self.assertEqual(code, 0, out)
        code, out = fx.run(
            "check-classification", "--classification", c2, "--universe", u, "--expect-critical", "gamma",
        )
        self.assertEqual(code, 1, out)
        self.assertIn("REFUSED(critical_path_missing): gamma", out)

    # ── observe + emit ──────────────────────────────────────────────────────

    def test_observe_records_exact_git_state_without_touching_the_checkout(self):
        fx = self.fx
        alpha = fx.repo("alpha")
        base = fx.git(alpha, "rev-parse", "HEAD")
        head = fx.commit(alpha, "local.txt", "unpushed\n")
        (alpha / "scratch.txt").write_text("untracked\n")
        refs_before = fx.git(alpha, "for-each-ref", "refs/heads", "refs/tags")
        status_before = fx.git(alpha, "status", "--porcelain")
        index_before = (alpha / ".git/index").read_bytes()
        u = universe(fx, {"alpha": alpha, "nolocal": None})
        code, out = fx.run(
            "observe", "--universe", u, "--out", "obs.json", "--observed-at", "2026-09-23T06:00:00Z",
            "--int", f"alpha={alpha}",
        )
        self.assertEqual(code, 0, out)
        index_after = (alpha / ".git/index").read_bytes()
        obs = json.loads((fx.root / "obs.json").read_text())
        a = {r["name"]: r for r in obs["repositories"]}["alpha"]
        self.assertEqual(a["head_sha"], head)
        self.assertEqual(a["branch"], "main")
        self.assertEqual(a["default_ref"], "main")
        self.assertEqual(a["default_sha"], base)
        self.assertEqual((a["ahead"], a["behind"]), (1, 0))
        self.assertEqual(a["dirty_paths"], 1)
        self.assertEqual(a["fetch"], {"exit": 0, "status": "ok"})
        self.assertEqual(obs["subjects"], [
            {"branch": "main", "dirty_paths": 1, "head_sha": head, "name": "alpha", "path": str(alpha)}
        ])
        n = {r["name"]: r for r in obs["repositories"]}["nolocal"]
        self.assertEqual(n["fetch"]["status"], "skipped")
        self.assertIsNone(n["head_sha"])
        self.assertEqual(index_after, index_before)
        self.assertEqual(fx.git(alpha, "for-each-ref", "refs/heads", "refs/tags"), refs_before)
        self.assertEqual(fx.git(alpha, "status", "--porcelain"), status_before)

    def test_emit_is_byte_identical_for_identical_inputs_and_refuses_uncovered_rows(self):
        fx = self.fx
        alpha, beta = fx.repo("alpha"), fx.repo("beta")
        u = universe(fx, {"alpha": alpha, "beta": beta})
        code, out = fx.run(
            "observe", "--universe", u, "--out", "obs.json", "--observed-at", "2026-09-23T06:00:00Z",
            "--no-network", "--int", f"alpha={alpha}",
        )
        self.assertEqual(code, 0, out)
        c = classification(fx, [("beta", "Successor", False), ("alpha", "CriticalPath", True)])
        for d in ("one", "two"):
            code, out = fx.run(
                "emit", "--classification", c, "--observations", "obs.json",
                "--out-ttl", f"{d}/matrix.ttl", "--out-md", f"{d}/matrix.md",
            )
            self.assertEqual(code, 0, out)
        for f in ("matrix.ttl", "matrix.md"):
            self.assertEqual((fx.root / "one" / f).read_bytes(), (fx.root / "two" / f).read_bytes())
        md = (fx.root / "one/matrix.md").read_text()
        self.assertLess(md.index("| alpha |"), md.index("| beta |"))
        self.assertIn("| CriticalPath | yes |", md)
        import rdflib

        g = rdflib.Graph().parse(fx.root / "one/matrix.ttl", format="turtle")
        rows = set(g.subjects(rdflib.RDF.type, rdflib.URIRef(SJ + "FleetMatrixRow")))
        self.assertEqual(len(rows), 2)
        head = fx.git(alpha, "rev-parse", "HEAD")
        self.assertIn((None, rdflib.URIRef(SJ + "subjectSha"), rdflib.Literal(head)), g)
        c_short = classification(fx, [("alpha", "CriticalPath", True)], "short.ttl")
        code, out = fx.run(
            "emit", "--classification", c_short, "--observations", "obs.json",
            "--out-ttl", "x/matrix.ttl", "--out-md", "x/matrix.md",
        )
        self.assertEqual(code, 1, out)
        self.assertIn("REFUSED(unclassified): universe repository beta", out)
        self.assertFalse((fx.root / "x/matrix.ttl").exists())

    # ── check-standing (ARD F6) ─────────────────────────────────────────────

    def _standing(self, alpha, *extra):
        c = classification(self.fx, [("alpha", "CriticalPath", True), ("beta", "Successor", False)])
        return self.fx.run(
            "check-standing", "--classification", c, "--receipts-dir", self.fx.root / "receipts",
            "--int", f"alpha={alpha}", "--validator", VALIDATOR, *extra,
        )

    @unittest.skipUnless(VALIDATOR.is_file(), f"real receipt validator absent: {VALIDATOR}")
    def test_check_standing_admits_an_alive_receipt_at_the_exact_head(self):
        alpha = self.fx.repo("alpha")
        head = self.fx.git(alpha, "rev-parse", "HEAD")
        receipt(self.fx, "alpha", alpha, head)
        code, out = self._standing(alpha)
        self.assertEqual(code, 0, out)
        self.assertIn(f"ALIVE: alpha head {head}", out)

    @unittest.skipUnless(VALIDATOR.is_file(), f"real receipt validator absent: {VALIDATOR}")
    def test_check_standing_binds_a_relative_int_path_to_an_absolute_receipt_repo(self):
        # Regression (found by the court-level falsifier): --int given relative to the cwd must
        # bind a receipt whose identity.repo is the absolute path of the same checkout.
        gamma = self.fx.repo("gamma")
        head = self.fx.git(gamma, "rev-parse", "HEAD")
        receipt(self.fx, "gamma", gamma, head)
        c = classification(self.fx, [("ggen_igniter", "CriticalPath", True)], "rel.ttl")
        code, out = self.fx.run(
            "check-standing", "--classification", c, "--receipts-dir", self.fx.root / "receipts",
            "--int", "ggen_igniter=gamma", "--validator", VALIDATOR,
        )
        self.assertEqual(code, 0, out)
        self.assertIn(f"ALIVE: ggen_igniter head {head}", out)

    @unittest.skipUnless(VALIDATOR.is_file(), f"real receipt validator absent: {VALIDATOR}")
    def test_f6_receipt_at_a_stale_subject_no_longer_applies(self):
        alpha = self.fx.repo("alpha")
        old = self.fx.git(alpha, "rev-parse", "HEAD")
        receipt(self.fx, "alpha", alpha, old)
        code, out = self._standing(alpha)
        self.assertEqual(code, 0, out)
        new = self.fx.commit(alpha, "change.txt", "covered subject changed\n")
        code, out = self._standing(alpha)
        self.assertEqual(code, 1, out)
        self.assertIn(f"REFUSED(stale_subject): {self.fx.root / 'receipts/alpha.json'} ALIVE at {old}", out)
        self.assertIn(f"UNKNOWN: alpha has no admitted ALIVE receipt at exact head {new}", out)

    @unittest.skipUnless(VALIDATOR.is_file(), f"real receipt validator absent: {VALIDATOR}")
    def test_check_standing_refuses_non_alive_excluded_and_unobserved_subjects(self):
        alpha = self.fx.repo("alpha")
        head = self.fx.git(alpha, "rev-parse", "HEAD")
        receipt(self.fx, "alpha-unknown", alpha, head, standing="UNKNOWN")
        code, out = self._standing(alpha)
        self.assertEqual(code, 1, out)
        self.assertIn("UNKNOWN: alpha has no admitted ALIVE receipt", out)
        receipt(self.fx, "alpha-gate", alpha, head, subject="GC-26.9.23/GC23-11")
        code, out = self._standing(alpha, "--exclude-subject-prefix", "GC-26.9.23/")
        self.assertEqual(code, 1, out)
        code, out = self._standing(alpha)
        self.assertEqual(code, 0, out)
        c = classification(self.fx, [("alpha", "CriticalPath", True)], "only.ttl")
        code, out = self.fx.run(
            "check-standing", "--classification", c, "--receipts-dir", self.fx.root / "receipts",
            "--validator", VALIDATOR,
        )
        self.assertEqual(code, 1, out)
        self.assertIn("UNKNOWN: alpha is CriticalPath but no --int alpha=PATH names its subject", out)

    @unittest.skipUnless(VALIDATOR.is_file(), f"real receipt validator absent: {VALIDATOR}")
    def test_check_standing_refuses_a_receipt_the_validator_does_not_admit(self):
        alpha = self.fx.repo("alpha")
        head = self.fx.git(alpha, "rev-parse", "HEAD")
        p = receipt(self.fx, "alpha", alpha, head)
        doc = json.loads(p.read_text())
        doc["replay"]["commands"][0]["exit"] = 1  # ALIVE with a failing replay: admission_vacuous
        p.write_text(json.dumps(doc))
        code, out = self._standing(alpha)
        self.assertEqual(code, 1, out)
        self.assertIn("REFUSED(not_admitted)", out)


    @unittest.skipUnless(VALIDATOR.is_file(), f"real receipt validator absent: {VALIDATOR}")
    def test_check_standing_reports_unreadable_and_non_r_receipts_instead_of_dropping_them(self):
        # Doctrine court (repair 1): a receipt that cannot be read must be typed and counted,
        # never skipped silently; it can lower standing, never raise it.
        alpha = self.fx.repo("alpha")
        head = self.fx.git(alpha, "rev-parse", "HEAD")
        broken = self.fx.write("receipts/broken.json", '{"identity": {"repo": ')
        not_r = self.fx.write("receipts/list.json", "[]\n")
        a_dir = self.fx.root / "receipts/dir.json"  # a directory matching *.json: read raises OSError
        a_dir.mkdir()
        code, out = self._standing(alpha)
        self.assertEqual(code, 1, out)
        self.assertIn(f"REFUSED(unreadable_receipt): {broken}: JSONDecodeError", out)
        self.assertIn(f"REFUSED(unreadable_receipt): {a_dir}: IsADirectoryError", out)
        self.assertIn(f"IGNORED(not_r_receipt): {not_r} has no identity object", out)
        self.assertIn("(0 receipts name it; 2 unreadable receipts bind no repository)", out)
        self.assertIn("receipts: 0 read, 2 unreadable, 1 not R", out)
        receipt(self.fx, "alpha", alpha, head)
        code, out = self._standing(alpha)
        self.assertEqual(code, 0, out)
        self.assertIn(f"ALIVE: alpha head {head}", out)
        self.assertIn(f"REFUSED(unreadable_receipt): {broken}", out)
        self.assertIn("receipts: 1 read, 2 unreadable, 1 not R", out)

    def test_an_internal_error_exits_cannot_run_not_refused(self):
        # Exit 1 is reserved for explicit refusals; a crash must not read as an F7 refusal.
        fx = self.fx
        u = fx.write("universe.json", "[]\n")  # valid JSON, wrong shape: load_universe crashes
        c = classification(fx, [("alpha", "CriticalPath", True)])
        code, out = fx.run("check-classification", "--classification", c, "--universe", u)
        self.assertEqual(code, 2, out)
        self.assertIn("Traceback", out)
        self.assertIn("check-classification: CANNOT RUN: internal error", out)
        self.assertNotIn("REFUSED", out)

    # ── GC23-11.sh court: typed exit mapping ────────────────────────────────

    def _court_tree(self, universe_text=None, rows=None):
        """A real xaas-shaped checkout holding the real script and court (symlinks), plus a
        real ggen_igniter checkout; returns (xaas, ggen_igniter)."""
        fx = self.fx
        xaas, gi = fx.repo("xaas"), fx.repo("ggen_igniter")
        (xaas / "scripts/sjira").mkdir(parents=True)
        os.symlink(SCRIPT, xaas / "scripts/sjira/fleet_matrix.py")
        courts = xaas / "docs/sjira/v26.9.23/courts"
        courts.mkdir(parents=True)
        os.symlink(COURT, courts / "GC23-11.sh")
        fleet = xaas / "docs/sjira/v26.9.23/fleet"
        fleet.mkdir(parents=True)
        if universe_text is None:
            universe_text = json.dumps(
                {"schema": "xaas.fleet.universe/v1", "repositories": [
                    {"name": "gamma", "path": None, "github": None, "default_remote": None},
                    {"name": "ggen_igniter", "path": str(gi), "github": None, "default_remote": "origin"},
                    {"name": "xaas", "path": str(xaas), "github": None, "default_remote": "origin"},
                ]}, indent=2, sort_keys=True) + "\n"
        (fleet / "universe.json").write_text(universe_text)
        if rows is None:
            rows = [("gamma", "Successor", False), ("ggen_igniter", "CriticalPath", True), ("xaas", "CriticalPath", True)]
        shutil.copy(classification(fx, rows, "court-classification.ttl"), fleet / "classification.ttl")
        return xaas, gi

    def _court(self, xaas, gi, **env):
        run_env = dict(
            self.fx.env,
            XAAS_DIR=str(xaas),
            GGEN_IGNITER_DIR=str(gi),
            GC23_FLEET_RECEIPTS_DIR=str(self.fx.root / "fleet-receipts"),
            TMPDIR=str(self.fx.root),
        )
        run_env.update(env)
        cp = subprocess.run(
            ["sh", str(COURT)], cwd=xaas, env=run_env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True
        )
        lines = [ln.strip() for ln in cp.stdout.splitlines() if ln.strip()]
        return cp.returncode, (lines[-1] if lines else ""), cp.stdout

    def test_court_reports_a_classification_that_cannot_run_as_unknown_not_refused(self):
        xaas, gi = self._court_tree(universe_text='{"repositories": [')
        code, last, out = self._court(xaas, gi)
        self.assertEqual(code, 3, out)
        self.assertEqual(last, "UNKNOWN: GC23-11 check-classification could not run (exit 2)", out)
        self.assertNotIn("REFUSED: GC23-11", out)

    def test_court_refuses_an_unclassified_repository_ard_f7(self):
        xaas, gi = self._court_tree(rows=[("ggen_igniter", "CriticalPath", True), ("xaas", "CriticalPath", True)])
        code, last, out = self._court(xaas, gi)
        self.assertEqual(code, 1, out)
        self.assertEqual(last, "REFUSED: GC23-11 fleet classification (ARD F7) check-classification exit 1", out)
        self.assertIn("REFUSED(unclassified): universe repository gamma", out)

    def test_court_reports_check_standing_that_cannot_run_as_unknown(self):
        xaas, gi = self._court_tree()
        nohome = self.fx.root / "nohome"  # a host without ~/.claude/dfcm/validate_receipt.py
        nohome.mkdir()
        # keep the interpreter's user site (where rdflib may live) while HOME moves
        code, last, out = self._court(xaas, gi, HOME=str(nohome), PYTHONUSERBASE=site.getuserbase())
        self.assertEqual(code, 3, out)
        self.assertEqual(last, "UNKNOWN: GC23-11 check-standing could not run (exit 2)", out)
        self.assertIn("check-standing: CANNOT RUN: validator", out)

    def test_court_reports_absent_rdflib_as_unknown_not_an_f7_refusal(self):
        # The doctrine court's example: rdflib absent used to crash with exit 1 and read as
        # "REFUSED ... (ARD F7)". Hide the user site; skip visibly if rdflib is installed
        # system-wide (then this host cannot lose it without uninstalling).
        env = dict(self.fx.env, PYTHONNOUSERSITE="1")
        probe = subprocess.run(["python3", "-c", "import rdflib"], env=env, capture_output=True)
        if probe.returncode == 0:
            self.skipTest("rdflib is importable without the user site; cannot make it absent here")
        xaas, gi = self._court_tree()
        code, last, out = self._court(xaas, gi, PYTHONNOUSERSITE="1")
        self.assertEqual(code, 3, out)
        self.assertEqual(last, "UNKNOWN: GC23-11 check-classification could not run (exit 2)", out)
        self.assertIn("check-classification: CANNOT RUN: rdflib not importable", out)
        self.assertNotIn("Traceback", out)
        self.assertNotIn("REFUSED", out)

    @unittest.skipUnless(VALIDATOR.is_file(), f"real receipt validator absent: {VALIDATOR}")
    def test_court_is_unknown_without_exact_head_receipts_and_alive_with_them(self):
        xaas, gi = self._court_tree()
        code, last, out = self._court(xaas, gi)
        self.assertEqual(code, 3, out)
        self.assertEqual(
            last, "UNKNOWN: GC23-11 CriticalPath repositories lack exact-head standing (check-standing exit 1)", out
        )
        rdir = self.fx.root / "fleet-receipts"
        for name, repo in (("xaas", xaas), ("ggen_igniter", gi)):
            p = receipt(self.fx, f"court-{name}", repo, self.fx.git(repo, "rev-parse", "HEAD"))
            rdir.mkdir(exist_ok=True)
            shutil.move(str(p), rdir / p.name)
        (rdir / "corrupt.json").write_text("{")
        code, last, out = self._court(xaas, gi)
        self.assertEqual(code, 0, out)
        self.assertTrue(last.startswith("ALIVE: GC23-11"), out)
        self.assertIn(f"REFUSED(unreadable_receipt): {rdir / 'corrupt.json'}", out)


if __name__ == "__main__":
    unittest.main()
