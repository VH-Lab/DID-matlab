#!/usr/bin/env python3
"""Tests for tools/affected_corpora.py (changed files -> corpora to re-run).

Run: python3 tools/test_affected_corpora.py   (well under a second)

The failure that matters is a corpus that SHOULD be re-run and is not, so most
cases pin the conservative arms (ALL) as well as the narrow ones.
"""
import contextlib
import io
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import affected_corpora as ac  # noqa: E402

CENSUS = {"A": {"ontologytablerow": 5, "session": 1},
          "B": {"treatment": 3, "session": 1},
          "C": {"element": 9, "session": 1}}
LEDGER_PASSES = {"resolveDeferredBaths": {"ontologytablerow"}}


def fake_repo(d):
    mig = os.path.join(d, ac.MIGRATORS)
    os.makedirs(os.path.join(d, ac.PRIVATE))
    files = {
        ac.MIGRATORS + "treatment.m": "out = jDose(x);",
        ac.MIGRATORS + "ontology_table_row.m": "y = jLabel(x);",
        ac.MIGRATORS + "element.m": "z = 1;",
        ac.PRIVATE + "jDose.m": "q = jInner(x);",
        ac.PRIVATE + "jInner.m": "r = 2;",
        ac.PRIVATE + "jLabel.m": "s = 3;",
        ac.PRIVATE + "jOrphan.m": "t = 4;",
    }
    for p, body in files.items():
        with open(os.path.join(d, p), "w") as fh:
            fh.write(body)
    return mig


def run(paths, narrow=False):
    with tempfile.TemporaryDirectory() as d:
        fake_repo(d)
        callers = ac.helper_callers(d)
    return ac.analyse(paths, CENSUS, callers, LEDGER_PASSES, {}, narrow)


class Mapping(unittest.TestCase):
    def test_camelcase_corpus_class_matches_snake_case_migrator(self):
        _, corpora = run([ac.MIGRATORS + "ontology_table_row.m"])
        self.assertEqual(corpora, ["A"])

    def test_a_helper_reaches_its_callers_transitively(self):
        rows, corpora = run([ac.PRIVATE + "jInner.m"])
        self.assertEqual(corpora, ["B"])
        self.assertIn("treatment", rows[0]["rule"])

    def test_a_helper_nobody_calls_maps_to_all(self):
        _, corpora = run([ac.PRIVATE + "jOrphan.m"])
        self.assertEqual(corpora, ["A", "B", "C"])

    def test_a_batch_pass_maps_to_all_unless_narrowed(self):
        p = ac.CONVERT + "resolveDeferredBaths.m"
        self.assertEqual(run([p])[1], ["A", "B", "C"])
        self.assertEqual(run([p], narrow=True)[1], ["A"])

    def test_the_driver_validator_and_super_migrators_map_to_all(self):
        for p in (ac.CONVERT + "v1_to_v2.m", "src/did/+did2/+schema/cache.m",
                  ac.MIGRATORS + "+super/ngrid.m",
                  "tests/+did2/+unittest/+helpers/runCorpusDiscovery.m"):
            self.assertEqual(run([p])[1], ["A", "B", "C"], p)

    def test_tools_and_docs_touch_no_corpus(self):
        self.assertEqual(run(["tools/census_digest.py", "README.md",
                              ac.MIGRATORS + "Contents.m"])[1], [])


class Census(unittest.TestCase):
    def test_reports_census_is_read_with_normalised_names(self):
        with tempfile.TemporaryDirectory() as d:
            with open(os.path.join(d, "Z-summary.json"), "w") as fh:
                json.dump({"corpus": "Z", "source_census": {
                    "by_class": {"ontologyTableRow": 2}}}, fh)
            c = ac.load_census(reports=[d])
        self.assertEqual(c, {"Z": {"ontologytablerow": 2}})

    def test_the_committed_census_holds_six_corpora(self):
        c = ac.load_census()
        self.assertEqual(sorted(c), ["20211116", "B", "Dab", "JH", "PRED", "Soph"])
        self.assertTrue(all(c[k] for k in c))


class Cli(unittest.TestCase):
    def test_prints_denominator_union_and_ndi_runs(self):
        with contextlib.redirect_stdout(io.StringIO()) as buf:
            rc = ac.main([ac.MIGRATORS + "treatment.m", "--ledger", "/nonexistent"])
        out = buf.getvalue()
        self.assertEqual(rc, 0)
        self.assertIn("DENOMINATOR: 1 changed file(s); census of 6 corpora", out)
        self.assertIn("ledger NOT FOUND", out)
        self.assertIn("AFFECTED CORPORA:", out)
        self.assertIn("NDI-matlab end-to-end:", out)


if __name__ == "__main__":
    unittest.main(verbosity=2)
