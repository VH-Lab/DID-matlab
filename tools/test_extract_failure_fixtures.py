#!/usr/bin/env python3
"""Tests for tools/extract_failure_fixtures.py (red corpus report -> fixture).

Run: python3 tools/test_extract_failure_fixtures.py   (well under a second)
"""
import contextlib
import io
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import extract_failure_fixtures as ef  # noqa: E402


def doc(i, cls, sess, refs=()):
    return {"base": {"id": i, "session_id": sess},
            "document_class": {"class_name": cls},
            "depends_on": [{"name": "x", "value": r} for r in refs]}


SOURCE = [
    doc("S1", "session", "s1"),
    doc("dev", "daqsystem", "s1"),
    doc("el", "element", "s1", refs=["dev"]),
    doc("ep", "element_epoch", "s1", refs=["el"]),
    doc("unrelated", "subject", "s1"),
    doc("S2", "session", "s2"),
    doc("t2", "treatment", "s2"),
    doc("other", "element", "s2"),
]


def setup_source(d):
    for x in SOURCE:
        with open(os.path.join(d, x["base"]["id"] + ".json"), "w") as fh:
            json.dump(x, fh)


def write_report(d, fd, extra=None):
    rep = {"corpus": "T", "generated_at": "now"}
    if fd is not None:
        rep["failure_documents"] = fd
    rep.update(extra or {})
    p = os.path.join(d, "T-summary.json")
    with open(p, "w") as fh:
        json.dump(rep, fh)
    return p


FULL = {
    "cap": 2000,
    "quarantine_count": 1,
    # MATLAB's jsonencode writes a 1x1 struct array as an OBJECT.
    "quarantine": {"source_id": "ep", "class_name": "element_epoch", "identifier": "x:y"},
    "fragment_count": 1, "fragment": ["t2"],
    "orphan_count": 1,
    "orphan": [{"doc_id": "minted-not-v1", "doc_class": "entity",
                "edge_name": "subject_id", "edge_document_id": "gone"}],
    "empty_required_edge_count": 0, "empty_required_edge": [],
}


class Extract(unittest.TestCase):
    def run_extract(self, fd, **kw):
        with tempfile.TemporaryDirectory() as src, tempfile.TemporaryDirectory() as rd:
            setup_source(src)
            rp = write_report(rd, fd, kw.pop("extra", None))
            return ef.extract(rp, src, None, **kw)

    def test_seed_plus_same_session_closure_plus_session_document(self):
        s = self.run_extract(FULL)
        self.assertEqual(s["files"], sorted(["ep.json", "el.json", "dev.json", "S1.json",
                                             "t2.json", "S2.json"]))
        self.assertNotIn("unrelated.json", s["files"])
        self.assertNotIn("other.json", s["files"])

    def test_an_unmappable_row_is_listed_not_dropped(self):
        s = self.run_extract(FULL)
        self.assertEqual(len(s["unmapped"]), 1)
        self.assertEqual(s["unmapped"][0]["kind"], "orphan")

    def test_counts_and_states_per_kind(self):
        s = self.run_extract(FULL)
        k = s["kinds"]
        self.assertEqual(k["quarantine"]["count_in_report"], 1)
        self.assertEqual(k["quarantine"]["seeded"], 1)
        self.assertEqual(k["empty_required_edge"]["state"], "measured")
        self.assertEqual(k["empty_required_edge"]["seeded"], 0)

    def test_a_report_without_the_block_is_not_measured_never_zero(self):
        s = self.run_extract(None, extra={"reference_integrity": {
            "orphan_count": 1, "orphans": [{"doc_id": "el", "doc_class": "element",
                                            "edge_name": "d", "edge_document_id": "q"}]}})
        k = s["kinds"]
        self.assertEqual(k["quarantine"]["state"], "not_measured")
        self.assertEqual(k["fragment"]["state"], "not_measured")
        self.assertEqual(k["orphan"]["state"], "measured")
        self.assertIn("el.json", s["files"])

    def test_per_class_cap_is_deterministic(self):
        fd = dict(FULL, quarantine=[
            {"source_id": i, "class_name": "element", "identifier": "z"}
            for i in ("other", "el")], fragment=[], orphan=[])
        s = self.run_extract(fd, per_class=1)
        self.assertEqual(s["kinds"]["quarantine"]["seeded"], 1)
        self.assertIn("el.json", s["files"])        # "el" < "other"
        self.assertNotIn("other.json", s["files"])

    def test_whole_session_copies_every_document_of_a_touched_session(self):
        fd = dict(FULL, quarantine=[], fragment=["t2"], orphan=[])
        s = self.run_extract(fd, whole_session=True)
        self.assertEqual(s["files"], ["S2.json", "other.json", "t2.json"])


class Cli(unittest.TestCase):
    def test_writes_folder_and_manifest_beside_it(self):
        with tempfile.TemporaryDirectory() as src, tempfile.TemporaryDirectory() as rd, \
                tempfile.TemporaryDirectory() as out:
            setup_source(src)
            write_report(rd, FULL)
            with contextlib.redirect_stdout(io.StringIO()) as buf:
                rc = ef.main(["--report", rd, "--corpus", "T=" + src, "--out", out])
            self.assertEqual(rc, 0)
            self.assertIn("DENOMINATOR: %d v1 document(s)" % len(SOURCE), buf.getvalue())
            self.assertTrue(os.path.isfile(os.path.join(out, "T.manifest.json")))
            self.assertEqual(len(os.listdir(os.path.join(out, "T"))), 6)

    def test_no_report_found_is_an_error(self):
        with tempfile.TemporaryDirectory() as rd, tempfile.TemporaryDirectory() as out:
            with contextlib.redirect_stdout(io.StringIO()), \
                    contextlib.redirect_stderr(io.StringIO()):
                rc = ef.main(["--report", rd, "--corpus", "T=" + rd, "--out", out])
            self.assertNotEqual(rc, 0)

    def test_a_clean_report_writes_nothing(self):
        clean = {"cap": 2000, "quarantine_count": 0, "quarantine": [],
                 "fragment_count": 0, "fragment": [], "orphan_count": 0, "orphan": [],
                 "empty_required_edge_count": 0, "empty_required_edge": []}
        with tempfile.TemporaryDirectory() as src, tempfile.TemporaryDirectory() as rd, \
                tempfile.TemporaryDirectory() as out:
            setup_source(src)
            write_report(rd, clean)
            with contextlib.redirect_stdout(io.StringIO()) as buf:
                rc = ef.main(["--report", rd, "--corpus", "T=" + src, "--out", out])
            self.assertEqual(rc, 0)
            self.assertEqual(os.listdir(out), [])
            self.assertIn("fixtures written: 0 of 1", buf.getvalue())


if __name__ == "__main__":
    unittest.main(verbosity=2)
