"""Shared real-collaborator fixtures for the APS court/backlog tests.

Nothing here is a test double: candidates are real `git clone --local` copies
of a real APS checkout with real commits, and the court/backlog are run as real
subprocesses. The source checkout is only ever read.
"""
from __future__ import annotations

import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
from types import SimpleNamespace

HERE = pathlib.Path(__file__).resolve().parent
VERIFIERS = HERE.parent
COURT = pathlib.Path(os.environ.get("APS_COURT_PATH", str(VERIFIERS / "aps_dod_court.py")))
BACKLOG = VERIFIERS / "aps_backlog.py"

_SCRATCH_CLONE = (
    "/private/tmp/claude-501/-Users-sac-dev-zcode-cli/b7d87048-101f-406e-a6f3-99a4a5b279db/scratchpad/aps"
)

GIT_ENV = {
    **os.environ,
    "GIT_AUTHOR_NAME": "candidate", "GIT_AUTHOR_EMAIL": "candidate@example.invalid",
    "GIT_COMMITTER_NAME": "candidate", "GIT_COMMITTER_EMAIL": "candidate@example.invalid",
}


def aps_clone():
    for cand in (os.environ.get("APS_CLONE"), _SCRATCH_CLONE):
        if cand and (pathlib.Path(cand) / "contracts").is_dir():
            return pathlib.Path(cand)
    return None


APS = aps_clone()
SKIP_REASON = "no APS checkout found (set APS_CLONE to a clone of agile-protocol-specification)"


def sh(*cmd, cwd=None, env=None, check=True):
    proc = subprocess.run(list(map(str, cmd)), cwd=cwd, env=env or GIT_ENV, capture_output=True, text=True)
    if check and proc.returncode != 0:
        raise RuntimeError(f"{cmd} failed: {proc.stderr.strip()}")
    return proc.stdout.strip()


def backlog_items(repo, *extra):
    out = sh(sys.executable, BACKLOG, "--repo", repo, *extra)
    return {i["id"]: i for i in json.loads(out)["items"]}


class Candidate:
    """A throwaway APS checkout the 'worker' commits into."""

    _counter = 0

    def __init__(self, root: pathlib.Path):
        Candidate._counter += 1
        self.root = root
        self.path = root / f"repo-{Candidate._counter}"
        sh("git", "clone", "--quiet", "--local", "--no-hardlinks", APS, self.path)
        self.base = sh("git", "-C", self.path, "rev-parse", "HEAD")

    def write(self, rel, text):
        target = self.path / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text)

    def append(self, rel, text):
        with open(self.path / rel, "a") as fh:
            fh.write(text)

    def commit(self, message="candidate"):
        sh("git", "-C", self.path, "add", "-A")
        sh("git", "-C", self.path, "commit", "--quiet", "-m", message)
        return self.head()

    def head(self):
        return sh("git", "-C", self.path, "rev-parse", "HEAD")

    def status(self):
        return sh("git", "-C", self.path, "status", "--porcelain", "--untracked-files=all")

    def ticket(self, item, *, allowed_paths=None, mutants=None, attempt=1, name="ticket", **overrides):
        ticket = {
            "schemaVersion": "aps-ticket/1",
            "item": item["id"],
            "attempt": attempt,
            "base_sha": self.base,
            "goal": item["goal"],
            "allowed_paths": allowed_paths if allowed_paths is not None else item["allowed_paths"],
            "min_new_tests": item["min_new_tests"],
            "min_kill_ratio": item["min_kill_ratio"],
            "mutants": item["mutants"] if mutants is None else mutants,
            "history": [],
        }
        ticket.update(overrides)
        path = self.root / f"{name}-{self.path.name}.json"
        path.write_text(json.dumps(ticket))
        return path

    def run_court(self, ticket_path, *, head=None, executor="glm-worker-1", verifier="aps-court-1",
                  env=None, worktree=None, extra=()):
        cmd = [sys.executable, str(COURT), "--worktree", str(worktree or self.path),
               "--head", head or self.head(), "--ticket", str(ticket_path),
               "--executor", executor, "--verifier-identity", verifier, *extra]
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=900, env=env or os.environ.copy())
        receipt = None
        lines = [ln for ln in proc.stdout.splitlines() if ln.strip()]
        if lines:
            try:
                receipt = json.loads(lines[-1])
            except ValueError:
                receipt = None
        gates = {}
        if receipt:
            gates = {g["id"]: g for g in receipt["observation"]["gates"]}
        return SimpleNamespace(rc=proc.returncode, receipt=receipt, gates=gates,
                               stdout=proc.stdout, stderr=proc.stderr)


# Banned test-double tokens are assembled at runtime so a plain grep over this
# directory stays a meaningful signal that no test here uses test doubles.
BANNED_TOKENS = ("unittest." + "mock", "Magic" + "Mock", "monkey" + "patch")
BANNED_IMPORT = "from unittest import " + "mo" + "ck"


def tempdir():
    return pathlib.Path(tempfile.mkdtemp(prefix="aps-court-test-"))


def cleanup(path):
    shutil.rmtree(path, ignore_errors=True)


# ---------------------------------------------------------------- test files
STANDING_GOOD = '''import json
import pathlib
import unittest

import jsonschema

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCHEMA = json.loads((ROOT / "contracts" / "standing.schema.json").read_text())


class StandingContractTest(unittest.TestCase):
    def setUp(self):
        self.validator = jsonschema.Draft202012Validator(SCHEMA)

    def test_alive_is_a_valid_standing(self):
        self.assertTrue(self.validator.is_valid("ALIVE"))

    def test_lowercase_alive_is_rejected(self):
        self.assertFalse(self.validator.is_valid("alive"))

    def test_unknown_word_is_rejected(self):
        self.assertFalse(self.validator.is_valid("DONE"))

    def test_non_string_is_rejected(self):
        self.assertFalse(self.validator.is_valid(7))


if __name__ == "__main__":
    unittest.main()
'''

ACTUATION_HEADER = '''import json
import pathlib
import unittest

import jsonschema

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCHEMA = json.loads((ROOT / "contracts" / "actuation-intent.schema.json").read_text())
VALID = {
    "intentId": "intent-1",
    "contractId": "contract-1",
    "authorityRef": "authority-1",
    "executorRef": "executor-1",
    "action": {"op": "noop"},
    "idempotencyKey": "key-1",
    "limits": {"maxSteps": 1},
}


def without(key):
    doc = dict(VALID)
    del doc[key]
    return doc


class ActuationIntentContractTest(unittest.TestCase):
    def setUp(self):
        self.validator = jsonschema.Draft202012Validator(SCHEMA)

    def test_complete_instance_is_valid(self):
        self.assertTrue(self.validator.is_valid(dict(VALID)))

    def test_extra_property_is_rejected(self):
        self.assertFalse(self.validator.is_valid({**VALID, "surprise": 1}))

    def test_empty_idempotency_key_is_rejected(self):
        self.assertFalse(self.validator.is_valid({**VALID, "idempotencyKey": ""}))

    def test_missing_intent_id_is_rejected(self):
        self.assertFalse(self.validator.is_valid(without("intentId")))
'''

ACTUATION_FULL_EXTRA = '''
    def test_missing_contract_id_is_rejected(self):
        self.assertFalse(self.validator.is_valid(without("contractId")))

    def test_missing_authority_ref_is_rejected(self):
        self.assertFalse(self.validator.is_valid(without("authorityRef")))

    def test_missing_executor_ref_is_rejected(self):
        self.assertFalse(self.validator.is_valid(without("executorRef")))
'''
