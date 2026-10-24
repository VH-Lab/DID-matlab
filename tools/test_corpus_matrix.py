#!/usr/bin/env python3
"""Tests for tools/corpus_matrix.py and its wiring in test-code.yml, and the
NDI-matlab ref fallback of test-code.yml, test-migrators-quick.yml and
test-corpus.yml.

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


class TestGate(unittest.TestCase):
    """The corpora run only when migration code changes (Jess Haley, 2026-10-24)."""

    def run_gate(self, event, files):
        return cm.gate(event, files, out=lambda *_: None)[0]

    def test_dispatch_always_runs(self):
        self.assertTrue(self.run_gate("workflow_dispatch", ["README.md"]))

    def test_unknown_file_list_runs(self):
        self.assertTrue(self.run_gate("pull_request", None))
        self.assertTrue(self.run_gate("push", []))

    def test_a_migration_file_runs(self):
        for f in ("src/did/+did2/+convert/epochMint.m",
                  "src/did/+did2/+convert/+migrators_j/treatment.m",
                  "tests/+did2/+unittest/testCorpusJH.m",
                  "tests/+did2/+unittest/+helpers/runCorpusDiscovery.m",
                  "tools/corpus_matrix.py",
                  ".github/workflows/test-code.yml"):
            self.assertTrue(self.run_gate("pull_request", ["README.md", f]), f)

    def test_other_files_skip(self):
        self.assertFalse(self.run_gate("pull_request", [
            "README.md", "src/did/+did2/+schema/cache.m",
            "src/did/+did2/+build/statement.m",
            "tests/+did2/+unittest/testMigratorsJ.m",
            ".github/workflows/test-builder.yml"]))

    def test_cli_writes_the_output(self):
        d = tempfile.mkdtemp()
        lst, gho = os.path.join(d, "f.txt"), os.path.join(d, "o.txt")
        with open(lst, "w") as fh:
            fh.write("docs/x.md\n")
        with contextlib.redirect_stdout(io.StringIO()):
            cm.main(["gate", "--event", "push", "--files-from", lst,
                     "--github-output", gho])
        with open(gho) as fh:
            self.assertEqual(fh.read(), "run=false\n")


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

    def test_corpus_jobs_are_gated(self):
        plan = self.job("plan")
        self.assertIn("tools/corpus_matrix.py gate", plan)
        self.assertIn("run: ${{ steps.gate.outputs.run }}", plan)
        self.assertIn("if: needs.plan.outputs.run == 'true'", self.job("corpus"))

    def test_aggregate_runs_always_and_checks_reports(self):
        agg = self.job("aggregate")
        self.assertIn("if: always() && needs.plan.outputs.run == 'true'", agg)
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


class TestNdiRefFallback(unittest.TestCase):
    """[NDI ref fallback] (Jess Haley, 2026-10-22, did-schema
    V_eta_go_forward_class_audit.md; test-corpus.yml added by her answer of
    the same day): EVERY "Resolve the NDI-matlab ref" step of test-code.yml
    (all of its jobs), test-migrators-quick.yml and test-corpus.yml tries the
    same-name branch, then V2, then main, prints the ref it took and says
    FALLBACK when it is not the same-name branch. The integration branch
    claude/v2-object-layer (NDI #1021's head) left the order when #1021 merged
    into V2 (2026-10-23), as the decision said it would."""

    ORDER = '"$want" V2 main'
    FILES = ("test-code.yml", "test-migrators-quick.yml", "test-corpus.yml")

    def steps(self, name):
        path = os.path.join(REPO, ".github", "workflows", name)
        with open(path) as fh:
            lines = fh.read().split("\n")
        out = []
        for i, ln in enumerate(lines):
            if re.match(r"^\s*- name: Resolve the NDI-matlab ref", ln):
                ind = len(ln) - len(ln.lstrip())
                e = next((j for j in range(i + 1, len(lines))
                          if lines[j].strip() and
                          len(lines[j]) - len(lines[j].lstrip()) <= ind),
                         len(lines))
                out.append("\n".join(x for x in lines[i:e]
                                     if not x.lstrip().startswith("#")))
        return out

    def test_every_step_uses_the_decided_order(self):
        total = 0
        for name in self.FILES:
            steps = self.steps(name)
            self.assertGreater(len(steps), 0, "%s: no resolve step found" % name)
            total += len(steps)
            for st in steps:
                self.assertIn("for ref in %s; do" % self.ORDER, st, name)
                self.assertIn("FALLBACK", st, name)
                self.assertIn('echo "ref=$chosen" >> "$GITHUB_OUTPUT"', st, name)
                self.assertNotIn('echo "ref=main" >> "$GITHUB_OUTPUT"\n          fi', st,
                                 "%s: the old straight-to-main fallback" % name)
        # DENOMINATOR: test-code.yml has the unit and aggregate jobs' steps,
        # test-migrators-quick.yml and test-corpus.yml one each.
        print("\n--- NDI ref fallback: %d resolve step(s) checked in %d file(s) ---"
              % (total, len(self.FILES)))
        self.assertEqual(total, 4)

    def test_the_resolver_runs_and_falls_back_in_order(self):
        """Run one step's script with git ls-remote stubbed: only V2 and main
        exist, so the same-name branch is tried first and V2 is taken,
        printed as a FALLBACK; the retired integration branch is not tried."""
        import subprocess
        st = self.steps("test-code.yml")[0]
        body = st.split("run: |", 1)[1]
        script = "\n".join(x[10:] if x.startswith(" " * 10) else x.strip()
                            for x in body.split("\n"))
        script = script.replace("${{ github.head_ref || github.ref_name }}",
                                "feature-x")
        d = tempfile.mkdtemp()
        stub = os.path.join(d, "git")
        with open(stub, "w") as fh:
            fh.write('#!/bin/sh\nfor a in "$@"; do last="$a"; done\n'
                     'case "$last" in V2|main) exit 0;; esac\nexit 2\n')
        os.chmod(stub, 0o755)
        out_file = os.path.join(d, "out")
        env = dict(os.environ, PATH=d + os.pathsep + os.environ["PATH"],
                   GITHUB_OUTPUT=out_file)
        p = subprocess.run(["bash", "-c", script], env=env,
                           capture_output=True, text=True)
        self.assertEqual(p.returncode, 0, p.stderr)
        with open(out_file) as fh:
            self.assertEqual(fh.read().strip(), "ref=V2")
        self.assertIn("NO branch 'feature-x'", p.stdout)
        self.assertNotIn("claude/v2-object-layer", p.stdout)
        self.assertIn("FALLBACK to 'V2'", p.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
