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

So this file gates all three legs, statically, by reading the sources as text:

    CALLED     named in all three DID-side call sites
    PERSISTED  its report key copied by writeCorpusReport
    PRINTED    its report key in runCorpusDiscovery's `expected` table

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


def _read(path):
    with open(path, "r", encoding="utf-8") as handle:
        return handle.read()


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
