#!/usr/bin/env python3
"""Turn a red corpus report into a quick-suite fixture.

    python3 tools/extract_failure_fixtures.py \
        --report corpus-reports/B-summary.json --corpus B=/tmp/did2-corpus-B/B \
        --out tests/+did2/fixtures/corpus_failures

For each `<corpus>-summary.json` given (files, or folders searched at any
depth), read the `failure_documents` block (written by
tests/+did2/+unittest/+helpers/failureDocuments.m) and copy into
`<out>/<corpus>/`:

  * the v1 source documents behind every failure row: quarantined and
    fragmented sources (v1 base.id), orphaned documents and their dangling
    edge targets, documents with an empty required edge;
  * every document those reference by depends_on, transitively, WITHIN THE
    SAME SESSION (cross-session edges are not followed: a fixture is one
    session's slice, and no corpus held a cross-session edge on 2026-10-21);
  * the `session` document(s) of each session touched, because on did-schema
    #88 base.session_id is a required edge to the session entity.

`<out>/<corpus>.manifest.json` records what was asked for and what was found,
BESIDE the folder (the driver reads every *.json in it as a document).

ROWS ARE CAPPED, PER (kind, class): `--per-class` seeds each (default 3),
chosen by sorted id, so the same report always gives the same fixture. One
failing document per class reproduces a class's failure; the full list is in
the report.

WHAT CANNOT BE MAPPED IS PRINTED, NOT DROPPED. Orphan and empty-edge rows name
the MIGRATED document's id, which is the v1 id for most migrators and a minted
one for some. An id with no v1 document is listed as `unmapped` with its row,
and counted. A report written before `failure_documents` existed falls back to
the orphan sample in `reference_integrity` and says so; quarantine, fragment
and empty-edge ids are then NOT MEASURED, never zero.

The fixture is a SLICE of a session, so a failure that needs a document joined
by string rather than by depends_on (CLAUDE.md: probemap `devicename`) may not
reproduce from it. `--whole-session` copies each touched session in full
instead.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import sys

KINDS = ("quarantine", "fragment", "orphan", "empty_required_edge")


def find_reports(paths):
    out = []
    for p in paths:
        if os.path.isfile(p):
            out.append(p)
        elif os.path.isdir(p):
            for dp, _, fns in os.walk(p):
                out.extend(os.path.join(dp, f) for f in fns
                           if f.endswith("-summary.json"))
    return sorted(set(out))


def as_list(v):
    """MATLAB's jsonencode writes a 1x1 struct array as an object."""
    if v is None:
        return []
    if isinstance(v, dict):
        return [v]
    if isinstance(v, list):
        return v
    if isinstance(v, str):
        return [v]
    return []


def seed_rows(report):
    """{kind: {"state": measured|not_measured, "count": n|None, "rows": [...]}}.

    Each row is {"id", "class", "extra_ids", "row"}.
    """
    fd = report.get("failure_documents")
    out = {}
    if not isinstance(fd, dict) or "audit_failed" in (fd or {}):
        note = ("block absent (report predates failure_documents)"
                if not isinstance(fd, dict) else "audit_failed: %s" % fd["audit_failed"])
        for k in KINDS:
            out[k] = {"state": "not_measured", "count": None, "rows": [], "note": note}
        ri = report.get("reference_integrity") or {}
        if isinstance(ri, dict) and "orphans" in ri:
            out["orphan"] = {"state": "measured", "count": ri.get("orphan_count"),
                             "rows": [orphan_row(r) for r in as_list(ri.get("orphans"))],
                             "note": "from reference_integrity.orphans (capped sample)"}
        return out
    for k in KINDS:
        v = fd.get(k)
        if k not in fd or v == "not_measured":
            out[k] = {"state": "not_measured", "count": None, "rows": [], "note": ""}
            continue
        rows = []
        for r in as_list(v):
            if k == "quarantine":
                rows.append({"id": r.get("source_id", ""), "class": r.get("class_name", ""),
                             "extra_ids": [], "row": r})
            elif k == "fragment":
                rows.append({"id": r if isinstance(r, str) else "", "class": "",
                             "extra_ids": [], "row": r})
            elif k == "orphan":
                rows.append(orphan_row(r))
            else:
                rows.append({"id": r.get("doc_id", ""), "class": r.get("class_name", ""),
                             "extra_ids": [], "row": r})
        out[k] = {"state": "measured", "count": fd.get(k + "_count", len(rows)),
                  "rows": rows, "note": ""}
    return out


def orphan_row(r):
    return {"id": r.get("doc_id", ""), "class": r.get("doc_class", ""),
            "extra_ids": [r.get("edge_document_id", "")], "row": r}


def index_source(src):
    """id -> (file, class, session, refs); session -> [session-doc ids]; session -> [files]."""
    byid, sess_docs, sess_files = {}, {}, {}
    for f in sorted(os.listdir(src)):
        if not f.endswith(".json") or f.startswith("._"):
            continue
        try:
            with open(os.path.join(src, f), "rb") as fh:
                d = json.loads(fh.read().decode("utf-8"))
        except (OSError, ValueError, UnicodeDecodeError):
            continue
        if not isinstance(d, dict):
            continue
        base = d.get("base") if isinstance(d.get("base"), dict) else {}
        cls = (d.get("document_class") or {}).get("class_name", "") \
            if isinstance(d.get("document_class"), dict) else ""
        sid = base.get("session_id") if isinstance(base.get("session_id"), str) else ""
        deps = d.get("depends_on") or []
        if isinstance(deps, dict):
            deps = [deps]
        refs = [x.get("value") for x in deps
                if isinstance(x, dict) and isinstance(x.get("value"), str) and x.get("value")]
        i = base.get("id")
        if isinstance(i, str) and i:
            byid.setdefault(i, (f, cls, sid, refs))
        sess_files.setdefault(sid, []).append(f)
        if cls == "session" and isinstance(i, str):
            sess_docs.setdefault(sid, []).append(i)
    return byid, sess_docs, sess_files


def pick_seeds(rows_by_kind, per_class):
    """Deterministic: per (kind, class), the first `per_class` ids in sorted order."""
    picked = []
    for kind in KINDS:
        groups = {}
        for r in rows_by_kind[kind]["rows"]:
            groups.setdefault(r["class"], []).append(r)
        for cls in sorted(groups):
            rs = sorted(groups[cls], key=lambda r: (r["id"], r["extra_ids"]))
            for r in rs[:per_class]:
                picked.append((kind, r))
    return picked


def extract(report_path, src, out_root, per_class=3, whole_session=False, name=None):
    with open(report_path) as fh:
        report = json.load(fh)
    corpus = name or report.get("corpus") or os.path.basename(report_path).split("-summary")[0]
    rows = seed_rows(report)
    byid, sess_docs, sess_files = index_source(src)
    picked = pick_seeds(rows, per_class)

    wanted, unmapped, sessions = set(), [], set()
    seeded = {k: 0 for k in KINDS}
    for kind, r in picked:
        seeded[kind] += 1
        ids = [r["id"]] + [x for x in r["extra_ids"] if x]
        mapped_any = False
        for i in ids:
            if i in byid:
                wanted.add(i)
                sessions.add(byid[i][2])
                mapped_any = True
        if not mapped_any:
            unmapped.append({"kind": kind, "row": r["row"]})
    # closure inside each document's own session
    stack = sorted(wanted)
    while stack:
        i = stack.pop()
        _, _, sid, refs = byid[i]
        for t in refs:
            if t in byid and t not in wanted and byid[t][2] == sid:
                wanted.add(t)
                stack.append(t)
    for sid in sessions:
        wanted.update(sess_docs.get(sid, []))
    files = sorted({byid[i][0] for i in wanted})
    if whole_session:
        files = sorted(set(files).union(*(sess_files.get(s, []) for s in sessions)))

    summary = {
        "tool": "tools/extract_failure_fixtures.py",
        "corpus": corpus,
        "report": report_path,
        "report_generated_at": report.get("generated_at"),
        "report_sampled": "sample" in report,
        "source_dir": src,
        "source_docs_indexed": len(byid),
        "per_class": per_class,
        "whole_session": whole_session,
        "kinds": {k: {"state": rows[k]["state"], "count_in_report": rows[k]["count"],
                      "rows_listed": len(rows[k]["rows"]), "seeded": seeded[k],
                      "note": rows[k].get("note", "")} for k in KINDS},
        "unmapped": unmapped,
        "sessions": sorted(sessions),
        "docs_written": len(files),
        "files": files,
    }
    return summary


def write_fixture(summary, src, out_root):
    dest = os.path.join(out_root, summary["corpus"])
    if os.path.exists(dest):
        shutil.rmtree(dest)
    os.makedirs(dest)
    for f in summary["files"]:
        shutil.copyfile(os.path.join(src, f), os.path.join(dest, f))
    with open(os.path.join(out_root, summary["corpus"] + ".manifest.json"), "w") as fh:
        json.dump(summary, fh, indent=1, sort_keys=True)
        fh.write("\n")
    return dest


def render(s):
    out = ["=== failure fixture: %s (report %s%s) ===" % (
        s["corpus"], s["report"], ", SAMPLED run" if s["report_sampled"] else "")]
    out.append("DENOMINATOR: %d v1 document(s) indexed from %s"
               % (s["source_docs_indexed"], s["source_dir"]))
    for k in KINDS:
        r = s["kinds"][k]
        if r["state"] != "measured":
            out.append("  %-20s NOT MEASURED %s" % (k, r["note"]))
        else:
            out.append("  %-20s %s in report, %d row(s) listed, %d seeded%s"
                       % (k, r["count_in_report"], r["rows_listed"], r["seeded"],
                          (" (%s)" % r["note"]) if r["note"] else ""))
    out.append("  unmapped (no v1 document with that id): %d" % len(s["unmapped"]))
    for u in s["unmapped"][:20]:
        out.append("      %s %s" % (u["kind"], json.dumps(u["row"], sort_keys=True)))
    out.append("  sessions touched: %d; documents written: %d"
               % (len(s["sessions"]), s["docs_written"]))
    return "\n".join(out)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--report", action="append", required=True,
                    help="a *-summary.json, or a folder searched at any depth")
    ap.add_argument("--corpus", action="append", required=True,
                    help="NAME=DIR: the folder of v1 *.json the run read")
    ap.add_argument("--out", required=True, help="fixture root")
    ap.add_argument("--per-class", type=int, default=3)
    ap.add_argument("--whole-session", action="store_true")
    a = ap.parse_args(argv)
    sources = {}
    for c in a.corpus:
        if "=" not in c:
            ap.error("--corpus takes NAME=DIR, got %r" % c)
        n, d = c.split("=", 1)
        sources[n] = d
    reports = find_reports(a.report)
    print("REPORT SEARCH: %d *-summary.json under %s" % (len(reports), a.report))
    if not reports:
        print("ERROR: no corpus report found -- nothing was read", file=sys.stderr)
        return 2
    wrote = 0
    for rp in reports:
        with open(rp) as fh:
            corpus = json.load(fh).get("corpus") or os.path.basename(rp).split("-summary")[0]
        if corpus not in sources:
            print("SKIP %s: no --corpus %s=DIR given" % (rp, corpus))
            continue
        if not os.path.isdir(sources[corpus]):
            print("ERROR: source folder %s for %s does not exist" % (sources[corpus], corpus),
                  file=sys.stderr)
            return 2
        s = extract(rp, sources[corpus], a.out, a.per_class, a.whole_session, corpus)
        print(render(s))
        if s["docs_written"]:
            dest = write_fixture(s, sources[corpus], a.out)
            print("wrote %d document(s) to %s" % (s["docs_written"], dest))
            wrote += 1
        else:
            print("nothing to write for %s" % corpus)
    print("fixtures written: %d of %d report(s)" % (wrote, len(reports)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
