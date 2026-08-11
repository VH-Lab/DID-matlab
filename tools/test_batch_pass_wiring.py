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
# These two passes predate Operating Rule 5 and attach NO report at all, so
# there is nothing for the PERSISTED and PRINTED legs to check. They are listed
# here rather than silently skipped, and the list is gated BOTH WAYS:
#
#   * a pass NOT on this list must declare a report key      (it cannot grow
#                                                             without a decision)
#   * a pass ON this list that HAS acquired one must be removed from it
#                                                            (it cannot go stale)
#
# A hand-kept allow-list that only ever gets longer is the thing that would have
# gone stale the day resolveSessionAnchors was added. This one can only shrink.
#
# What their absence costs, said plainly rather than filed away:
# `resolveDeferredBaths` resolves deferred stimulus_baths and `resolveDatasetEntities`
# dedups `dataset` entities and PRUNES membership relations -- both change the
# corpus, and neither reports how many documents it inspected, resolved or
# dropped. "Ran and found nothing" and "ran and silently failed to resolve
# anything" are the same reading of every corpus run today. Fixing that is a
# separate change with its own owner; recording it is not.
NO_REPORT_YET = {
    "resolveDatasetEntities": "predates Operating Rule 5; dedups `dataset` "
                              "entities and prunes membership relations without "
                              "reporting its denominator",
    "resolveDeferredBaths": "predates Operating Rule 5; resolves deferred "
                            "stimulus_baths without reporting how many it "
                            "inspected or refused",
}


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
#   epoch_mint.documents_with_epoch_id / .strings_declined /
#   .strings_declined_distinct
#       REAL COUNTERS, REALLY NOT RENDERED. epochMint's own header says a
#       declined string should be "a number in strings_by_source /
#       strings_declined rather than" a silence -- and that number does not
#       reach the digest today.
#   valid_interval_decompose.anchor_session_from_timeref / _from_document /
#   method_from_app_block / method_from_class_default
#       REAL COUNTERS, REALLY NOT RENDERED. They record WHERE a value came
#       from, which is the provenance half of that pass's report.
#
# Closing either group is a digest change, not a pass change, and is out of
# scope for the change that added this gate. Recording it is not.
NOT_RENDERED_YET = {
    "epoch_mint": {
        "strings_by_source", "epoch_index",
        "documents_with_epoch_id", "strings_declined",
        "strings_declined_distinct",
    },
    "valid_interval_decompose": {
        "anchor_session_from_timeref", "anchor_session_from_document",
        "method_from_app_block", "method_from_class_default",
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
    renders AT ALL are checked. Three passes (lawn_plate_subjects,
    openminds_citations, response_parameters_fold) have no POST_PASSES entry,
    so every counter they declare is unrendered -- a whole-pass gap, which is a
    bigger and different decision than a missing row, and one this test names
    rather than silently folds into a count.
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
