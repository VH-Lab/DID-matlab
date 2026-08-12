#!/usr/bin/env python3
"""A batch post-pass must be CALLED, PERSISTED and PRINTED -- checked in Python.

WHY THIS EXISTS BESIDE tests/+did2/+unittest/testBatchPassWiring.m
------------------------------------------------------------------
That file already gates the first of those three, and it is the better place
for it: it runs inside the harness it is describing. It has one property this
file does not, and one this file has instead.

  * it needs MATLAB. This container has none, so it is written blind and the
    first CI run is the first evidence. THIS file runs on `python3 -m pytest
    tools/ -q` in 0.1 s, which is the only gate with an opinion while the work
    is being done.
  * it checks CALLED only. `did2.convert.epochMint` was the near miss in the
    other direction -- wired into every call site, persisted into every corpus
    report, and not rendered anywhere, so the number existed and nobody could
    see it. A pass that is called but invisible is the same defect as a pass
    that is never called, arriving one layer later.

So this file gates all four legs, statically, by reading the sources as text:

    CALLED     named in all three DID-side call sites
    PERSISTED  its report key copied by writeCorpusReport
    PRINTED    its report key in runCorpusDiscovery's `expected` table
    RENDERED   each COUNTER inside the report has a row in census_digest.py

SCOPE, AND THE ONE THING OUTSIDE IT. The sweep covers BATCH POST-PASSES: the
discovery scan reads +did2/+convert for a function whose first argument is
`result`. ONE instrument is gated by name from outside that set --
`did2.validate.timeReferenceFamilies`, at the bottom of this file -- because it
arrived in exactly the state the RENDERED leg exists to prevent (called,
persisted, printed nowhere) and because it is the evidence for a team decision.
It is gated on three legs; PRINTED does not apply and the test says why rather
than skipping it. The sweep was NOT widened to all of +did2/+validate: that
would pull in five instruments at once and go red on a debt nobody has decided
to pay, and a gate whose first act is to acquire a long allow-list is not a
gate.

THE FOURTH LEG WAS ADDED 2026-08-11 AND THE FIRST THREE DID NOT COVER IT.
They gate the PASS. A pass can satisfy all three while a counter inside it is
invisible: `resolveSessionAnchors` is called, persisted and printed, and ten
counters added to its report that day would have reached the corpus artifact
and stopped there -- which is precisely the epochMint defect, one level down,
and this file's own docstring already says a measurement nobody can see is the
same as no measurement.

A STATIC SCAN IS THE POINT, not a shortcut. The alternative -- run each
harness and check -- needs MATLAB and the corpora, which is the hour the whole
exercise exists to protect.

THE ESCAPE HATCH IS THE SAME ONE. A pass whose source carries a header comment
line consisting of the token WIRING-EXEMPT, a colon and a reason is excluded
and REPORTED with its reason. (Written that way rather than shown verbatim: a
docstring that spelled the marker out would exempt this file's own examples,
and a gate that disarms itself in its own documentation is this project's
recurring failure in miniature.) Leaving a pass unwired is sometimes right --
`resolveSessionAnchors`'s author deliberately did not wire it because they
could not run it. What must not stay available is doing it SILENTLY.

DENOMINATOR: every test below prints how many passes it discovered and how many
files it read, first and unconditionally, and asserts the discovery count is
non-zero -- a broken scan reports perfect coverage.

Run: python3 -m pytest tools/test_batch_pass_wiring.py -q
"""

import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)

CONVERT_DIR = os.path.join(REPO, "src", "did", "+did2", "+convert")
UNITTEST_DIR = os.path.join(REPO, "tests", "+did2", "+unittest")

# The three DID-side harness entry points, the same three testBatchPassWiring.m
# reads. ndi.migrate.local is the fourth and lives in another repository. It is
# NOT checked here, and that is a deliberate split rather than an omission:
# since 2026-08-11 testBatchPassWiring.m ASSERTS the cross-repo divergence
# against a checked-in table, and it does so from ONE place so there is ONE
# table. A second copy of that table here would be a second thing to keep in
# agreement, and this file exists to be the gate that runs without MATLAB --
# not the gate that runs without NDI-matlab.
CALL_SITES = {
    "runCorpusDiscovery": os.path.join(UNITTEST_DIR, "+helpers", "runCorpusDiscovery.m"),
    "testCorpusPRED": os.path.join(UNITTEST_DIR, "testCorpusPRED.m"),
    "testFixtureCorpus": os.path.join(UNITTEST_DIR, "testFixtureCorpus.m"),
}

REPORT_WRITER = os.path.join(UNITTEST_DIR, "+helpers", "writeCorpusReport.m")
DISCOVERY = CALL_SITES["runCorpusDiscovery"]

# A pass's report key is the name it attaches to the result struct. It is not
# derivable from the function name (epochMint -> epoch_mint,
# resolveSessionAnchors -> session_anchor_fold), so it is read out of the source
# rather than guessed: every pass assigns `result.<key> = report` before it does
# anything else, which is Operating Rule 5 written as code.
RESULT_ASSIGN = re.compile(r"^\s*result\.([A-Za-z_]\w*)\s*=\s*report\s*;", re.M)

# `function <out> = <name>(result, ...)` -- a batch post-pass is a function whose
# first argument is the struct v1_to_v2 returns.
SIGNATURE = re.compile(r"^function\s+\S.*?=\s*(\w+)\s*\(\s*result\s*[,)]")

EXEMPT = re.compile(r"^%\s*WIRING-EXEMPT:\s*(\S[^\n\r]*)$", re.M)

# ---------------------------------------------------------------------------
# THE KNOWN GAP, NAMED. NOT AN EXEMPTION -- A DEBT WITH A DIRECTION.
# ---------------------------------------------------------------------------
# A pass listed here attaches NO report at all, so there is nothing for the
# PERSISTED and PRINTED legs to check. Listing it is not skipping it, and the
# list is gated BOTH WAYS:
#
#   * a pass NOT on this list must declare a report key      (it cannot grow
#                                                             without a decision)
#   * a pass ON this list that HAS acquired one must be removed from it
#                                                            (it cannot go stale)
#
# A hand-kept allow-list that only ever gets longer is the thing that would have
# gone stale the day resolveSessionAnchors was added. This one can only shrink.
#
# IT IS NOW EMPTY, AND WHAT CAME OFF IT CAME OFF BY BEING FIXED (2026-08-11):
#
#   resolveDeferredBaths     -> `deferred_bath_resolution`
#   resolveDatasetEntities   -> `dataset_entity_resolution`
#
# Both MUTATE the corpus -- the first moves documents from `quarantine` into
# `migrated`, the second DELETES them -- and neither reported how many it
# inspected, resolved or dropped. "Ran and found nothing" and "ran and silently
# failed to resolve anything" were the same reading of every corpus run,
# 31522068566 (green) included. The debt list shrank to nothing; it did not
# get a longer set of excuses.
NO_REPORT_YET = {}


# ---------------------------------------------------------------------------
# THE RENDERED LEG'S KNOWN DEBT. SAME CONTRACT AS NO_REPORT_YET: SHRINK ONLY.
# ---------------------------------------------------------------------------
# Counters that a pass declares and census_digest.py does not print. Listed so
# a NEW one cannot appear silently, and gated both ways so this list cannot
# outlive the gap it describes.
#
# WHAT IS ON IT AND WHY, because a list of names with no reasons is a list
# nobody will ever be able to shorten:
#
#   epoch_mint.strings_by_source / .epoch_index
#       NOT COUNTERS. Both are struct ARRAYS -- a per-source table and the
#       (session_id, local_identifier, epoch_document_id) index -- so there is
#       no number for a row to print. Rendering them needs a table renderer,
#       which is a different change with a different owner.
#   openminds_citations.withheld_reasons
#       NOT A COUNTER either, and for the same reason: it is a CELL ARRAY of
#       one reason string per withheld component, so there is no number for a
#       row to print and the cross-corpus rollup could not sum it. It is not
#       invisible -- census_digest's openminds_citations reading block prints
#       every reason verbatim under the *** WITHHELD banner -- but it is not a
#       ROW, and this list is the register of what the row sweep does not
#       cover. `components_withheld` is the number.
#
# WHAT CAME OFF THIS LIST, 2026-08-11, and it came off by being rendered rather
# than by being reclassified:
#   epoch_mint.documents_with_epoch_id / .strings_declined /
#   .strings_declined_distinct           -> rows in POST_PASSES
#   valid_interval_decompose.anchor_session_from_timeref / _from_document /
#   .method_from_app_block / .method_from_class_default   -> rows in POST_PASSES
# Seven real counters that reached the artifact and stopped there. The debt
# list shrank; it did not get a longer set of excuses.
NOT_RENDERED_YET = {
    "epoch_mint": {
        "strings_by_source", "epoch_index",
        # epoch_index_report (added 2026-08-12 with the 1 -> N arming rebuild)
        #     NOT A COUNTER. It is did2.convert.epochIndex's OWN report struct,
        #     carried out whole so the index's denominators survive to the
        #     artifact; there is no scalar for a row to print and no cross-corpus
        #     rollup could sum it. The numbers a reader wants FROM it are already
        #     rendered as epoch_mint rows in their own right -- the arming block
        #     added in the same change -- so this is a nested duplicate of
        #     printed facts, not a missing one. Same shape and same reason as
        #     `epoch_index` above.
        "epoch_index_report",
    },
    "openminds_citations": {
        "withheld_reasons",
    },
    # deferred_bath_resolution.unexpected_error_reasons
    #     NOT A COUNTER, same shape and same reason as withheld_reasons above:
    #     a CELL ARRAY holding one string per DISTINCT error identifier the
    #     per-bath handler met, so there is no number for a row to print and no
    #     cross-corpus rollup could sum it. `refused_unexpected_error` is the
    #     number. Listed ahead of the digest entry landing so the row sweep
    #     does not fail the first person who writes one.
    "deferred_bath_resolution": {
        "unexpected_error_reasons",
    },
}

# Structural keys every pass carries that are NOT measurements: `ran` says the
# pass executed and is rendered as its own LINE rather than as a row, and
# `pass` is the guard's identity stamp from runBatchPass.
NON_COUNTER_KEYS = {"ran", "pass", "pass_failed", "pass_failed_identifier"}


def _read(path):
    with open(path, "r", encoding="utf-8") as handle:
        return handle.read()


def struct_field_names(text, assign="report = struct("):
    """Top-level field NAMES of a `report = struct(...)` initializer.

    A DEPTH-AWARE SCAN, NOT A REGEX, and the difference is load-bearing: a
    regex over quoted strings inside the call reports epochMint's nested
    `struct('source', {}, 'documents', {}, ...)` keys as if they were report
    fields, which would put four names on the debt list that are not counters
    and are not missing. It tracks (), {}, [], MATLAB char literals (with ''
    escaping) and `%` comments, splits the outermost argument list on commas at
    depth 1, and takes the even-indexed items -- name, value, name, value.

    Returns None when the file has no such initializer, so "this pass declares
    no report" stays distinguishable from "it declares an empty one".
    """
    i = text.find(assign)
    if i < 0:
        return None
    j = text.index("(", i)
    depth, items, cur, k, n = 0, [], [], j, len(text)
    while k < n:
        ch = text[k]
        if ch == "'":
            k2 = k + 1
            while k2 < n:
                if text[k2] == "'":
                    if k2 + 1 < n and text[k2 + 1] == "'":
                        k2 += 2
                        continue
                    break
                k2 += 1
            cur.append(text[k:k2 + 1])
            k = k2 + 1
            continue
        if ch == "%":
            while k < n and text[k] != "\n":
                k += 1
            continue
        if ch in "({[":
            depth += 1
            if depth == 1 and ch == "(":
                k += 1
                continue
            cur.append(ch)
            k += 1
            continue
        if ch in ")}]":
            depth -= 1
            if depth == 0:
                items.append("".join(cur))
                break
            cur.append(ch)
            k += 1
            continue
        if ch == "," and depth == 1:
            items.append("".join(cur))
            cur = []
            k += 1
            continue
        cur.append(ch)
        k += 1
    names = []
    for idx, item in enumerate(items):
        if idx % 2:
            continue
        s = item.replace("...", "").strip()
        if len(s) >= 2 and s[0] == "'" and s[-1] == "'":
            names.append(s[1:-1])
    return names


def discover():
    """Every batch post-pass in +did2/+convert: (name, report_key, exempt_reason)."""
    assert os.path.isdir(CONVERT_DIR), (
        "scan root %s does not exist -- this is 'did not look', not "
        "'found nothing'" % CONVERT_DIR
    )
    found, exempt = [], []
    files = sorted(f for f in os.listdir(CONVERT_DIR) if f.endswith(".m"))
    for name in files:
        text = _read(os.path.join(CONVERT_DIR, name))
        first = text.split("\n", 1)[0].strip()
        match = SIGNATURE.match(first)
        if not match:
            continue
        keys = RESULT_ASSIGN.findall(text)
        why = EXEMPT.search(text)
        entry = (match.group(1), keys[0] if keys else None)
        if why:
            exempt.append((entry[0], why.group(1).strip()))
        else:
            found.append(entry)
    return sorted(found), sorted(exempt), len(files)


def _banner():
    passes, exempt, n_files = discover()
    print(
        "\n--- batch-pass wiring (python): %d pass(es) in %d .m file(s) "
        "-- %d gated, %d exempt ---" % (len(passes) + len(exempt), n_files,
                                        len(passes), len(exempt))
    )
    for name, reason in exempt:
        print("  %-30s EXEMPT -- reason: %s" % (name, reason))
    return passes, exempt


def test_the_scan_finds_passes_at_all():
    """A broken scan reports perfect coverage. Assert the denominator first."""
    passes, exempt = _banner()
    assert len(passes) + len(exempt) >= 4, (
        "fewer than 4 batch post-passes discovered in %s -- the signature scan "
        "is broken, and a broken scan makes every test below vacuously true"
        % CONVERT_DIR
    )


def test_every_pass_declares_a_report_key():
    """Operating Rule 5: a pass with no report has measured nothing.

    Read out of the source (`result.<key> = report;`) rather than derived from
    the function name -- epochMint's key is `epoch_mint` and
    resolveSessionAnchors's is `session_anchor_fold`, so a naming rule would be
    a fiction.
    """
    passes, _ = _banner()
    for name, key in passes:
        if key:
            print("  %-30s report key: %s" % (name, key))
        else:
            print("  %-30s NO REPORT -- known gap: %s"
                  % (name, NO_REPORT_YET.get(name, "UNRECORDED")))
    missing = [name for name, key in passes if not key and name not in NO_REPORT_YET]
    assert not missing, (
        "NEW batch post-pass(es) with no `result.<key> = report;` assignment: "
        "%s. A pass that attaches no report cannot be persisted or printed, and "
        "a run that did not measure is not a run that found nothing."
        % ", ".join(missing)
    )
    # THE LIST MUST SHRINK, NEVER GO STALE. A pass that has since acquired a
    # report key but is still listed as a gap would make the gap look larger
    # than it is -- the same defect as a stale sign-off header, in the direction
    # that understates progress.
    healed = [name for name, key in passes if key and name in NO_REPORT_YET]
    assert not healed, (
        "%s now declare(s) a report key and must be removed from NO_REPORT_YET "
        "-- a known-gap list that outlives the gap is a stale claim about our "
        "own instruments." % ", ".join(healed)
    )


def test_every_pass_is_called_from_every_did_side_call_site():
    """CALLED. A pass wired into some sites and not others is worse than one
    wired nowhere: the corpus goes green while another path does something else.
    """
    passes, _ = _banner()
    print("  %d call site(s) read: %s" % (len(CALL_SITES), ", ".join(sorted(CALL_SITES))))
    texts = {site: _read(path) for site, path in CALL_SITES.items()}
    missing = []
    for name, _key in passes:
        # The qualified name followed by an opening parenthesis, so a mention in
        # a comment ("see also did2.convert.epochMint") does NOT count as a call.
        call = re.compile(r"did2\.convert\." + re.escape(name) + r"\s*\(")
        row = "  %-30s" % name
        for site in sorted(CALL_SITES):
            if call.search(texts[site]):
                row += " %-18s" % "CALLED"
            else:
                row += " %-18s" % "-- NOT CALLED --"
                missing.append("%s is not called from %s" % (name, site))
        print(row)
    assert not missing, "\n  ".join(["unwired batch post-pass(es):"] + missing)


def test_every_pass_report_is_persisted_into_the_corpus_report():
    """PERSISTED. The corpus report is the artifact a decision gets read out of
    weeks later; a counter that lives only in a log is a counter nobody has.
    """
    passes, _ = _banner()
    text = _read(REPORT_WRITER)
    print("  read: %s" % REPORT_WRITER)
    missing = []
    for name, key in passes:
        if not key:
            continue  # already failed in its own test; do not double-report
        if re.search(r"report\.%s\s*=\s*result\.%s\s*;" % (re.escape(key), re.escape(key)), text):
            print("  %-30s PERSISTED as `%s`" % (name, key))
        else:
            print("  %-30s -- NOT PERSISTED -- (`%s`)" % (name, key))
            # HAND OVER THE BLOCK, DO NOT JUST NAME THE SIN.
            #
            # This check fired twice in one hour on 2026-08-11, for two
            # different passes written by two different people, and both times
            # the cost was a full CI round trip spent discovering that
            # writeCorpusReport.m exists and what its entries look like. The
            # check was right both times; the MESSAGE was the expensive part.
            #
            # The enumeration in writeCorpusReport.m is deliberately NOT a
            # generic copy-everything loop: each entry carries a written reason
            # for why that report belongs in the record, and several of those
            # comments are the only place a reader is told how to interpret a
            # zero. Replacing them with a loop would trade seven pieces of
            # documentation for two round trips. So the enumeration stays, and
            # instead the failure prints exactly what to add -- leaving the
            # author only the part a machine cannot write, which is the reason.
            missing.append(
                "%s's report key `%s` is not copied by writeCorpusReport.\n"
                "      ADD TO %s, beside its siblings:\n\n"
                "          %% `%s` (<who decided it, when>). PERSISTED BECAUSE\n"
                "          %% <why these counters belong in the record -- and, if a\n"
                "          %% zero here is ambiguous, WHICH denominator tells the\n"
                "          %% two readings apart. That sentence is the whole point\n"
                "          %% of this block; the two lines below are mechanical.>\n"
                "          if isfield(result, '%s')\n"
                "              report.%s = result.%s;\n"
                "          end\n"
                % (name, key, REPORT_WRITER, key, key, key, key))
    assert not missing, "\n  ".join(["unpersisted batch post-pass report(s):"] + missing)


def test_every_pass_is_printed_by_the_discovery_run():
    """PRINTED. runCorpusDiscovery's `expected` table is the list that makes
    "the pass ran and changed nothing" and "the pass was never wired into this
    call site" different LINES rather than the same silence. A pass absent from
    it is invisible in the log of every corpus run -- which is exactly how
    epochMint's numbers existed while nobody could see them.
    """
    passes, _ = _banner()
    text = _read(DISCOVERY)
    print("  read: %s" % DISCOVERY)
    # The table is `'<key>', 'did2.convert.<name>'; ...` inside printBatchPasses.
    missing = []
    for name, key in passes:
        if not key:
            continue
        row = re.compile(r"'%s'\s*,\s*'did2\.convert\.%s'" % (re.escape(key), re.escape(name)))
        if row.search(text):
            print("  %-30s PRINTED as `%s`" % (name, key))
        else:
            print("  %-30s -- NOT PRINTED -- (`%s`)" % (name, key))
            missing.append("%s (`%s`) is missing from runCorpusDiscovery's "
                           "`expected` table" % (name, key))
    assert not missing, "\n  ".join(["unprinted batch post-pass(es):"] + missing)


def _digest_rows():
    """census_digest.POST_PASSES as {report key: set(rendered counter keys)}."""
    import importlib.util

    path = os.path.join(HERE, "census_digest.py")
    spec = importlib.util.spec_from_file_location("_census_digest_wiring", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return dict((name, set(key for key, _label in rows))
                for name, _fn, rows in module.POST_PASSES)


def test_every_counter_a_rendered_pass_declares_reaches_the_digest():
    """RENDERED. A counter in the artifact and not on the screen is write-only.

    THE DENOMINATOR IS PRINTED PER PASS -- how many fields its initializer
    declares -- because a scan that failed to parse a struct would report
    perfect coverage, which is this repository's most-repeated failure and the
    reason `struct_field_names` returns None rather than [] when it finds
    nothing.

    SCOPE, STATED SO THE ZERO IS READABLE: only passes that census_digest.py
    renders AT ALL are checked.

    THIS PARAGRAPH USED TO NAME THREE PASSES -- lawn_plate_subjects,
    openminds_citations, response_parameters_fold -- as having no POST_PASSES
    entry, so that every counter they declared was unrendered. THAT IS STALE:
    all three now have one, and this test's own output says so, printing
    "9 pass(es), 9 rendered by census_digest". Verified against the committed
    digest rather than a working copy:

        $ git show a45e1ad:tools/census_digest.py | python3 -c "...POST_PASSES..."
        lawn_plate_subjects     -> PRESENT
        openminds_citations     -> PRESENT
        response_parameters_fold-> PRESENT

    The whole-pass gap this scope note was written to keep visible is now
    CLOSED and, more to the point, GATED: census_digest.pass_census_gate exits
    non-zero on a pass measured by nothing, so the condition can no longer sit
    in a docstring waiting to be read. The scope sentence above still stands on
    its own -- a pass the digest does not render is out of reach of this leg --
    it simply has no instances today. A zero here is now a measured zero.
    """
    passes, _exempt, _n_files = discover()
    rendered = _digest_rows()
    print("\n--- RENDERED leg: %d pass(es), %d rendered by census_digest ---"
          % (len(passes), len(rendered)))

    unrendered_passes = []
    missing, healed = [], []
    for name, key in passes:
        if not key:
            continue
        text = _read(os.path.join(CONVERT_DIR, name + ".m"))
        fields = struct_field_names(text)
        if fields is None:
            print("  %-30s no `report = struct(` initializer -- NOT SCANNED"
                  % name)
            continue
        counters = [f for f in fields if f not in NON_COUNTER_KEYS]
        if key not in rendered:
            unrendered_passes.append((name, key, len(counters)))
            print("  %-30s %3d counter(s), NO POST_PASSES ENTRY -- the whole "
                  "pass is unrendered" % (name, len(counters)))
            continue
        known = NOT_RENDERED_YET.get(key, set())
        gap = [f for f in counters if f not in rendered[key]]
        print("  %-30s %3d counter(s) declared, %d rendered, %d known gap(s)"
              % (name, len(counters), len(rendered[key] & set(counters)),
                 len(known)))
        for f in gap:
            if f not in known:
                missing.append("%s.%s" % (key, f))
        for f in known:
            if f in rendered[key]:
                healed.append("%s.%s" % (key, f))
            elif f not in counters:
                healed.append("%s.%s (no longer declared)" % (key, f))

    # The whole-pass gap is REPORTED, not asserted on. Adding three POST_PASSES
    # entries is a digest change with its own reading instructions per block,
    # and quietly failing this test into existence would get them written badly.
    for name, key, n in unrendered_passes:
        print("  NOTE: %s (`%s`) renders none of its %d counter(s)"
              % (name, key, n))

    assert not missing, (
        "counter(s) declared by a batch post-pass and rendered NOWHERE in "
        "tools/census_digest.py: %s.\n"
        "  A counter that reaches the corpus artifact and not the digest is "
        "write-only -- exactly the epochMint defect. ADD A ROW to that pass's "
        "entry in POST_PASSES, or, if the number is genuinely not worth "
        "printing, add it to NOT_RENDERED_YET in this file WITH THE REASON."
        % ", ".join(missing)
    )
    # SHRINK ONLY, same contract as NO_REPORT_YET above: a debt list that
    # outlives its debt is a stale claim about our own instruments, in the
    # direction that understates progress.
    assert not healed, (
        "%s is/are now rendered (or no longer declared) and must be removed "
        "from NOT_RENDERED_YET." % ", ".join(healed)
    )


def test_the_session_anchor_extent_counters_are_rendered():
    """The bounded-extent group, named rather than left to the sweep above.

    The generic test passes just as well if these counters are DELETED -- a
    scan over what exists cannot notice something that stopped existing, which
    is the same reason test_the_response_parameters_fold_is_wired exists. They
    are the instrument for a defect that discarded 20,411 encounter windows
    while every other counter in that report read clean, so removing them is a
    decision that should have to argue with a test.
    """
    rendered = _digest_rows()
    assert "session_anchor_fold" in rendered, (
        "session_anchor_fold has no POST_PASSES entry at all"
    )
    required = {
        "bounded_extents_examined": "THE DENOMINATOR -- without it every "
                                    "extent counter's 0 is unreadable",
        "bounded_with_start_field": "was a window there to lose",
        "bounded_with_end_field": "was a window there to lose",
        "bounded_window_carried": "did it survive",
        "bounded_start_only_carried": "the half-window, kept apart from a "
                                      "window that was never there",
        "bounded_no_window_stated": "nothing to lose -- NOT a loss",
        "refused_unreadable_extent_unit": "the unit the fold will not guess",
        "refused_malformed_extent": "a shape it does not recognise",
        "refused_extent_without_start": "an end it cannot anchor",
    }
    gone = sorted(k for k in required if k not in rendered["session_anchor_fold"])
    print("\n--- session_anchor_fold extent rows: %d required, %d missing ---"
          % (len(required), len(gone)))
    assert not gone, "\n  ".join(
        ["bounded-extent row(s) missing from census_digest.POST_PASSES:"]
        + ["%s -- %s" % (k, required[k]) for k in gone])


def test_the_response_parameters_fold_is_wired():
    """#61's resolver, named explicitly rather than left to the sweep above.

    The generic tests would keep passing if this pass were deleted outright --
    a scan over what EXISTS cannot notice something that stopped existing. This
    one names it, so removing the file fails a test that says why.
    """
    passes, _exempt, _n_files = discover()
    names = [name for name, _ in passes]
    assert "resolveResponseParameters" in names, (
        "did2.convert.resolveResponseParameters is gone from %s. It is the "
        "RESOLVER half of the signed stimulus-response fold (#61, TEAM-SIGN-OFF "
        "[stimulus response] 2026-08-08): the five run knobs move inline onto "
        "the harmonic_component_calculation leaf and the method_parameters_id "
        "edge is dropped. Discovered: %s" % (CONVERT_DIR, ", ".join(names))
    )
    key = dict(passes)["resolveResponseParameters"]
    assert key == "response_parameters_fold", (
        "the pass's report key changed to %r; the corpus report, the discovery "
        "print table and tools/census_digest.py all key on the old name" % key
    )



# ---------------------------------------------------------------------------
# THE FOURTH LEG, APPLIED TO A +validate INSTRUMENT RATHER THAN A POST-PASS
# ---------------------------------------------------------------------------
# `did2.validate.timeReferenceFamilies` is NOT a batch post-pass and the sweep
# above cannot see it: `discover()` scans +did2/+convert for a function whose
# FIRST ARGUMENT IS `result`, and this one lives in +did2/+validate and takes
# `docs`. So it is checked by name, here, in the same spirit as the
# session-anchor extent rows -- and the reason is that it arrived with exactly
# the defect the RENDERED leg exists to stop: called from v1_to_v2, persisted
# by writeCorpusReport, and printed NOWHERE, so 26 fields of evidence for a
# team decision reached the corpus artifact and stopped there.
#
# WHY ONE NAMED TEST AND NOT A SWEEP OVER +did2/+validate. A sweep would pull
# in silentLoss, sourceCensus, fileList, epochStrings and references at once,
# several of which render some counters and not others, and it would go red on
# a debt nobody has decided to pay. That is a bigger change with a different
# owner. Widening the scan without deciding what to do about what it finds is
# how a gate ends up with a long allow-list; this is one instrument, gated
# whole.
#
# THE `PRINTED` LEG DOES NOT APPLY AND IS NAMED RATHER THAN SKIPPED.
# runCorpusDiscovery's `expected` table is the BATCH POST-PASS table -- it
# prints one line per pass so an unwired pass is visible. A validate instrument
# has no entry there and never had one, and adding it is a MATLAB change this
# checkout cannot execute. So this instrument is gated on three legs (CALLED,
# PERSISTED, RENDERED) and the fourth is recorded as not applicable.
TRF_SOURCE = os.path.join(REPO, "src", "did", "+did2", "+validate",
                          "timeReferenceFamilies.m")
TRF_CALL_SITE = os.path.join(CONVERT_DIR, "v1_to_v2.m")
TRF_REPORT_KEY = "time_reference_families"

# The fields the instrument declares that are NOT plain counters, and HOW the
# digest renders each. A field on this list is asserted to appear in
# census_digest.py by name; a field on neither this list nor a row list fails,
# so a new field cannot appear silently and this list cannot outlive its
# entries.
TRF_STRUCTURAL = {
    "docs_inspected": "printed by `headline`, which the renderer emits "
                      "verbatim and first",
    "schema_cache_available": "a NOT-MEASURED condition in "
                              "time_reference_families() -- 'did not look'",
    "count_distribution": "its own table, per corpus and summed in the rollup",
    "shape": "the shape table, UNITED BY shape_key in the rollup",
    "shape_denominator": "its own row list (TRF_SHAPE_DENOMINATOR)",
    "emitter": "the emitter table, united on (shape, class, name, anchors)",
    "emitter_denominator": "printed on the EMITTERS line and checked as a "
                           "partition of multi_slots_examined",
    "reference_census_vacuous": "verdict one of two, rendered BEFORE any count",
    "reference_census_vacuous_reason": "rendered verbatim under that verdict",
    "shape_census_vacuous": "verdict two of two -- the SAME flag for two "
                            "opposite findings, split by trf_shape_regime",
    "shape_census_vacuous_reason": "rendered verbatim under that verdict",
    "headline": "emitted first and unconditionally",
}


def _trf_nested_fields(text, name):
    """Field names of a `'<name>', struct(...)` initializer nested in a report."""
    match = re.search(r"'%s',\s*struct\(" % re.escape(name), text)
    if not match:
        return None
    return struct_field_names(text, assign=match.group(0))


def test_the_time_reference_family_instrument_is_wired_end_to_end():
    """CALLED, PERSISTED, RENDERED -- for the #52 evidence instrument.

    DENOMINATOR FIRST: how many fields its report declares, how many are rows,
    how many are structural, how many are unaccounted for. A scan that failed
    to parse the initializer would otherwise report perfect coverage, which is
    this repository's most-repeated failure.
    """
    import importlib.util

    assert os.path.isfile(TRF_SOURCE), (
        "%s does not exist -- this is 'did not look', not 'found nothing'"
        % TRF_SOURCE
    )
    text = _read(TRF_SOURCE)
    fields = struct_field_names(text, assign="r = struct(")
    assert fields, (
        "no `r = struct(` initializer found in %s -- the scan is broken and "
        "every assertion below would be vacuously true" % TRF_SOURCE
    )
    nested = _trf_nested_fields(text, "shape_denominator")
    assert nested, "no nested `shape_denominator` initializer found"

    spec = importlib.util.spec_from_file_location(
        "_census_digest_trf", os.path.join(HERE, "census_digest.py"))
    digest_mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(digest_mod)
    digest_src = _read(os.path.join(HERE, "census_digest.py"))
    rows = set(k for k, _l in digest_mod.TRF_DENOMINATOR)
    shape_rows = set(k for k, _l in digest_mod.TRF_SHAPE_DENOMINATOR)

    print("\n--- #52 instrument wiring: %d report field(s), %d nested "
          "shape_denominator field(s) ---" % (len(fields), len(nested)))

    # CALLED.
    call = _read(TRF_CALL_SITE)
    assert "did2.validate.timeReferenceFamilies(" in call, (
        "timeReferenceFamilies is not called from %s. An instrument nobody "
        "runs measures nothing." % TRF_CALL_SITE
    )
    assert "result.%s" % TRF_REPORT_KEY in call, (
        "v1_to_v2 does not attach the report as `result.%s`; the persist and "
        "render legs both key on that name" % TRF_REPORT_KEY
    )
    print("  CALLED     v1_to_v2.m -> result.%s" % TRF_REPORT_KEY)

    # PERSISTED.
    writer = _read(REPORT_WRITER)
    assert "report.%s" % TRF_REPORT_KEY in writer, (
        "writeCorpusReport does not copy `%s` into the corpus report, so the "
        "block never reaches the artifact" % TRF_REPORT_KEY
    )
    print("  PERSISTED  writeCorpusReport.m -> report.%s" % TRF_REPORT_KEY)

    # RENDERED -- every declared field, as a row or structurally.
    as_rows, structural, missing = [], [], []
    for f in fields:
        if f in rows:
            as_rows.append(f)
        elif f in TRF_STRUCTURAL:
            if "'%s'" % f in digest_src or '"%s"' % f in digest_src:
                structural.append(f)
            else:
                missing.append("%s (listed as structural, and census_digest.py "
                               "does not name it)" % f)
        else:
            missing.append(f)
    for f in nested:
        if f not in shape_rows:
            missing.append("shape_denominator.%s" % f)
    print("  RENDERED   %d as row(s), %d structural, %d nested shape row(s), "
          "%d unaccounted" % (len(as_rows), len(structural), len(nested),
                              len(missing)))

    assert not missing, (
        "field(s) declared by did2.validate.timeReferenceFamilies and rendered "
        "NOWHERE in tools/census_digest.py: %s.\n"
        "  A counter that reaches the corpus artifact and not the digest is "
        "write-only -- exactly the epochMint defect, and exactly the state "
        "this instrument shipped in. ADD A ROW to TRF_DENOMINATOR or "
        "TRF_SHAPE_DENOMINATOR, or add the field to TRF_STRUCTURAL in this "
        "file WITH the reason it is not a row." % ", ".join(missing)
    )

    # SHRINK-ONLY, the same contract as NO_REPORT_YET and NOT_RENDERED_YET: a
    # structural entry for a field the instrument no longer declares is a stale
    # claim about our own instruments.
    stale = [f for f in TRF_STRUCTURAL if f not in fields]
    assert not stale, (
        "%s is/are no longer declared by the instrument and must be removed "
        "from TRF_STRUCTURAL." % ", ".join(stale)
    )

    # And the two vacuity verdicts specifically, because they are the reading
    # the whole block turns on and a sweep over field NAMES would pass just as
    # well if the renderer printed one of them twice.
    for flag in ("reference_census_vacuous", "shape_census_vacuous"):
        assert flag in fields, "%s is no longer declared" % flag
    assert "trf_shape_regime" in digest_src, (
        "census_digest.py no longer derives the shape-census regime from the "
        "counters. `shape_census_vacuous` is set for TWO OPPOSITE findings -- "
        "'no statement carries a second reference' (a result) and 'every "
        "multi-reference statement had a referent outside the batch' (an "
        "occupied regime nobody measured). Without the derivation the flag "
        "alone cannot tell them apart."
    )

# ---------------------------------------------------------------------------
# `did2.validate.epochStringRetention` -- the SECOND validate instrument gated
# by name, and gated for the same reason as timeReferenceFamilies above: the
# sweep cannot see it (it lives in +did2/+validate and takes
# (v1Bodies, migratedBodies), not `result`), and it arrived in a state the
# RENDERED leg exists to stop -- worse than write-only, it was CALL-SITE-FREE.
# Measured at 32166b8, before the wiring below:
#
#     8 executable call sites, all in tests
#       7  tests/+did2/+unittest/testEpochStrings.m
#       1  tests/+did2/+unittest/testStimulusResponseEpochGuard.m
#       0  src/          (4 mentions, every one of them a comment)
#       0  tools/        (0 mentions of any kind)
#
# A validator that has never run on real data is a validator whose value nobody
# knows.
#
# THREE LEGS ARE ASSERTED, THE FOURTH IS REPORTED. CALLED / PERSISTED / PRINTED
# are gated. RENDERED is NOT, and that is deliberate rather than an oversight:
# tools/census_digest.py is owned by another change in flight and adding rows to
# it from here would collide. The render status of every field is PRINTED, so
# the debt is a number in this test's output rather than a silence -- and when
# the digest block lands, this test does not need editing to notice.
ESR_SOURCE = os.path.join(REPO, "src", "did", "+did2", "+validate",
                          "epochStringRetention.m")
ESR_REPORT_KEY = "epoch_string_retention"
# BOTH corpus-report producers. runCorpusDiscovery drives five of the six
# corpora; testCorpusPRED is the sixth and is the corpus that was invisible to
# the census once already (run #3, 31315510527 -- six jobs, five artifacts).
# testFixtureCorpus is NOT on this list and that is not an omission: it writes
# no corpus report, so there is nothing for the PERSISTED leg to reach.
ESR_CALL_SITES = {
    "runCorpusDiscovery": CALL_SITES["runCorpusDiscovery"],
    "testCorpusPRED": CALL_SITES["testCorpusPRED"],
}
# Report fields that are not plain counters, with HOW each is rendered by the
# discovery printout. A field on neither this list nor the counter set fails, so
# a new field cannot appear silently.
ESR_STRUCTURAL = {
    "ran": "printed as its own DID NOT RUN line -- 'did not run' and 'ran and "
           "found nothing' must not print the same",
    "v1_by_source": "a table, printed row per row",
    "v1_by_class": "THE 0-of-0 TABLE, printed row per row",
    "dropped_by_v1_class": "a struct keyed by mangled class name, so it has no "
                           "printable row; v1_by_class is the human-readable "
                           "form of the same fact and the printout LOCKS the "
                           "two derivations together instead of printing both",
    "dropped_detail": "a capped example list, printed as `e.g.` lines",
}


def test_the_epoch_string_retention_instrument_is_wired_end_to_end():
    """CALLED from both corpus report producers, PERSISTED, PRINTED.

    DENOMINATOR FIRST: how many fields the report declares, how many are
    printed as counters, how many structurally, how many unaccounted for. A
    scan that failed to parse the initializer would otherwise report perfect
    coverage, which is this repository's most-repeated failure.
    """
    assert os.path.isfile(ESR_SOURCE), (
        "%s does not exist -- this is 'did not look', not 'found nothing'"
        % ESR_SOURCE
    )
    text = _read(ESR_SOURCE)
    fields = struct_field_names(text, assign="report = struct(")
    assert fields, (
        "no `report = struct(` initializer found in %s -- the scan is broken "
        "and every assertion below would be vacuously true" % ESR_SOURCE
    )
    print("\n--- epoch-string retention wiring: %d report field(s) ---"
          % len(fields))

    # CALLED -- from every producer of a corpus report.
    for label, path in sorted(ESR_CALL_SITES.items()):
        src = _read(path)
        assert "did2.validate.epochStringRetention(" in src, (
            "epochStringRetention is not called from %s. An instrument nobody "
            "runs measures nothing -- which is the state it shipped in." % path
        )
        assert "result.%s" % ESR_REPORT_KEY in src, (
            "%s does not attach the report as `result.%s`; the persist and "
            "print legs both key on that name" % (label, ESR_REPORT_KEY)
        )
        print("  CALLED     %s -> result.%s" % (label, ESR_REPORT_KEY))

    # CALLED, AND SITED. The placement is the measurement: after every batch
    # post-pass, so `retained_as_epoch_document` is a real number rather than
    # the structural 0 a pass-1 siting would produce (the silentLoss tautology,
    # v1_to_v2.m:382). Checked by ORDER in the file, because a comment saying
    # so is not the same as the call being there.
    disc = _read(ESR_CALL_SITES["runCorpusDiscovery"])
    mint_at = disc.find("did2.convert.epochMint")
    call_at = disc.find("did2.validate.epochStringRetention(")
    write_at = disc.find("did2.unittest.helpers.writeCorpusReport(")
    assert -1 < mint_at < call_at < write_at, (
        "epochStringRetention must be called AFTER did2.convert.epochMint and "
        "BEFORE writeCorpusReport. Called before the mint, "
        "`retained_as_epoch_document` is 0 by construction and the instrument "
        "reproduces the silentLoss tautology it was written to avoid; called "
        "after the write, the block never reaches the artifact. "
        "(epochMint at %d, retention at %d, writeCorpusReport at %d)"
        % (mint_at, call_at, write_at)
    )
    print("  SITED      after epochMint, before writeCorpusReport")

    # PERSISTED.
    writer = _read(REPORT_WRITER)
    assert "report.%s" % ESR_REPORT_KEY in writer, (
        "writeCorpusReport does not copy `%s` into the corpus report, so the "
        "block never reaches the artifact" % ESR_REPORT_KEY
    )
    print("  PERSISTED  writeCorpusReport.m -> report.%s" % ESR_REPORT_KEY)

    # PRINTED -- every declared field, as a counter or structurally.
    printed, structural, missing = [], [], []
    for f in fields:
        named = ("r.%s" % f) in disc or ("'%s'" % f) in disc
        if f in ESR_STRUCTURAL:
            if named:
                structural.append(f)
            else:
                missing.append("%s (listed as structural, and "
                               "runCorpusDiscovery.m does not name it)" % f)
        elif named:
            printed.append(f)
        else:
            missing.append(f)
    print("  PRINTED    %d counter(s), %d structural, %d unaccounted"
          % (len(printed), len(structural), len(missing)))
    assert not missing, (
        "field(s) declared by did2.validate.epochStringRetention and printed "
        "NOWHERE in runCorpusDiscovery.m: %s.\n"
        "  A counter that reaches the corpus artifact and not the log is "
        "write-only -- the epochMint defect. Print it, or add it to "
        "ESR_STRUCTURAL in this file WITH the reason it is not a counter."
        % ", ".join(missing)
    )

    # SHRINK-ONLY, same contract as TRF_STRUCTURAL: a structural entry for a
    # field the instrument no longer declares is a stale claim about our own
    # instruments.
    stale = [f for f in ESR_STRUCTURAL if f not in fields]
    assert not stale, (
        "%s is/are no longer declared by the instrument and must be removed "
        "from ESR_STRUCTURAL." % ", ".join(stale)
    )

    # THE DENOMINATOR FIELDS SPECIFICALLY. A sweep over field NAMES would pass
    # just as well if the printout emitted the drop count and no denominator,
    # which is the exact defect Operating Rule 5 exists for.
    for required in ("v1_documents_inspected", "v1_pairs",
                     "v1_classes_inspected", "v1_classes_with_string",
                     "v1_documents_with_string", "v1_by_class"):
        assert required in fields, (
            "%s is no longer declared by the instrument; it is a DENOMINATOR "
            "and every retention figure is unreadable without it" % required
        )
    assert "THE DENOMINATOR" in disc, (
        "runCorpusDiscovery.m no longer labels the retention denominator in "
        "its output. `pairs_dropped: 0` and `0 of 0 pairs inspected` read "
        "identically and only one of them is good news."
    )
    for want in ("vmspikefit", "pyraview"):
        assert want in disc, (
            "runCorpusDiscovery.m no longer names `%s` in the retention "
            "printout. Both migrators drop the epoch string BY CONSTRUCTION "
            "(they build new bodies and never copy the block), so a corpus "
            "that holds none of them must print '0 of 0 INSPECTED' rather "
            "than a bare 0 -- the generic_file_fold reading error." % want
        )

    # RENDERED -- REPORTED, NOT ASSERTED. census_digest.py is owned by another
    # change in flight; this prints the debt so it is a number rather than a
    # silence, and needs no edit here once the digest block lands.
    digest_src = _read(os.path.join(HERE, "census_digest.py"))
    rendered = [f for f in fields
                if ("'%s'" % f) in digest_src or ('"%s"' % f) in digest_src]
    print("  RENDERED   %d of %d field(s) named in census_digest.py "
          "(NOT GATED -- the digest is owned elsewhere; %d field(s) are an "
          "OPEN DEBT)" % (len(rendered), len(fields), len(fields) - len(rendered)))


# ---------------------------------------------------------------------------
# THE PRINTED HEADLINE. "7 EXPECTED" WHILE THE FILE COMPOSED 9.
# ---------------------------------------------------------------------------
# `printBatchPasses`'s `expected` cell array is a hand-kept MATLAB list, and
# deriving it inside MATLAB would mean the harness reading its own source at
# run time. The three tests below make the disagreement UNCOMMITTABLE instead,
# which is a weaker guarantee than derivation and a much stronger one than a
# comment: the count is derived from the table (`size(expected, 1)`), the table
# is pinned to the composed chain in BOTH directions, so the printed number
# cannot differ from what the file runs without this gate going red.
#
# Everything here is a text scan of the harness. It runs in milliseconds on the
# fast gate and needs no MATLAB -- which is the point, because the file it
# checks is only EXECUTED by the ~2-hour corpus job.

_RUN_BATCH_PASS = re.compile(
    r"runBatchPass\s*\(\s*result\s*,\s*(?:\.\.\.\s*)?"
    r"'did2\.convert\.(\w+)'\s*,\s*'(\w+)'", re.S)

_EXPECTED_ROW = re.compile(r"'(\w+)'\s*,\s*'did2\.convert\.(\w+)'")

_FATAL_LIST = re.compile(r"for\s+passField\s*=\s*\{(.*?)\}", re.S)


def _strip_matlab_comments(text):
    """Drop whole-line %-comments. DELIBERATELY CRUDE, and the direction of the
    error is the point: it only ever removes lines, so it can hide a call or a
    row -- never invent one. A hidden call makes a set SMALLER, which fails the
    equality tests below loudly instead of passing them quietly.
    """
    return "\n".join(line for line in text.splitlines()
                     if not line.strip().startswith("%"))


def _expected_table(text):
    """The (report field, function name) rows of printBatchPasses's table."""
    i = text.find("expected = {")
    if i < 0:
        return None
    j = text.find("};", i)
    if j < 0:
        return None
    block = _strip_matlab_comments(text[i:j])
    return set(_EXPECTED_ROW.findall(block))


def _guarded_calls(text):
    """(report field, function name) for every runBatchPass call in TEXT."""
    body = _strip_matlab_comments(text)
    return set((field, fn) for fn, field in _RUN_BATCH_PASS.findall(body))


def test_the_printed_table_is_exactly_the_composed_chain():
    """BOTH DIRECTIONS. A row with no call is a phantom; a call with no row is
    invisible in the log of every corpus run.

    The existing PRINTED test only checks the second direction, and only for
    passes discovered in the package -- so a row naming a pass this file does
    not compose would have sailed through it.
    """
    text = _read(DISCOVERY)
    table = _expected_table(text)
    assert table is not None, (
        "no `expected = {` table found in %s -- this is 'did not look', not "
        "'the table agrees'" % DISCOVERY)
    calls = _guarded_calls(text)
    print("\n--- printed table vs composed chain: %d row(s), %d guarded "
          "call(s) in %s ---" % (len(table), len(calls), DISCOVERY))
    for field, fn in sorted(table | calls):
        print("  %-28s %-40s %-10s %s"
              % (field, "did2.convert." + fn,
                 "ROW" if (field, fn) in table else "-- no row --",
                 "CALLED" if (field, fn) in calls else "-- not composed --"))
    assert table == calls, (
        "runCorpusDiscovery's printed `expected` table and the passes it "
        "actually composes through runBatchPass DISAGREE.\n"
        "  rows with no call: %s\n"
        "  calls with no row: %s\n"
        "  The headline is `%%d expected` off this table, so a disagreement "
        "prints a number that describes neither." % (
            sorted(table - calls) or "none", sorted(calls - table) or "none"))


def test_the_printed_pass_count_is_derived_from_the_table():
    """The headline must be size(expected, 1). A literal is how it said 7."""
    text = _read(DISCOVERY)
    hits = [line for line in text.splitlines()
            if "batch post-passes (%d expected)" in line]
    print("\n--- printed headline: %d matching fprintf line(s) ---" % len(hits))
    for line in hits:
        print("  %s" % line.strip())
    assert len(hits) == 1, (
        "expected exactly one `batch post-passes (%d expected)` headline in "
        "%s, found %d" % (DISCOVERY, len(hits)))
    # The argument may sit on the same line or wrap; take the fprintf call.
    i = text.find("batch post-passes (%d expected)")
    window = text[i:i + 400]
    assert "size(expected, 1)" in window, (
        "the batch-post-pass headline in %s does not read its count from "
        "`size(expected, 1)`. A literal there is exactly how the log printed "
        "'7 expected' while the file composed 9." % DISCOVERY)


def test_the_two_mutating_passes_are_guarded_and_fatal_at_both_producers():
    """resolveDeferredBaths and resolveDatasetEntities, named explicitly.

    A scan over what EXISTS cannot notice something that stopped existing, and
    these two are the reason this change exists: one moves documents from
    `quarantine` into `migrated` and swallowed every per-bath failure; the
    other DELETES documents. Both must (a) run through the guard at both
    report-writing sites, so a throw cannot destroy the corpus artifact, and
    (b) be in that site's FATAL list, so guarding them does not quietly
    downgrade a hard failure -- which is a regression in the costume of a
    safety improvement.
    """
    wanted = {
        "deferred_bath_resolution": "resolveDeferredBaths",
        "dataset_entity_resolution": "resolveDatasetEntities",
    }
    producers = ["runCorpusDiscovery", "testCorpusPRED"]
    print("\n--- the two mutating passes: %d pass(es) x %d report-writing "
          "producer(s) ---" % (len(wanted), len(producers)))
    problems = []
    for site in producers:
        text = _read(CALL_SITES[site])
        calls = _guarded_calls(text)
        fatal = set()
        for block in _FATAL_LIST.findall(_strip_matlab_comments(text)):
            fatal |= set(re.findall(r"'(\w+)'", block))
        for field, fn in sorted(wanted.items()):
            guarded = (field, fn) in calls
            is_fatal = field in fatal
            print("  %-28s %-20s guard:%-6s fatal:%-6s"
                  % (field, site, "yes" if guarded else "NO",
                     "yes" if is_fatal else "NO"))
            if not guarded:
                problems.append(
                    "%s is not routed through runBatchPass in %s -- a throw "
                    "there lands between the post-passes and "
                    "writeCorpusReport, and costs the corpus its entire "
                    "census" % (fn, site))
            if not is_fatal:
                problems.append(
                    "`%s` is missing from the FATAL pass list in %s. Both "
                    "passes were BARE calls for months, where a throw was "
                    "already fatal; guarding them without this is a silent "
                    "downgrade" % (field, site))
    assert not problems, "\n  ".join(["mutating-pass wiring:"] + problems)


def test_no_pass_is_left_without_a_report():
    """The claim in runBatchPass.m, asserted where it can actually be checked.

    That file says "Every pass in did2.convert assigns its report to RESULT
    unconditionally". It was FALSE for two of nine passes and nothing checked
    it -- a guarantee written as a description. NO_REPORT_YET is now empty, and
    this test is what keeps the sentence true rather than aspirational.
    """
    passes, _exempt, n_files = discover()
    without = [name for name, key in passes if not key]
    print("\n--- runBatchPass.m's claim: %d pass(es) in %d file(s), %d with no "
          "report, %d on the allow-list ---"
          % (len(passes), n_files, len(without), len(NO_REPORT_YET)))
    assert not NO_REPORT_YET, (
        "NO_REPORT_YET is non-empty (%s). That is allowed -- the list is the "
        "honest way to carry a gap -- but runBatchPass.m's claim that EVERY "
        "pass attaches a report must then be amended to name the exemptions "
        "and say why, in the same commit." % ", ".join(sorted(NO_REPORT_YET)))
    assert not without, (
        "pass(es) with no `result.<key> = report;`: %s" % ", ".join(without))


if __name__ == "__main__":
    import sys

    failures = 0
    for fn in [v for k, v in sorted(globals().items()) if k.startswith("test_")]:
        try:
            fn()
            print("PASS %s" % fn.__name__)
        except AssertionError as err:
            failures += 1
            print("FAIL %s\n  %s" % (fn.__name__, err))
    sys.exit(1 if failures else 0)
