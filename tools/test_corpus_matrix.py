#!/usr/bin/env python3
"""Tests for tools/corpus_matrix.py and its wiring in test-code.yml.

    python3 tools/test_corpus_matrix.py
"""
import io
import os
import re
import sys
import tempfile
import unittest
import contextlib

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import corpus_matrix as cm  # noqa: E402

WORKFLOW = os.path.join(REPO, ".github", "workflows", "test-code.yml")


def fake_repo(names):
    d = tempfile.mkdtemp()
    t = os.path.join(d, cm.TEST_DIR)
    os.makedirs(t)
    for n in names:
        open(os.path.join(t, "testCorpus%s.m" % n), "w").close()
    open(os.path.join(t, "testOther.m"), "w").close()
    return d


def write_report(root, name, sub=""):
    p = os.path.join(root, sub)
    os.makedirs(p, exist_ok=True)
    open(os.path.join(p, name + cm.REPORT_SUFFIX), "w").close()


class TestMatrix(unittest.TestCase):
    def test_every_corpus_exactly_once(self):
        m = cm.build_matrix(["A", "B", "C", "D"], ["C"])
        self.assertEqual(m["include"], [
            {"group": "C", "corpora": "C"},
            {"group": cm.OTHERS, "corpora": "A B D"}])

    def test_alone_name_without_a_test_file_is_an_error(self):
        with self.assertRaises(SystemExit):
            cm.build_matrix(["A", "B"], ["Z"])

    def test_no_others_job_when_every_corpus_is_alone(self):
        m = cm.build_matrix(["A", "B"], ["A", "B"])
        self.assertEqual([e["group"] for e in m["include"]], ["A", "B"])

    def test_discover_reads_the_real_tree(self):
        names = cm.discover()
        self.assertGreater(len(names), 0)
        for n in names:
            self.assertTrue(os.path.isfile(os.path.join(
                REPO, cm.TEST_DIR, "testCorpus%s.m" % n)))

    def test_empty_tree_is_an_error_not_an_empty_matrix(self):
        with self.assertRaises(SystemExit):
            cm.discover(fake_repo([]))


class TestCheck(unittest.TestCase):
    def run_check(self, repo, roots):
        buf = io.StringIO()
        rc = cm.check(roots, repo=repo, out=lambda s: buf.write(s + "\n"))
        return rc, buf.getvalue()

    def test_all_present_at_any_depth(self):
        repo = fake_repo(["A", "B"])
        root = tempfile.mkdtemp()
        write_report(root, "A")
        write_report(root, "B", sub="tests/corpus-reports")
        rc, out = self.run_check(repo, [root])
        self.assertEqual(rc, 0, out)
        self.assertIn("found    2 of 2 expected", out)

    def test_missing_corpus_fails_and_is_named(self):
        repo = fake_repo(["A", "B"])
        root = tempfile.mkdtemp()
        write_report(root, "A")
        write_report(root, "fixture-x")
        rc, out = self.run_check(repo, [root])
        self.assertEqual(rc, 1)
        self.assertIn("1 of 2 expected corpus report(s) MISSING: B", out)
        self.assertIn("OTHER", out)

    def test_absent_root_is_missing_everything(self):
        repo = fake_repo(["A"])
        rc, out = self.run_check(repo, [os.path.join(tempfile.mkdtemp(), "no")])
        self.assertEqual(rc, 1)
        self.assertIn("root(s) absent", out)

    def test_denominator_prints_first(self):
        repo = fake_repo(["A"])
        _, out = self.run_check(repo, [tempfile.mkdtemp()])
        self.assertTrue(out.splitlines()[1].lstrip().startswith("expected 1"))


class TestWorkflowWiring(unittest.TestCase):
    """Scoped text reads of test-code.yml; a YAML cross-check when available."""

    @classmethod
    def setUpClass(cls):
        with open(WORKFLOW) as fh:
            cls.text = fh.read()
        cls.lines = cls.text.split("\n")

    def job(self, name):
        start = [i for i, ln in enumerate(self.lines) if ln == "  %s:" % name]
        self.assertEqual(len(start), 1, "job %s" % name)
        s = start[0]
        e = next((i for i in range(s + 1, len(self.lines))
                  if re.match(r"^  \S.*:\s*$", self.lines[i])), len(self.lines))
        return "\n".join(ln for ln in self.lines[s:e]
                         if not ln.lstrip().startswith("#"))

    def test_unit_job_excludes_the_corpus_prefix(self):
        self.assertIn('"did2.unittest.%s"' % cm.PREFIX, self.job("unit"))

    def test_corpus_matrix_comes_from_the_tool(self):
        self.assertIn("tools/corpus_matrix.py matrix", self.job("plan"))
        corpus = self.job("corpus")
        self.assertIn("fromJSON(needs.plan.outputs.matrix)", corpus)
        self.assertIn("fail-fast: false", corpus)
        self.assertIn("corpus-report-${{ matrix.group }}", corpus)

    def test_aggregate_runs_always_and_checks_reports(self):
        agg = self.job("aggregate")
        self.assertIn("if: always()", agg)
        self.assertIn("tools/corpus_matrix.py check", agg)
        for tool in ("tools/census_digest.py", "tools/corpus_proven.py",
                     "did-schema/tools/bar2_gap.py"):
            self.assertIn(tool, agg)
        self.assertIn("DID_MATLAB:", agg)
        self.assertIn("NDI_MATLAB:", agg)

    def test_yaml_parses_and_aggregate_needs_corpus(self):
        try:
            import yaml
        except ImportError:
            self.skipTest("PyYAML not installed -- YAML cross-check NOT RUN")
        doc = yaml.safe_load(self.text)
        needs = doc["jobs"]["aggregate"]["needs"]
        self.assertIn("corpus", needs)
        self.assertFalse(doc["jobs"]["corpus"]["strategy"]["fail-fast"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
