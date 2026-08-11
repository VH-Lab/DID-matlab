#!/usr/bin/env python3
"""Render the corpus census from the per-corpus *-summary.json reports.

WHY THIS IS A FILE AND NOT A YAML HEREDOC
-----------------------------------------
This digest shipped broken twice, and both times the reason was that it lived
inside a `run:` block in test-code.yml where nothing could execute it except a
full ~3-hour corpus run:

  1. It printed "0 empty required edges, 0 vacuous required fields" without
     printing `total_docs`, so a census that inspected NOTHING was
     indistinguishable from one that found nothing wrong -- the very bug
     `silentLoss` itself had shipped with.

  2. It did `dict[:10]`. MATLAB's `jsonencode` writes a ONE-ELEMENT struct array
     as a bare object rather than a one-element array, so a report with exactly
     one offending row arrives as a dict. That killed run #256 mid-corpus and
     cost the two largest corpora their output.

Neither defect was reachable by any test while the code lived in YAML. As a
module it is importable, and tests/test_census_digest.py exercises both shapes
in under a second.

Usage:
    python3 tools/census_digest.py <reports-dir> [<reports-dir> ...]

Exits non-zero if any report could not be rendered -- but only AFTER every
readable report has printed. A digest that cannot read its input must say so;
it must not also destroy the data it could read.
"""

import json
import os
import sys
import traceback

# Sentinel placed in the `failed` list when the digest found no reports at all.
# ZERO REPORTS IS A FAILURE OF THE INSTRUMENT, NOT A CLEAN RUN. It used to
# return `(lines, [])` -- so run #3's census job printed "NO CORPUS REPORTS
# FOUND" and went GREEN, and six corpora that had run for over an hour
# reported nothing at all. A digest with no input has not agreed with the
# corpora; it has not read them.
MISSING_REPORTS = "<no *-summary.json found>"


def aslist(v):
    """Normalise MATLAB's array-or-object encoding to a list.

    `jsonencode` emits a 1-element struct array as a bare object and a 2+
    element one as an array, so any list-shaped field can arrive either way.
    Every list-shaped read goes through here -- not just the field that
    happened to break once.
    """
    if v is None:
        return []
    if isinstance(v, dict):
        return [v]
    if isinstance(v, list):
        return v
    return [v]


# The batch post-passes a V_eta corpus run is expected to have executed, in the
# order the harness runs them. This list IS the denominator for the post-pass
# block: every entry prints a line whether or not the report carries it, so
# "the pass ran and changed nothing" and "the pass was never wired into the run
# that produced this report" are different output rather than the same silence.
#
# THAT DISTINCTION IS WHY THIS BLOCK EXISTS. `did2.convert.resolveSessionAnchors`
# was built and left uncalled, and no corpus artifact said so, because a pass
# that is not called writes nothing anywhere. `epoch_mint` was the sibling case:
# it WAS wired and WAS persisted into every report from the day it landed -- and
# this digest did not render it, so the number reached the artifact and stopped
# there. A measurement nobody can see without downloading a zip is the
# write-only condition this whole file exists to remove.
#
# (field-in-report, MATLAB function, [(report key, label), ...] to print)
POST_PASSES = [
    ("epoch_mint", "did2.convert.epochMint", [
        ("documents_inspected", "documents inspected"),
        ("documents_unreadable", "UNREADABLE"),
        ("session_documents_seen", "session documents"),
        ("epoch_strings_read", "epoch strings read"),
        ("distinct_epoch_id_strings", "distinct id strings"),
        ("distinct_session_epoch_pairs", "distinct (session,id) pairs"),
        ("pairs_minus_strings", "epochs the string key would have FUSED"),
        ("epochs_found_existing", "epochs already present"),
        ("epochs_minted", "epochs minted"),
        ("skipped_synthetic", "refused: synthetic whole_session_ id"),
        ("skipped_no_session_id", "refused: no base.session_id"),
        ("skipped_no_session_document", "refused: no session document"),
        ("skipped_ambiguous_session", "refused: ambiguous session"),
        ("method_parameters_seen", "method_parameters seen"),
        ("method_parameters_edges_filled", "method_parameters epoch_id filled"),
        ("method_parameters_unresolved", "method_parameters unresolved"),
        ("mint_quarantined", "QUARANTINED by the mint"),
    ]),
    ("session_anchor_fold", "did2.convert.resolveSessionAnchors", [
        ("documents_inspected", "documents inspected"),
        ("documents_unreadable", "UNREADABLE"),
        ("session_documents_seen", "session documents"),
        ("anchors_seen", "anchors seen"),
        ("anchors_relative", "  session_relative_reference"),
        ("anchors_bounded", "  session_bounded_reference"),
        ("anchors_folded", "FOLDED to relative_reference"),
        ("refused_total", "REFUSED (total)"),
        ("refused_no_session_id", "  no base.session_id"),
        ("refused_no_session_document", "  no session document"),
        ("refused_ambiguous_session", "  ambiguous session"),
        ("refused_ambiguous_relation", "  ambiguous relation (concurrent_with)"),
        ("refused_unknown_relation", "  relation not in the v1 enum"),
        ("refused_negative_extent", "  end < start"),
        ("fold_quarantined", "QUARANTINED by the fold"),
    ]),
]


# --- THE METADATA TIER ----------------------------------------------------
#
# WHY THESE CLASSES ARE COUNTED, AND WHY THE CO-OCCURRENCE IS THE MEASUREMENT.
#
# `metadata_editor` and the openMINDS dataset graph are written on INDEPENDENT
# paths in NDI, and neither path reads or removes the other's store:
#
#   +ndi/+database/+metadata_ds_core/saveEditor2Doc.m:11-23
#       docName = ['metadata_editor'];  ... ndi.document(docName, ...)
#       -- written on the editor app's window-CLOSE.
#   +ndi/+database/+metadata_app/+fun/save_dataset_docs.m:12
#       ndi.query('openminds.matlab_type','exact_string',
#                 'openminds.core.products.Dataset')
#       -- the openMINDS graph, written on the Save BUTTON.
#
# On the V_eta side `+migrators_j/metadata_editor.m` is the ONLY migrator that
# emits the dataset / person / organization / funding / publication tier
# (`grep -rln "'person'" src/did/+did2/+convert/` matches that one file), and
# there is no migrator for the bare `openminds` class at all. So a dataset that
# has the graph and NO metadata_editor document migrates with its authors,
# funding and publications unmigrated -- and nothing in this digest could say
# whether that combination occurs, because the counts sat unread in `by_class`.
#
# THE COUNTS COME FROM THE v1 SOURCE CENSUS, not from the top-level `by_class`.
# That is not a detail: the top-level table is the MIGRATED-OUTPUT histogram, in
# which `metadata_editor` is absent precisely WHEN IT MIGRATED SUCCESSFULLY.
# Reading absence there as "the corpus has no editor document" would invert the
# finding.
METADATA_EDITOR_CLASS = "metadata_editor"
# The bare `openminds` class IS the dataset-graph store -- it is the class
# save_dataset_docs.m queries and removes. The siblings below are the
# subject/stimulus/element bundles: a different tier, counted for context and
# deliberately NOT folded into the graph total.
OPENMINDS_GRAPH_CLASS = "openminds"
OPENMINDS_SIBLING_CLASSES = ("openminds_element", "openminds_stimulus",
                             "openminds_subject")
METADATA_TIER_CLASSES = ((METADATA_EDITOR_CLASS, OPENMINDS_GRAPH_CLASS)
                         + OPENMINDS_SIBLING_CLASSES)
# What the metadata_editor migrator emits. Printed from the migrated-output
# `by_class` beside the source counts, so "the source document was there" and
# "the tier got built" are separate, visible facts.
METADATA_TIER_EMITTED = ("dataset", "person", "organization", "funding",
                         "publication", "web_resource")


def norm_class(name):
    """Lowercase, underscores stripped -- the mechanical demo_ndi check.

    V_eta is snake_case, NDI is camelCase, and `did2.validate.sourceCensus`
    normalises its `by_class` keys THE SAME WAY (`normClass`: lower + strip
    underscores), so its table is keyed `metadataeditor`, not `metadata_editor`.
    A lookup that used the pretty spelling would return nothing and print 0 --
    a zero that is a property of the query, which is the exact failure that
    dispositioned `demo_ndi` as DELETE off a grep against a repository that has
    never contained that string.

    The top-level `by_class` is keyed by the real class name instead, so BOTH
    sides are normalised here rather than picking one spelling.
    """
    return str(name).replace("_", "").lower()


def normalised_class_index(table):
    """{normalised class name: {"count": int, "keys": [original keys]}}.

    Keys that collide under normalisation are SUMMED and both spellings kept,
    so a table carrying two spellings of one class cannot silently drop one.
    """
    index = {}
    if not isinstance(table, dict):
        return index
    for key, value in table.items():
        try:
            n = int(value)
        except (TypeError, ValueError):
            continue
        entry = index.setdefault(norm_class(key), {"count": 0, "keys": []})
        entry["count"] += n
        entry["keys"].append(key)
    return index


def class_count(index, name):
    entry = index.get(norm_class(name))
    return entry["count"] if entry else 0


def metadata_tier(r):
    """Read one report's metadata-tier counts out of the v1 source census.

    Returns a dict whose `measured` flag is the point of the whole function: a
    corpus that contributed NO readable census must not be renderable as a row
    of zeros. That distinction is the thing this project has shipped the
    absence of twice (`silentLoss` printing "0 empty edges" while reading
    nothing; the digest repeating it), so it is a separate field rather than a
    convention about what a zero means.
    """
    sc = r.get("source_census") or {}
    if not sc:
        return {"measured": False,
                "why": "this report carries no v1 source census block"}
    if "audit_failed" in sc:
        return {"measured": False,
                "why": "the v1 source census FAILED (%s)" % sc["audit_failed"]}
    total = sc.get("total_docs")
    if not isinstance(total, int) or total <= 0:
        return {"measured": False,
                "why": "the v1 source census read %s document(s)" % total}

    index = normalised_class_index(sc.get("by_class"))
    counts = dict((cls, class_count(index, cls)) for cls in METADATA_TIER_CLASSES)
    known = set(norm_class(c) for c in METADATA_TIER_CLASSES)
    extras = {}
    for key, entry in index.items():
        if key.startswith("openminds") and key not in known:
            extras["/".join(entry["keys"])] = entry["count"]

    editor = counts[METADATA_EDITOR_CLASS]
    graph = counts[OPENMINDS_GRAPH_CLASS]
    if graph and editor:
        verdict = "BOTH"
    elif graph:
        verdict = "GRAPH WITHOUT EDITOR"
    elif editor:
        verdict = "EDITOR WITHOUT GRAPH"
    else:
        verdict = "NEITHER"
    return {"measured": True, "source_total": total,
            "skipped": sc.get("skipped_docs", "?"),
            "counts": counts, "extras": extras,
            "editor": editor, "graph": graph, "verdict": verdict}


def render_metadata_tier(r, out):
    """Render one corpus's metadata-tier co-occurrence."""
    p = lambda s="": out.append(s)

    p("  METADATA TIER: metadata_editor vs the openMINDS dataset graph")
    m = metadata_tier(r)
    if not m["measured"]:
        p("      NOT MEASURED -- %s." % m["why"])
        p("      No count is printed for this corpus. A corpus that contributed")
        p("      no readable census and a corpus that contributed a ZERO are")
        p("      different facts and must not print identically.")
        return

    p("      DENOMINATOR: from the v1 SOURCE census -- %s doc(s) read, "
      "%s unreadable" % (m["source_total"], m["skipped"]))
    for cls in METADATA_TIER_CLASSES:
        if cls == METADATA_EDITOR_CLASS:
            note = "   <- the editor store (saveEditor2Doc)"
        elif cls == OPENMINDS_GRAPH_CLASS:
            note = "   <- the dataset graph store (save_dataset_docs)"
        else:
            note = "   (subject/stimulus tier, not the dataset graph)"
        p("      %8d  %-22s%s" % (m["counts"][cls], cls, note))
    if m["extras"]:
        for key, n in sorted(m["extras"].items(), key=lambda kv: (-kv[1], kv[0])):
            p("      %8d  %-22s   <- ANOTHER openminds_* class, not in the "
              "expected list" % (n, key))
    else:
        p("      (no openminds_* class outside the expected list)")

    p("      CO-OCCURRENCE: graph=%d, editor=%d -> %s"
      % (m["graph"], m["editor"], m["verdict"]))
    if m["verdict"] == "GRAPH WITHOUT EDITOR":
        p("      *** this corpus has the openMINDS dataset graph and NO")
        p("      *** metadata_editor document. `migrators_j/metadata_editor.m`")
        p("      *** is the only source of the dataset / person / organization /")
        p("      *** funding / publication / web_resource tier, and the bare")
        p("      *** `openminds` class has no migrator, so those facts migrate")
        p("      *** NOWHERE for this dataset.")

    by_class = r.get("by_class")
    if not isinstance(by_class, dict):
        p("      migrated dataset tier: NOT MEASURED -- this report carries no "
          "by_class")
    else:
        emitted = normalised_class_index(by_class)
        p("      migrated dataset tier (from the MIGRATED-OUTPUT by_class): %s"
          % ", ".join("%s=%d" % (c, class_count(emitted, c))
                      for c in METADATA_TIER_EMITTED))


# --- THE EPOCH ASSOCIATION (#72) ------------------------------------------
#
# WHAT IS BEING MEASURED AND WHY IT HAD NO COUNTER.
#
# The team settled (2026-08-10) that a statement reaches its epoch through a
# REFERENCE CHAIN, not a direct edge:
#
#     subject_interaction --time_reference_#--> relative_reference
#                         --relative_to-------> epoch
#
# `min_count: 1` guarantees the family EXISTS and `relative_reference.
# relative_to` is REQUIRED, so a POPULATED reference resolves. But
# `subject_interaction.time_reference_#` is `mustBeNonEmpty: false`, so
# `time_reference_1 = ''` SATISFIES the family and reaches nothing -- and the
# armed RequiredDependencies gate keys on `mustBeNonEmpty`, so it does not fire.
# Between them the two existing silent-loss checks step over exactly that
# document: the family check asks HOW MANY members exist and ignores what they
# hold, and the empty-edge check excludes numbered families by construction.
#
# MEASUREMENT ONLY. Nothing here or in silentLoss tightens a schema, arms a
# gate or changes what quarantines.
#
# The rows are printed from THIS list, not from whatever keys the report
# happens to carry, so a counter the report lacks prints "(absent)" instead of
# vanishing -- the same rule the post-pass block follows, and for the same
# reason: a missing counter and a zero counter are different facts.
EPOCH_ASSOCIATION_FAMILY = [
    ("family_docs_declaring", "document(s) whose CLASS declares a time-reference family"),
    ("family_docs_absent", "  carry NO member (cardinality -- reported separately above)"),
    ("family_docs_present", "  carry >= 1 member"),
    ("family_docs_all_empty", "    <-- REACH NOTHING: every member blank"),
    ("family_docs_populated", "    >= 1 populated member"),
    ("family_members_total", "members: total"),
    ("family_members_empty", "members: BLANK"),
    ("family_members_populated", "members: populated"),
]
EPOCH_ASSOCIATION_EDGES = [
    ("epoch_documents", "`epoch` document(s) in this batch"),
    ("epoch_id_docs_declaring", "document(s) whose CLASS declares an epoch_id edge"),
    ("epoch_id_edges_present", "epoch_id edge(s) found"),
    ("epoch_id_resolved", "  RESOLVED -- names a document in this batch"),
    ("epoch_id_resolved_not_epoch", "    of those, the target is NOT an epoch"),
    ("epoch_id_empty", "  EMPTY -- names nothing"),
    ("epoch_id_unresolved_in_batch", "  NOT IN THIS BATCH -- see the note below"),
]
EPOCH_ASSOCIATION_CHAIN = [
    ("chain_docs_examined", "document(s) with a POPULATED member"),
    ("chain_docs_reaching_epoch", "  REACH AN EPOCH   <-- the number the decision rests on"),
    ("chain_docs_reaching_no_epoch", "  terminate at a definite non-epoch document"),
    ("chain_docs_undetermined", "  UNDETERMINED -- left the batch, or too deep"),
    ("chain_members_examined", "member(s) examined, of which:"),
    ("chain_member_reaches_epoch", "  reach an epoch"),
    ("chain_member_reaches_other", "  terminate elsewhere"),
    ("chain_member_unresolved", "  target not in this batch"),
    ("chain_member_incomplete", "  every branch left the batch"),
    ("chain_member_not_a_reference", "  target is not a time reference at all"),
    ("chain_member_anchor_absent", "  reference declares no anchor edge (terminal by design)"),
    ("chain_member_anchor_empty", "  reference's REQUIRED anchor is blank"),
    ("chain_member_depth_exceeded", "  chain longer than max_depth"),
    ("chain_member_unclassified", "  UNCLASSIFIED -- a state with no counter"),
]


def epoch_association(r):
    """Read one report's epoch-association block, or say why it cannot be read.

    Four NOT-MEASURED conditions, kept apart from each other and from a zero:

      absent        the report has no `epoch_association` -- it predates the
                    counter. NOT rendered as zeros.
      malformed     the key is there and is not an object.
      inspected 0   silentLoss looked at nothing. Every count below it is
                    vacuous -- this is the original defect, and the rule is
                    unchanged: check total_docs before believing any figure.
      all unreadable  it was handed documents and could parse none.
    """
    sl = r.get("silent_loss") or {}
    if not isinstance(sl, dict):
        # `"audit_failed" in sl` on a string is a SUBSTRING test, which would
        # answer a question nobody asked. Malformed input gets its own reading.
        return {"measured": False,
                "why": "the silent_loss field is malformed (%s)"
                       % type(sl).__name__}
    if "audit_failed" in sl:
        return {"measured": False,
                "why": "the silent-loss audit FAILED (%s)" % sl["audit_failed"]}
    ea = sl.get("epoch_association")
    if ea is None:
        return {"measured": False,
                "why": "this report carries no epoch_association block -- the "
                       "counter was not wired into the run that produced it"}
    if not isinstance(ea, dict):
        return {"measured": False,
                "why": "the epoch_association block is malformed (%s)"
                       % type(ea).__name__}
    inspected = ea.get("docs_inspected")
    if not isinstance(inspected, int) or inspected <= 0:
        return {"measured": False, "block": ea,
                "why": "it inspected %s document(s)" % inspected}
    unreadable = ea.get("docs_unreadable")
    if isinstance(unreadable, int) and unreadable >= inspected:
        return {"measured": False, "block": ea,
                "why": "all %s document(s) handed to it were unreadable"
                       % inspected}
    return {"measured": True, "block": ea, "inspected": inspected}


def _ea_rows(ea, rows, out, indent="          "):
    for key, label in rows:
        if key in ea:
            out.append("%s%10s  %s" % (indent, ea[key], label))
        else:
            # A counter the report does not carry is NOT printed as 0.
            out.append("%s%10s  %s" % (indent, "(absent)", label))


def render_epoch_association(r, out):
    """Render one corpus's epoch-association block. Denominator first."""
    p = lambda s="": out.append(s)

    p("  EPOCH ASSOCIATION (#72): does a statement actually reach an epoch?")
    p("      MEASUREMENT ONLY -- nothing here is enforced and nothing "
      "quarantines on it.")
    m = epoch_association(r)
    if not m["measured"]:
        p("      NOT MEASURED -- %s." % m["why"])
        p("      No count is printed for this corpus. A corpus that could not")
        p("      be measured and a corpus that measured a ZERO are different")
        p("      facts and must not print identically.")
        return
    ea = m["block"]

    p("      DENOMINATOR: %s document(s) inspected, %s unreadable, %s classified"
      % (ea.get("docs_inspected", "?"), ea.get("docs_unreadable", "?"),
         ea.get("docs_classified", "?")))
    # THE NAMES IT FOLLOWED. Everything else in the block is schema-driven;
    # these are not, so a rename would send every count to zero and the report
    # would read clean -- the demo_ndi failure, where a grep against a string
    # the repository has never contained was reported as "this does not exist".
    p("      FOLLOWED: <family> -> `%s` -> `%s`, max depth %s"
      % (ea.get("anchor_edge", "?"), ea.get("terminal_class", "?"),
         ea.get("max_depth", "?")))
    for key, label in (("terminal_class_in_schema", "terminal_class"),
                       ("reference_root_in_schema", "reference_root")):
        val = ea.get(key)
        if val == 1:
            continue
        p("      *** `%s` (%s) DOES NOT LOAD FROM THE SCHEMA (%s=%s)."
          % (ea.get(label, "?"), label, key, val))
        p("      *** Every count below that mentions it is a property of the")
        p("      *** query, not of the data. Do NOT read them as zeros.")

    p("      (1) THE TIME-REFERENCE FAMILY -- does it reach anything at all?")
    _ea_rows(ea, EPOCH_ASSOCIATION_FAMILY, out)
    if ea.get("family_docs_declaring") == 0:
        p("          *** NO DOCUMENT'S CLASS DECLARES A TIME-REFERENCE FAMILY.")
        p("          *** The family counters could not fire; their zeros mean")
        p("          *** 'untested', not 'clean'.")
    for e in aslist(ea.get("family_all_empty_by_class"))[:10]:
        p("          %8s  %s.%s  family present, every member blank"
          % (e.get("count", "?"), e.get("class_name", "?"),
             e.get("edge_name", "?")))

    p("      (2) `epoch` DOCUMENTS AND `epoch_id` EDGES (checked BY NAME)")
    _ea_rows(ea, EPOCH_ASSOCIATION_EDGES, out)
    p("          NOTE: 'not in this batch' is NOT 'dangling'. A batch is a")
    p("          SAMPLE -- an edge naming a document outside it may resolve in")
    p("          a full migration (jSessionAnchor's discovery-mode orphans were")
    p("          exactly that). The three states are kept distinct; the third is")
    p("          named for what was measured.")
    for e in aslist(ea.get("epoch_id_by_class"))[:10]:
        p("          %8s  %s.epoch_id  %s"
          % (e.get("count", "?"), e.get("class_name", "?"),
             e.get("state", "?")))

    p("      (3) THE CHAIN, END TO END")
    _ea_rows(ea, EPOCH_ASSOCIATION_CHAIN, out)
    if ea.get("chain_docs_examined") == 0:
        p("          *** NO DOCUMENT CARRIES A POPULATED MEMBER, so the chain")
        p("          *** was never walked. Zero reaching an epoch means")
        p("          *** 'untested', not 'nothing reaches one'.")
    for e in aslist(ea.get("chain_terminus_by_class"))[:10]:
        p("          %8s  chain terminated at: %s"
          % (e.get("count", "?"), e.get("class_name", "?")))


def rollup_epoch_association(reports, out):
    """Cross-corpus epoch association, denominator first and unmeasured named.

    The rollup is the number that gets quoted -- in a plan document, in a commit
    message, in CLAUDE.md -- so it is computed here rather than hand-summed from
    the per-corpus blocks. That is not a hypothetical: 562,422 was recorded as
    an inspected total and was the six corpora with one of them contributing its
    `migrated_count` instead. Corpora that contributed nothing readable are
    NAMED and excluded, never summed in as zeros.
    """
    p = lambda s="": out.append(s)

    measured, unmeasured = [], []
    totals = {}
    empty_rows, edge_rows, term_rows = {}, {}, {}
    schema_warn = []
    for i, r in enumerate(reports):
        name = str(r.get("corpus") or "report #%d" % (i + 1))
        m = epoch_association(r)
        if not m["measured"]:
            unmeasured.append("%s (%s)" % (name, m["why"]))
            continue
        measured.append(name)
        ea = m["block"]
        for key, _label in (EPOCH_ASSOCIATION_FAMILY + EPOCH_ASSOCIATION_EDGES
                            + EPOCH_ASSOCIATION_CHAIN
                            + [("docs_inspected", ""), ("docs_unreadable", ""),
                               ("docs_classified", "")]):
            if key in ea:
                try:
                    totals[key] = totals.get(key, 0) + int(ea[key] or 0)
                except (TypeError, ValueError):
                    pass
        if ea.get("terminal_class_in_schema") != 1 or \
                ea.get("reference_root_in_schema") != 1:
            schema_warn.append(name)
        for e in aslist(ea.get("family_all_empty_by_class")):
            key = "%s.%s" % (e.get("class_name", "?"), e.get("edge_name", "?"))
            empty_rows[key] = empty_rows.get(key, 0) + int(e.get("count") or 0)
        for e in aslist(ea.get("epoch_id_by_class")):
            key = "%s.epoch_id  %s" % (e.get("class_name", "?"),
                                       e.get("state", "?"))
            edge_rows[key] = edge_rows.get(key, 0) + int(e.get("count") or 0)
        for e in aslist(ea.get("chain_terminus_by_class")):
            key = str(e.get("class_name", "?"))
            term_rows[key] = term_rows.get(key, 0) + int(e.get("count") or 0)

    p("")
    p("  EPOCH ASSOCIATION (#72) -- MEASUREMENT ONLY, nothing is enforced")
    p("      DENOMINATOR: %d corpus report(s); %d carried a readable "
      "epoch-association block, %d did not; %d document(s) inspected in total"
      % (len(reports), len(measured), len(unmeasured),
         totals.get("docs_inspected", 0)))
    if unmeasured:
        p("      *** NOT MEASURED in: %s" % ", ".join(unmeasured))
        p("      *** the totals below are sums over %d corpora, not %d -- do"
          % (len(measured), len(reports)))
        p("      *** not quote them as a whole-corpus figure.")
    if not measured:
        p("      (nothing to total -- no corpus contributed a readable block)")
        return
    if schema_warn:
        p("      *** the followed class names DID NOT LOAD from the schema in:")
        p("      *** %s. Their counts are a property of the query."
          % ", ".join(schema_warn))

    p("      (1) THE TIME-REFERENCE FAMILY")
    _ea_rows(totals, EPOCH_ASSOCIATION_FAMILY, out, indent="        ")
    p("      (2) `epoch` DOCUMENTS AND `epoch_id` EDGES")
    _ea_rows(totals, EPOCH_ASSOCIATION_EDGES, out, indent="        ")
    p("      (3) THE CHAIN, END TO END")
    _ea_rows(totals, EPOCH_ASSOCIATION_CHAIN, out, indent="        ")

    for label, table in (("FAMILIES PRESENT AND ENTIRELY BLANK", empty_rows),
                         ("epoch_id EDGES BY CLASS AND STATE", edge_rows),
                         ("CHAIN TERMINI (non-epoch)", term_rows)):
        p("      %s: %d occurrence(s) across %d row(s)"
          % (label, sum(table.values()), len(table)))
        for key, n in sorted(table.items(), key=lambda kv: (-kv[1], kv[0])):
            p("        %8d  %s" % (n, key))
        if not table:
            p("        (none)")


def render_post_passes(r, out):
    """Render the batch post-pass reports, denominator (the pass list) first.

    Four distinguishable states per pass, and keeping them distinguishable is
    the entire job:

      absent        the report does not carry the field -- the pass was not
                    wired into the run that produced it (or the report predates
                    the wiring). NOT rendered as zeros.
      pass_failed   the harness guard (did2.unittest.helpers.runBatchPass)
                    caught a throw. Rendered as a *** banner: the documents are
                    in pass-1 form and the run's other numbers describe a
                    migration that did not include this pass.
      ran == false  the pass returned early -- a non-V_eta target, or an empty
                    batch. A legitimate no-op, and a different fact from both
                    of the above.
      otherwise     the counters.
    """
    p = lambda s="": out.append(s)

    present = [name for name, _fn, _rows in POST_PASSES if name in r]
    p("  batch post-passes: %d expected, %d present in this report"
      % (len(POST_PASSES), len(present)))

    for name, fn, rows in POST_PASSES:
        rep = r.get(name)
        if rep is None:
            p("      %-22s NOT IN THIS REPORT -- the pass was not wired into"
              % name)
            p("      %-22s the run that produced it (%s)" % ("", fn))
            continue
        if not isinstance(rep, dict):
            p("      %-22s MALFORMED (%r)" % (name, type(rep).__name__))
            continue
        failed = rep.get("pass_failed")
        if failed:
            p("      %-22s *** FAILED: %s" % (name, failed))
            p("      %-22s *** identifier: %s"
              % ("", rep.get("pass_failed_identifier", "?")))
            p("      %-22s *** its documents are in PASS-1 FORM. Every other"
              % "")
            p("      %-22s *** number in this report describes a migration"
              % "")
            p("      %-22s *** that did NOT include %s." % ("", fn))
            continue
        if rep.get("ran") is False:
            p("      %-22s did not run (non-V_eta target, or an empty batch)"
              % name)
            continue
        p("      %-22s %s" % (name, fn))
        for key, label in rows:
            if key in rep:
                p("          %10s  %s" % (rep[key], label))
            else:
                # A counter the report does not carry is NOT printed as 0.
                p("          %10s  %s" % ("(absent)", label))
        # THE DELETION GATE, stated in the digest rather than left to be
        # re-derived. The six retiring reference classes may leave V_eta only
        # when refused_total is 0 AND no session_*_reference survives in
        # by_class -- deleting a class whose documents still exist is the
        # epochfiles_ingested regression, which cost 2,484 quarantines.
        if name == "session_anchor_fold":
            survivors = 0
            by_class = r.get("by_class") or {}
            for cls in ("session_relative_reference", "session_bounded_reference"):
                try:
                    survivors += int(by_class.get(cls) or 0)
                except (TypeError, ValueError):
                    pass
            refused = rep.get("refused_total")
            p("          deletion gate: refused_total=%s, surviving "
              "session_*_reference in by_class=%s" % (refused, survivors))
            if refused == 0 and survivors == 0 and rep.get("anchors_seen"):
                p("          -> BOTH HALVES MET for this corpus. The corpora "
                  "are a SAMPLE, so this is")
                p("             one corpus's evidence, not authorisation to "
                  "delete the classes.")


def render_report(r, out):
    """Render one corpus report. Raises on malformed input; the caller isolates."""
    p = lambda s="": out.append(s)

    p("")
    p("--- %s ---" % r.get("corpus", "(unnamed)"))
    p("  total=%s  migrated=%s  quarantine=%s"
      % (r.get("total", "?"), r.get("migrated_count", "?"),
         r.get("quarantine_count", "?")))

    sl = r.get("silent_loss") or {}
    if "audit_failed" in sl:
        p("  silent-loss: AUDIT FAILED (%s)" % sl["audit_failed"])
    elif sl:
        # total_docs FIRST and unconditionally. Without the denominator, a
        # census that inspected nothing and one that found nothing wrong print
        # identically -- see the module docstring.
        td = sl.get("total_docs", "?")
        p("  silent-loss: inspected %s doc(s), skipped %s"
          % (td, sl.get("skipped_docs", "?")))
        if td == 0:
            p("  *** total_docs=0 -- THE CENSUS INSPECTED NOTHING. The counts")
            p("  *** below are vacuous; do NOT read them as a clean result.")
        elif isinstance(td, int) and sl.get("skipped_docs", 0) == td:
            p("  *** every document was skipped -- counts below are vacuous.")
        p("  silent-loss: %s empty required edge(s), %s vacuous required field(s)"
          % (sl.get("empty_dependency_count", "?"),
             sl.get("vacuous_field_count", "?")))
        for e in aslist(sl.get("empty_required_dependency"))[:10]:
            p("      %8s  %s.%s" % (e.get("count", "?"),
                                    e.get("class_name", "?"),
                                    e.get("edge_name", "?")))
        for f in aslist(sl.get("vacuous_required_field"))[:10]:
            p("      %8s  %s / %s.%s" % (f.get("count", "?"),
                                         f.get("class_name", "?"),
                                         f.get("block", "?"),
                                         f.get("field_name", "?")))
        # The family-count number, printed UNCONDITIONALLY like the two above.
        # It was measured and written into the report from the first run, and
        # then never rendered -- so the one thing standing between it and a
        # decision was that nobody could see it without downloading an
        # artifact. That is the same write-only condition this whole file
        # exists to remove, one field further down.
        p("  silent-loss: %s edge-family cardinality violation(s)"
          % sl.get("family_violation_count", "?"))
        for v in aslist(sl.get("family_count_violation"))[:10]:
            p("      %8s  %s.%s  declared %s, found %s"
              % (v.get("count", "?"), v.get("class_name", "?"),
                 v.get("edge_name", "?"), v.get("declared", "?"),
                 v.get("found", "?")))
        # #52. A uniqueness violation is a DIFFERENT fact from a cardinality
        # one -- the count is legal and the members are indistinguishable --
        # so it gets its own line and its own denominators. Those denominators
        # are not decoration: this counter has four ways to read zero (the
        # rule fired and found nothing / no document carried two members / the
        # targets were not in the batch / the referents declare no clock), and
        # only the numbers below tell them apart.
        ud = sl.get("uniqueness_denominator") or {}
        p("  silent-loss: %s family-uniqueness violation(s)"
          % sl.get("family_uniqueness_violation_count", "?"))
        p("      DENOMINATOR: %s famil(ies) declare a uniqueness rule; "
          "%s doc-family pair(s) carry a member, %s carry MORE THAN ONE"
          % (ud.get("families_declared", "?"),
             ud.get("docs_with_family", "?"),
             ud.get("docs_multi_member", "?")))
        p("      DENOMINATOR: %s member(s) examined -- %s resolved, "
          "%s unresolved (target not in batch), %s with no key on the referent"
          % (ud.get("members_examined", "?"), ud.get("members_resolved", "?"),
             ud.get("members_unresolved", "?"), ud.get("members_no_key", "?")))
        p("      DENOMINATOR: compared on %s CURIE(s) and %s label(s) "
          "(labels because the NDIC clock terms are unminted -- #67)"
          % (ud.get("members_keyed_by_node", "?"),
             ud.get("members_keyed_by_name", "?")))
        if ud.get("docs_multi_member") == 0:
            p("      *** no document carries two members of a governed family,")
            p("      *** so the rule COULD NOT FIRE. Zero above means"
              " 'untested', not 'clean'.")
        for v in aslist(sl.get("family_uniqueness_violation"))[:10]:
            p("      %8s  %s.%s  two members share %s = %s"
              % (v.get("count", "?"), v.get("class_name", "?"),
                 v.get("edge_name", "?"), v.get("unique_by", "?"),
                 v.get("key", "?")))

    if "fragment_count" in r:
        fc = r["fragment_count"]
        p("  FRAGMENTS: %s migration(s) emitted only scaffolding%s"
          % (fc, "  <-- payload dropped, invisible to every other counter" if fc else ""))
        for k, v in sorted((r.get("fragment_by_class") or {}).items(),
                           key=lambda kv: -kv[1])[:15]:
            p("      %8s  %s" % (v, k))

    if "unconverted_count" in r:
        p("  unconverted: %s document(s) returned unchanged" % r["unconverted_count"])
        for k, v in sorted((r.get("unconverted_by_class") or {}).items(),
                           key=lambda kv: -kv[1])[:15]:
            p("      %8s  %s" % (v, k))

    sc = r.get("source_census") or {}
    if "audit_failed" in sc:
        p("  v1 source census: AUDIT FAILED (%s)" % sc["audit_failed"])
    elif sc:
        # The three pre-build measurements. DENOMINATOR FIRST, same rule as the
        # silent-loss block above and for the same reason.
        std = sc.get("total_docs", "?")
        p("  v1 source census: read %s v1 doc(s), %s unreadable"
          % (std, sc.get("skipped_docs", "?")))
        if std == 0:
            p("  *** total_docs=0 -- THE SOURCE CENSUS READ NOTHING. Everything")
            p("  *** below is vacuous; do NOT quote it as a measurement.")
        else:
            p("      epoch ids: %s doc(s) carry one, %s distinct"
              % (sc.get("docs_with_epoch_id", "?"),
                 sc.get("distinct_epoch_ids", "?")))
            for e in aslist(sc.get("epoch_id_by_prefix")):
                p("          %-16s %6s distinct  %8s doc(s)"
                  % (e.get("prefix", "?"), e.get("distinct_ids", "?"),
                     e.get("doc_count", "?")))
            # THE EPOCH GROUPING HAZARD. One `epoch` per distinct id string is
            # correct only where the string is unique per epoch;
            # `whole_session_<ref>` is minted per ELEMENT and would fuse.
            p("      grouping hazard: %s synthetic (whole_session_) id(s), "
              "%s id(s) spanning >1 session"
              % (sc.get("synthetic_epoch_id_count", "?"),
                 sc.get("cross_session_epoch_id_count", "?")))
            for x in aslist(sc.get("synthetic_epoch_ids"))[:5]:
                p("          would fuse %4s element span(s): %s"
                  % (x.get("distinct_elements", "?"), x.get("epoch_id", "?")))
            p("      session documents: %s   (distinct base.session_id: %s)"
              % (sc.get("session_doc_count", "?"),
                 sc.get("distinct_session_ids", "?")))
            if sc.get("session_doc_count") == 0:
                p("      *** NONE -- a REQUIRED `relative_to` would have no")
                p("      *** referent in this corpus.")
            p("      stimulation approaches: %s doc(s) over %s epoch(s)"
              % (sc.get("approach_doc_count", "?"),
                 sc.get("approach_epochs", "?")))
            for d in aslist(sc.get("subjects_per_approach_epoch")):
                p("          %4s subject(s): %6s epoch(s)"
                  % (d.get("n_subjects", "?"), d.get("n_epochs", "?")))
            if sc.get("approach_doc_count"):
                p("          %s approach epoch(s) with NO presentation document"
                  % sc.get("approach_epochs_no_presentation", "?"))
            # WHY THE TWO SIDES DO NOT MEET. Rendered whenever either exists:
            # Dab has 635 approaches and 1,242 presentations sharing NO epoch
            # id, and the pooled prefix histogram cannot say why because it
            # mixes every class together.
            if sc.get("approach_doc_count") or sc.get("presentation_doc_count"):
                if "approach_presentation_shared_epochs" in sc:
                    p("          epoch ids carried by BOTH classes: %s"
                      % sc["approach_presentation_shared_epochs"])
                for label, key in (("approach", "approach_epoch_prefixes"),
                                   ("presentation", "presentation_epoch_prefixes")):
                    tally = aslist(sc.get(key))
                    if not tally:
                        continue
                    p("          %s epoch ids by prefix:" % label)
                    for t in tally:
                        p("            %-16s %4s distinct  %6s doc(s)"
                          % (t.get("prefix", "?"), t.get("n_distinct", "?"),
                             t.get("n_docs", "?")))

    render_epoch_association(r, out)
    render_metadata_tier(r, out)
    render_post_passes(r, out)

    for q in aslist(r.get("quarantine_reasons"))[:5]:
        p("  quarantine: %5s [%s] %s" % (q.get("count", "?"),
                                         q.get("class_name", "?"),
                                         str(q.get("reason", ""))[:90]))


def find_reports(reports_dirs):
    """Find every *-summary.json under each root in reports_dirs, at ANY depth.

    Return (chosen_paths, all_paths, dirs_walked).

    SEVERAL ROOTS because MATLAB's pwd during a corpus run is not fixed:
    `test-corpus.yml` downloads artifacts into `corpus-reports/` while
    `test-code.yml` runs the corpora in-process and they land in
    `tests/corpus-reports/`. That second workflow's digest step has been
    printing "NO CORPUS REPORTS FOUND" for the same reason, one directory off.
    A root that does not exist is reported, not fatal.

    RECURSIVE ON PURPOSE. The reports are written to `<pwd>/corpus-reports/`
    and MATLAB's pwd during a corpus run is `tests/`, so the report lands at
    `tests/corpus-reports/<NAME>-summary.json`. `upload-artifact` given two
    search paths takes their LEAST COMMON ANCESTOR as the artifact root -- the
    repo root -- so the zip carries `tests/corpus-reports/...`, and
    `download-artifact --path corpus-reports` unpacks it to
    `corpus-reports/tests/corpus-reports/...`. Run #3 (31315510527) downloaded
    5 artifacts, 10 files, and matched ZERO with the old one-level glob:

        Total of 5 artifact(s) downloaded
        NO CORPUS REPORTS FOUND (corpus-reports/*-summary.json)
        With the provided path, there will be 10 files uploaded

    Depth is an artifact-plumbing detail and must never again decide whether
    the census is seen. Duplicates (the same corpus found at two depths, which
    the two-path upload can produce) collapse to the shallowest path, and the
    collapse is REPORTED rather than silently applied.
    """
    all_paths, dirs_walked = [], 0
    for reports_dir in reports_dirs:
        for root, _dirs, names in os.walk(reports_dir):
            dirs_walked += 1
            for name in names:
                if name.endswith("-summary.json"):
                    all_paths.append(os.path.join(root, name))
    all_paths.sort()

    by_name, chosen = {}, []
    for path in all_paths:
        key = os.path.basename(path)
        if key in by_name:
            continue
        by_name[key] = path
        chosen.append(path)
    chosen.sort(key=lambda p: (os.path.basename(p), p))
    return chosen, all_paths, dirs_walked


def rollup(reports, out):
    """Sum the headline counters ACROSS corpora, with the denominator first.

    WHY THIS EXISTS
    ---------------
    Every number in this digest is per-corpus, and the number that actually gets
    quoted -- in a plan document, in a commit message, in CLAUDE.md -- is the
    TOTAL. Until now that total was produced by a human reading six blocks and
    adding them up, and the record shows what that costs:

      * The empty-required-edge table was written down as "12,296 documents,
        three classes" and stood for months. It was 26,406 across six, and the
        three it named were the three SMALLEST. The two largest rows were in the
        same report the three came from; nobody had read past the daq family.
      * The next re-derivation, on 2026-08-09, was right -- but only because
        someone re-summed it by hand a second time, and it had to carry a
        standing note telling the next reader to do it again.

    A total that must be recomputed by hand from a report is a total that goes
    stale silently, because nothing compares it to anything. So the digest
    computes it.

    The DENOMINATOR comes first and unconditionally, per the standing rule: how
    many corpora went into the sum, and how many of them actually carried the
    field being summed. A total over four corpora and a total over six are
    different facts and must not print identically -- which is exactly the
    failure mode that made "0 empty edges" believable while `silentLoss` was
    reading nothing.
    """
    p = lambda s="": out.append(s)

    edges, fields, families, uniques = {}, {}, {}, {}
    # #52 rollup denominators, summed the same way the counts are.
    uni_den = {"docs_with_family": 0, "docs_multi_member": 0,
               "members_examined": 0, "members_resolved": 0,
               "members_unresolved": 0, "members_no_key": 0,
               "members_keyed_by_node": 0, "members_keyed_by_name": 0}
    inspected = 0
    addends = []
    quarantine = 0
    fragments = 0
    with_silent_loss = 0
    for i, r in enumerate(reports):
        sl = r.get("silent_loss") or {}
        try:
            quarantine += int(r.get("quarantine_count") or 0)
        except (TypeError, ValueError):
            pass
        try:
            fragments += int(r.get("fragment_count") or 0)
        except (TypeError, ValueError):
            pass
        if not sl or "audit_failed" in sl:
            continue
        with_silent_loss += 1
        try:
            n = int(sl.get("total_docs") or 0)
            inspected += n
            addends.append((str(r.get("corpus") or "report #%d" % (i + 1)), n))
        except (TypeError, ValueError):
            pass
        for e in aslist(sl.get("empty_required_dependency")):
            key = "%s.%s" % (e.get("class_name", "?"), e.get("edge_name", "?"))
            edges[key] = edges.get(key, 0) + int(e.get("count") or 0)
        for f in aslist(sl.get("vacuous_required_field")):
            key = "%s / %s.%s" % (f.get("class_name", "?"), f.get("block", "?"),
                                  f.get("field_name", "?"))
            fields[key] = fields.get(key, 0) + int(f.get("count") or 0)
        for v in aslist(sl.get("family_count_violation")):
            key = "%s.%s" % (v.get("class_name", "?"), v.get("edge_name", "?"))
            families[key] = families.get(key, 0) + int(v.get("count") or 0)
        for v in aslist(sl.get("family_uniqueness_violation")):
            key = "%s.%s  (%s = %s)" % (v.get("class_name", "?"),
                                        v.get("edge_name", "?"),
                                        v.get("unique_by", "?"),
                                        v.get("key", "?"))
            uniques[key] = uniques.get(key, 0) + int(v.get("count") or 0)
        ud = sl.get("uniqueness_denominator") or {}
        for k in uni_den:
            try:
                uni_den[k] += int(ud.get(k) or 0)
            except (TypeError, ValueError):
                pass

    p("")
    p("=" * 72)
    p("ACROSS ALL CORPORA")
    p("=" * 72)
    p("  DENOMINATOR: %d corpus report(s) summed; %d carried a readable "
      "silent-loss audit; %d document(s) inspected in total"
      % (len(reports), with_silent_loss, inspected))
    # THE ADDENDS, NAMED. A total whose inputs are three screens up gets
    # re-derived by hand, and a hand re-derivation picks up the wrong line.
    # It already has: 562,422 was recorded in DID-schema/CLAUDE.md for corpus
    # run 31415147934, and 562,422 is EXACTLY the six `inspected` figures with
    # corpus B's `migrated_count` (13,778) substituted for its `inspected`
    # (13,804) -- the two numbers sit two lines apart in B's block. The true
    # sum is 562,448. (That run predates this rollup entirely, so the figure
    # could only have been hand-summed.) Printing the addends beside the total,
    # and naming which counter they are, makes that substitution visible
    # instead of a 26-document discrepancy nobody can source.
    p("      addends -- silent-loss `inspected`, NOT `migrated` and NOT "
      "`total`:")
    p("      %s = %d"
      % (" + ".join("%s %d" % (name, n) for name, n in addends) or "(none)",
         inspected))
    if with_silent_loss != len(reports):
        p("  *** %d report(s) contributed NO silent-loss numbers. The totals"
          % (len(reports) - with_silent_loss))
        p("  *** below are sums over %d corpora, not %d -- do not quote them"
          % (with_silent_loss, len(reports)))
        p("  *** as a whole-corpus figure.")
    p("  quarantined: %d       fragments: %d" % (quarantine, fragments))

    for label, table in (("EMPTY REQUIRED EDGES", edges),
                         ("VACUOUS REQUIRED FIELDS", fields),
                         ("EDGE-FAMILY CARDINALITY VIOLATIONS", families),
                         ("EDGE-FAMILY UNIQUENESS VIOLATIONS", uniques)):
        total = sum(table.values())
        p("")
        p("  %s: %d document(s) across %d row(s)" % (label, total, len(table)))
        if table is uniques:
            # The uniqueness row set is the one where an empty table is
            # AMBIGUOUS, so its denominators print beside it rather than three
            # screens up in the per-corpus blocks.
            p("      DENOMINATOR: %d doc-family pair(s) carried a member, "
              "%d carried MORE THAN ONE"
              % (uni_den["docs_with_family"], uni_den["docs_multi_member"]))
            p("      DENOMINATOR: %d member(s) examined -- %d resolved, "
              "%d unresolved, %d with no key on the referent"
              % (uni_den["members_examined"], uni_den["members_resolved"],
                 uni_den["members_unresolved"], uni_den["members_no_key"]))
            p("      DENOMINATOR: %d compared on a CURIE, %d on a label"
              % (uni_den["members_keyed_by_node"],
                 uni_den["members_keyed_by_name"]))
            if uni_den["docs_multi_member"] == 0:
                p("      *** NOTHING IN REACH CARRIES TWO MEMBERS OF A")
                p("      *** GOVERNED FAMILY. The rule could not fire; the")
                p("      *** zero is 'untested', not 'clean'.")
        for key, n in sorted(table.items(), key=lambda kv: (-kv[1], kv[0])):
            p("      %8d  %s" % (n, key))
        if not table:
            p("      (none)")

    rollup_epoch_association(reports, out)
    rollup_metadata_tier(reports, out)
    rollup_post_passes(reports, out)


def rollup_metadata_tier(reports, out):
    """Cross-corpus metadata tier: does ANY corpus have the graph and no editor?

    THE QUESTION THIS ANSWERS. `metadata_editor` and the openMINDS dataset
    graph are written by two independent NDI code paths (see METADATA_TIER
    above), and only the first has a migrator that produces the dataset /
    person / funding / publication tier. Whether the split actually occurs in
    real data is a per-corpus co-occurrence, so it cannot be read off any
    single corpus's block -- which is why the buckets below NAME their corpora
    rather than only counting them.

    The denominator is how many reports carried a readable v1 source census,
    printed before any count, and the corpora that carried none are named. A
    corpus missing from the measurement and a corpus contributing a zero are
    the two readings this whole block exists to keep apart.
    """
    p = lambda s="": out.append(s)

    measured, unmeasured = [], []
    totals = dict((cls, 0) for cls in METADATA_TIER_CLASSES)
    extras = {}
    source_docs = 0
    buckets = {"BOTH": [], "GRAPH WITHOUT EDITOR": [],
               "EDITOR WITHOUT GRAPH": [], "NEITHER": []}
    emitted_totals = dict((cls, 0) for cls in METADATA_TIER_EMITTED)
    with_by_class = 0

    for i, r in enumerate(reports):
        name = str(r.get("corpus") or "report #%d" % (i + 1))
        if isinstance(r.get("by_class"), dict):
            with_by_class += 1
            index = normalised_class_index(r["by_class"])
            for cls in METADATA_TIER_EMITTED:
                emitted_totals[cls] += class_count(index, cls)
        m = metadata_tier(r)
        if not m["measured"]:
            unmeasured.append("%s (%s)" % (name, m["why"]))
            continue
        measured.append(name)
        source_docs += m["source_total"]
        for cls in METADATA_TIER_CLASSES:
            totals[cls] += m["counts"][cls]
        for key, n in m["extras"].items():
            extras[key] = extras.get(key, 0) + n
        buckets[m["verdict"]].append(name)

    p("")
    p("  METADATA TIER (metadata_editor vs the openMINDS dataset graph)")
    p("      DENOMINATOR: %d corpus report(s); %d carried a readable v1 source "
      "census, %d did not; %d v1 source doc(s) read in total"
      % (len(reports), len(measured), len(unmeasured), source_docs))
    if unmeasured:
        p("      *** NOT MEASURED in: %s" % ", ".join(unmeasured))
        p("      *** the totals below are sums over %d corpora, not %d."
          % (len(measured), len(reports)))
    if not measured:
        p("      (nothing to total -- no corpus contributed a source census)")
        return

    for cls in METADATA_TIER_CLASSES:
        p("      %8d  %s" % (totals[cls], cls))
    for key, n in sorted(extras.items(), key=lambda kv: (-kv[1], kv[0])):
        p("      %8d  %s   <- ANOTHER openminds_* class, not in the expected "
          "list" % (n, key))

    p("      CO-OCCURRENCE over the %d measured corpus/corpora:" % len(measured))
    for verdict in ("BOTH", "GRAPH WITHOUT EDITOR", "EDITOR WITHOUT GRAPH",
                    "NEITHER"):
        names = buckets[verdict]
        p("      %8d  %-22s %s"
          % (len(names), verdict, ", ".join(names) if names else "--"))
    if buckets["GRAPH WITHOUT EDITOR"]:
        p("      *** %d corpus/corpora carry the openMINDS dataset graph with NO"
          % len(buckets["GRAPH WITHOUT EDITOR"]))
        p("      *** metadata_editor document. Their authors, funding and")
        p("      *** publications have NO migrator and migrate nowhere.")
        p("      *** The corpora are a SAMPLE: this is what these %d measured"
          % len(measured))
        p("      *** corpora hold, not a bound on how often the split occurs.")

    if with_by_class != len(reports):
        p("      migrated dataset tier: %d of %d report(s) carried a by_class"
          % (with_by_class, len(reports)))
    p("      migrated dataset tier (from the MIGRATED-OUTPUT by_class): %s"
      % ", ".join("%s=%d" % (cls, emitted_totals[cls])
                  for cls in METADATA_TIER_EMITTED))


def rollup_post_passes(reports, out):
    """Cross-corpus post-pass coverage: did each pass run EVERYWHERE?

    THE FAILURE THIS DETECTS. A batch pass wired into some call sites and not
    others is worse than one wired nowhere: the corpus goes green while another
    path does something else, and nothing in a per-corpus block says so, because
    each block only reports on itself. The equivalent at the data level is a
    pass present in four reports out of six -- which reads as perfectly healthy
    four times and is invisible twice.

    So the coverage line is the DENOMINATOR here, printed before any total: how
    many reports were summed, and how many carried each pass. A pass whose
    presence count is not the report count gets a *** banner naming the corpora
    that lack it.
    """
    p = lambda s="": out.append(s)

    p("")
    p("  BATCH POST-PASSES: %d expected in a V_eta run, over %d corpus "
      "report(s)" % (len(POST_PASSES), len(reports)))
    if not reports:
        p("      (no reports)")
        return

    def corpus_of(rep, i):
        return str(rep.get("corpus") or "report #%d" % (i + 1))

    for name, fn, rows in POST_PASSES:
        carried, missing, failed_in, noop_in = [], [], [], []
        totals = {}
        for i, r in enumerate(reports):
            rep = r.get(name)
            if not isinstance(rep, dict):
                missing.append(corpus_of(r, i))
                continue
            if rep.get("pass_failed"):
                failed_in.append(corpus_of(r, i))
                continue
            if rep.get("ran") is False:
                noop_in.append(corpus_of(r, i))
                continue
            carried.append(corpus_of(r, i))
            for key, _label in rows:
                if key in rep:
                    try:
                        totals[key] = totals.get(key, 0) + int(rep[key] or 0)
                    except (TypeError, ValueError):
                        pass

        p("")
        p("    %s  (%s)" % (name, fn))
        p("      DENOMINATOR: ran in %d of %d report(s); %d absent, %d FAILED, "
          "%d no-op" % (len(carried), len(reports), len(missing),
                        len(failed_in), len(noop_in)))
        if failed_in:
            p("      *** FAILED in: %s" % ", ".join(failed_in))
            p("      *** those corpora's documents are in PASS-1 FORM for this")
            p("      *** pass; the totals below are sums over %d corpora only."
              % len(carried))
        if missing and carried:
            # MIXED presence: the trap. Healthy in every block it appears in,
            # invisible in the ones it does not.
            p("      *** NOT PRESENT in: %s" % ", ".join(missing))
            p("      *** a pass that ran on some corpora and not others is the")
            p("      *** trap this section exists to catch -- do not read the")
            p("      *** totals below as whole-corpus figures.")
        elif missing:
            # Absent EVERYWHERE. A different fact, and the one that means the
            # pass is not wired into the harness at all (or these reports
            # predate the wiring). Saying "some corpora and not others" here
            # would be false.
            p("      *** NOT PRESENT IN ANY REPORT: %s" % ", ".join(missing))
            p("      *** either the pass is not wired into the harness, or")
            p("      *** these reports predate the wiring. It measured nothing.")
        if noop_in:
            p("      no-op (non-V_eta target or empty batch) in: %s"
              % ", ".join(noop_in))
        if not carried:
            p("      (nothing to total)")
            continue
        for key, label in rows:
            if key in totals:
                p("          %10d  %s" % (totals[key], label))
            else:
                p("          %10s  %s" % ("(absent)", label))


def digest(reports_dirs):
    """Return (lines, failed_paths). Never raises on a malformed report.

    reports_dirs is a root or a list of roots.
    """
    if isinstance(reports_dirs, str):
        reports_dirs = [reports_dirs]
    out, failed = [], []
    files, all_paths, dirs_walked = find_reports(reports_dirs)

    # RULE 5, the digest's own denominator, printed FIRST and unconditionally.
    # Run #3 printed "NO CORPUS REPORTS FOUND" and exited 0 while five
    # artifacts sat unread one directory deeper. "Found nothing" and "looked
    # in the wrong place" have to be distinguishable from the output alone.
    out.append("REPORT SEARCH: %d file(s) matching *-summary.json under %s "
               "(%d director(ies) walked, %d duplicate(s) collapsed)"
               % (len(all_paths), ", ".join(repr(d) for d in reports_dirs),
                  dirs_walked, len(all_paths) - len(files)))
    for path in files:
        out.append("  read: %s" % path)
    if not files:
        out.append("NO CORPUS REPORTS FOUND (no *-summary.json at any depth "
                   "under %s)" % ", ".join(reports_dirs))
        for d in reports_dirs:
            if not os.path.isdir(d):
                out.append("  the directory itself does not exist: %s" % d)
        return (out, [MISSING_REPORTS])

    out.append("=" * 72)
    out.append("CORPUS CENSUS DIGEST  (%d corpus report(s))" % len(files))
    out.append("=" * 72)

    parsed = []
    for path in files:
        try:
            with open(path) as fh:
                r = json.load(fh)
        except Exception as exc:
            out.append("")
            out.append("%s: UNREADABLE (%s)" % (path, exc))
            failed.append(path)
            continue
        parsed.append(r)
        try:
            render_report(r, out)
        except Exception:
            # Isolate per corpus: one malformed report must not suppress the
            # other five. Run #256 lost its two largest corpora to exactly this.
            out.append("  *** DIGEST FAILED for this corpus -- output above is partial:")
            out.append(traceback.format_exc())
            failed.append(path)

    # Isolated the same way, and for the same reason: a defect in the ROLLUP
    # must not destroy six corpora's per-corpus output. That is precisely how
    # run #256 lost its two largest reports.
    try:
        rollup(parsed, out)
    except Exception:
        out.append("")
        out.append("  *** CROSS-CORPUS ROLLUP FAILED -- per-corpus output above stands:")
        out.append(traceback.format_exc())
        failed.append("<rollup>")

    out.append("")
    out.append("=" * 72)
    return out, failed


def main(argv):
    reports_dirs = argv[1:] or ["corpus-reports"]
    lines, failed = digest(reports_dirs)
    print("\n".join(lines))
    if failed:
        print("DIGEST FAILED on %d report(s): %s" % (len(failed), ", ".join(failed)))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
