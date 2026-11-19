#!/usr/bin/env python3
"""Tests for tools/shard_corpus.py, the whole-session cut behind the sharded
Soph run (test-soph-corpus.yml).

Run: python3 tools/test_shard_corpus.py   (well under a second)

What a shard set must never do, each as a case:
  * lose a document or hold one twice (the union must be the corpus);
  * cut a session in half, or split sessions joined by a depends_on;
  * cut differently when the files arrive in a different order;
  * write an empty shard and exit 0.
"""
import contextlib
import io
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import shard_corpus as sh  # noqa: E402


def doc(i, cls, sess, refs=()):
    return {"base": {"id": i, "session_id": sess},
            "document_class": {"class_name": cls},
            "depends_on": [{"name": "x", "value": r} for r in refs]}


def corpus(d, docs, names=None):
    for k, x in enumerate(docs):
        name = names[k] if names else "%s.json" % x["base"]["id"]
        with open(os.path.join(d, name), "w") as fh:
            json.dump(x, fh)


def run(argv):
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
        rc = sh.main(argv)
    return rc, buf.getvalue()


DOCS = ([doc("a%d" % k, "c1", "S1") for k in range(5)]
        + [doc("b%d" % k, "c2", "S2") for k in range(4)]
        + [doc("c%d" % k, "c1", "S3") for k in range(3)]
        + [doc("d0", "c3", "S4", refs=["c0"]), doc("d1", "c3", "S4")]
        + [doc("e0", "c4", "S5")])


class ShardCorpus(unittest.TestCase):
    def shards(self, docs, n, names=None):
        with tempfile.TemporaryDirectory() as src, tempfile.TemporaryDirectory() as out:
            corpus(src, docs, names)
            got = []
            for k in range(n):
                rc, text = run(["--corpus", "X", "--src", src, "--out",
                                os.path.join(out, str(k)), "--shards", str(n),
                                "--index", str(k)])
                self.assertEqual(rc, 0, text)
                self.assertIn("DENOMINATOR: %d doc(s)" % len(docs), text)
                files = sorted(os.listdir(os.path.join(out, str(k), "X")))
                with open(os.path.join(out, str(k), "X.sample.json")) as fh:
                    m = json.load(fh)
                self.assertEqual(m["docs_kept"], len(files))
                self.assertEqual(m["docs_in_corpus"], len(docs))
                self.assertEqual(sum(m["shard_loads"]), len(docs))
                got.append((files, m))
            return got

    def test_union_is_the_corpus_once(self):
        got = self.shards(DOCS, 3)
        allfiles = [f for files, _ in got for f in files]
        self.assertEqual(len(allfiles), len(DOCS))
        self.assertEqual(set(allfiles), {"%s.json" % d["base"]["id"] for d in DOCS})

    def test_sessions_and_linked_sessions_stay_whole(self):
        got = self.shards(DOCS, 3)
        sess = {"%s.json" % d["base"]["id"]: d["base"]["session_id"] for d in DOCS}
        where = {}
        for k, (files, m) in enumerate(got):
            for f in files:
                where.setdefault(sess[f], set()).add(k)
        for s, ks in where.items():
            self.assertEqual(len(ks), 1, s)
        # S4's d0 depends on S3's c0: one group, one shard.
        self.assertEqual(where["S3"], where["S4"])
        self.assertEqual(got[0][1]["cross_session_edges"], 1)
        self.assertEqual(got[0][1]["session_groups"], 4)

    def test_file_order_does_not_change_the_cut(self):
        names = ["%03d.json" % k for k in range(len(DOCS))]
        a = self.shards(DOCS, 3, names)
        b = self.shards(list(reversed(DOCS)), 3, list(reversed(names)))
        self.assertEqual([m["sessions"] for _, m in a], [m["sessions"] for _, m in b])
        self.assertEqual([m["kept_files_sha256"] for _, m in a],
                         [m["kept_files_sha256"] for _, m in b])

    def test_empty_shard_is_an_error(self):
        with tempfile.TemporaryDirectory() as src, tempfile.TemporaryDirectory() as out:
            corpus(src, DOCS)
            rc, text = run(["--corpus", "X", "--src", src, "--out", out,
                            "--shards", "5", "--index", "4"])
            self.assertEqual(rc, 2, text)
            self.assertIn("holds 0 documents", text)

    def test_bad_index_and_empty_corpus_refused(self):
        with tempfile.TemporaryDirectory() as src, tempfile.TemporaryDirectory() as out:
            self.assertEqual(run(["--corpus", "X", "--src", src, "--out", out,
                                  "--shards", "2", "--index", "2"])[0], 2)
            self.assertEqual(run(["--corpus", "X", "--src", src, "--out", out,
                                  "--shards", "2", "--index", "0"])[0], 2)


if __name__ == "__main__":
    unittest.main()
