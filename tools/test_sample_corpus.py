#!/usr/bin/env python3
"""Tests for tools/sample_corpus.py, the session picker behind the SAMPLED
corpus run (test-corpus.yml, `sample: true`).

Run: python3 tools/test_sample_corpus.py   (well under a second)

What a sampled run must never do, each as a case:
  * miss a class the corpus holds (a sampled run would read clean over it);
  * cut a session in half (the batch post-passes need the whole session);
  * pick different sessions on a re-run, or when the files arrive in a
    different order;
  * drop a session another kept session references (an orphan the full
    corpus does not have);
  * sample nothing and exit 0.
"""
import contextlib
import io
import json
import os
import random
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sample_corpus as sc  # noqa: E402


def doc(i, cls, sess, refs=()):
    return {"base": {"id": i, "session_id": sess},
            "document_class": {"class_name": cls},
            "depends_on": [{"name": "x", "value": r} for r in refs]}


def write(d, docs, names=None):
    for k, x in enumerate(docs):
        name = names[k] if names else "%s.json" % x["base"]["id"]
        with open(os.path.join(d, name), "w") as fh:
            json.dump(x, fh)


def build(docs, order_seed=None):
    with tempfile.TemporaryDirectory() as d:
        if order_seed is not None:
            docs = list(docs)
            random.Random(order_seed).shuffle(docs)
        write(d, docs)
        return sc.build_manifest("T", sc.load_corpus(d))


# A corpus with a big session holding most classes, a small one holding the
# same, and two tiny sessions each holding one class nobody else has.
CORPUS = (
    [doc("big%03d" % k, "element", "S_big") for k in range(50)]
    + [doc("bigs", "session", "S_big"), doc("bigsub", "subject", "S_big")]
    + [doc("small%d" % k, "element", "S_small") for k in range(3)]
    + [doc("smalls", "session", "S_small"), doc("smallsub", "subject", "S_small")]
    + [doc("ds1", "dataset_remote", "S_ds"), doc("ds2", "session", "S_ds")]
    + [doc("ot1", "ontologyTableRow", "S_ot")]
)


class Coverage(unittest.TestCase):
    def test_every_class_is_covered_and_the_denominators_add_up(self):
        m = build(CORPUS)
        self.assertEqual(m["classes_in_corpus"], 5)
        self.assertEqual(m["classes_covered"], 5)
        self.assertEqual(m["classes_uncovered"], [])
        self.assertEqual(m["docs_in_corpus"], len(CORPUS))
        self.assertEqual(sum(r["docs_kept"] for r in m["by_class"]), m["docs_kept"])

    def test_the_small_session_is_taken_instead_of_the_big_one(self):
        m = build(CORPUS)
        kept_sessions = {p["session_id"] for p in m["picks"] if not p.get("pruned")}
        self.assertEqual(kept_sessions, {"S_small", "S_ds", "S_ot"})
        self.assertEqual(m["docs_kept"], 5 + 2 + 1)

    def test_a_class_held_by_one_session_forces_that_session(self):
        m = build(CORPUS)
        kept = set(m["kept_files"])
        self.assertIn("ot1.json", kept)
        self.assertIn("ds1.json", kept)


class WholeSessions(unittest.TestCase):
    def test_no_session_is_cut(self):
        m = build(CORPUS)
        kept = set(m["kept_files"])
        by_session = {}
        for x in CORPUS:
            by_session.setdefault(x["base"]["session_id"], set()).add(x["base"]["id"] + ".json")
        for s, files in by_session.items():
            self.assertIn(len(files & kept), (0, len(files)), "session %s was cut" % s)

    def test_a_referenced_session_comes_along_whole(self):
        docs = CORPUS + [doc("refA", "probe", "S_ref", refs=["big000"])]
        m = build(docs)
        kept = set(m["kept_files"])
        self.assertIn("refA.json", kept)
        for k in range(50):
            self.assertIn("big%03d.json" % k, kept)

    def test_documents_without_a_session_id_are_a_group_of_their_own(self):
        docs = CORPUS + [{"base": {"id": "nosess"}, "document_class": {"class_name": "odd"}}]
        m = build(docs)
        self.assertIn("nosess.json", m["kept_files"])
        self.assertEqual(m["classes_covered"], m["classes_in_corpus"])


class Pruning(unittest.TestCase):
    def test_a_pick_a_later_pick_covers_is_dropped(self):
        # Greedy takes S_mid first (2 classes / 4 docs beats 3 / 9), then needs
        # S_all for `c`, which also holds a and b: S_mid is then redundant.
        docs = ([doc("m%d" % k, "a" if k < 2 else "b", "S_mid") for k in range(4)]
                + [doc("x%d" % k, ["a", "b", "c"][k % 3], "S_all") for k in range(9)])
        m = build(docs)
        pruned = [p["session_id"] for p in m["picks"] if p.get("pruned")]
        self.assertEqual(pruned, ["S_mid"])
        self.assertEqual(m["sessions_kept"], 1)
        self.assertEqual(m["classes_covered"], 3)

    def test_a_referenced_session_is_never_pruned_away(self):
        # Picks: S_target (a,z; 2 docs), S_big (c), S_ref (b, refs S_target).
        # By classes alone S_target is redundant (S_big holds a and z), but
        # S_ref references it, so dropping it would orphan S_ref's edge.
        docs = ([doc("t0", "a", "S_target"), doc("t1", "z", "S_target")]
                + [doc("g%d" % k, ["a", "z", "c"][k % 3], "S_big") for k in range(5)]
                + [doc("r%d" % k, "b", "S_ref", refs=["t0"]) for k in range(10)])
        m = build(docs)
        self.assertEqual([p["session_id"] for p in m["picks"]],
                         ["S_target", "S_big", "S_ref"])
        self.assertFalse(any(p.get("pruned") for p in m["picks"]))
        self.assertIn("t0.json", m["kept_files"])


class Determinism(unittest.TestCase):
    def test_input_order_does_not_change_the_sample(self):
        digests = {build(CORPUS, order_seed=s)["kept_files_sha256"] for s in range(6)}
        self.assertEqual(len(digests), 1)

    def test_a_full_tie_goes_to_the_smaller_session_id(self):
        docs = [doc("p", "a", "S_2"), doc("q", "a", "S_1")]
        m = build(docs)
        self.assertEqual(m["kept_files"], ["q.json"])


class Files(unittest.TestCase):
    def test_mac_sidecars_are_skipped_and_unreadable_files_are_kept_and_counted(self):
        with tempfile.TemporaryDirectory() as d:
            write(d, [doc("a", "x", "S")])
            for name, text in (("._a.json", "junk"), ("broken.json", "{not json")):
                with open(os.path.join(d, name), "w") as fh:
                    fh.write(text)
            m = sc.build_manifest("T", sc.load_corpus(d))
            self.assertEqual(m["docs_in_corpus"], 2)
            self.assertEqual(m["docs_unreadable"], 1)
            self.assertIn("broken.json", m["kept_files"])
            self.assertNotIn("._a.json", m["kept_files"])

    def test_cli_writes_the_folder_and_the_manifest_beside_it(self):
        with tempfile.TemporaryDirectory() as src, tempfile.TemporaryDirectory() as out:
            write(src, CORPUS)
            with contextlib.redirect_stdout(io.StringIO()) as buf:
                rc = sc.main(["--corpus", "T", "--src", src, "--out", out])
            self.assertEqual(rc, 0)
            self.assertIn("DENOMINATOR: %d doc(s)" % len(CORPUS), buf.getvalue())
            self.assertIn("classes covered 5 of 5", buf.getvalue())
            files = sorted(os.listdir(os.path.join(out, "T")))
            with open(os.path.join(out, "T.sample.json")) as fh:
                man = json.load(fh)
            self.assertEqual(files, man["kept_files"])
            self.assertFalse(any(f.endswith(".sample.json") for f in files))

    def test_an_empty_corpus_is_an_error_not_a_clean_sample(self):
        with tempfile.TemporaryDirectory() as src:
            with contextlib.redirect_stderr(io.StringIO()):
                rc = sc.main(["--corpus", "T", "--src", src])
            self.assertNotEqual(rc, 0)


class ReportSummary(unittest.TestCase):
    def test_sampled_and_full_reports_are_told_apart(self):
        with tempfile.TemporaryDirectory() as d:
            os.makedirs(os.path.join(d, "deep"))
            with open(os.path.join(d, "deep", "B-summary.json"), "w") as fh:
                json.dump({"corpus": "B", "total": 9, "sample": {
                    "docs_kept": 3, "docs_in_corpus": 9, "sessions_kept": 1,
                    "sessions_in_corpus": 4, "classes_covered": 2,
                    "classes_in_corpus": 2}}, fh)
            with open(os.path.join(d, "PRED-summary.json"), "w") as fh:
                json.dump({"corpus": "PRED", "total": 14}, fh)
            paths, text = sc.summarise_reports([d])
        self.assertEqual(len(paths), 2)
        self.assertIn("SAMPLE COVERAGE: 2 corpus report(s)", text)
        self.assertRegex(text, r"B\s+SAMPLED\s+3/9\s+1/4\s+2/2")
        self.assertRegex(text, r"PRED\s+FULL")

    def test_no_reports_is_an_error(self):
        with tempfile.TemporaryDirectory() as d:
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(sc.main(["--summarise-reports", d]), 2)


if __name__ == "__main__":
    unittest.main(verbosity=2)
