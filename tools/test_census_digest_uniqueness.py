#!/usr/bin/env python3
"""#52 -- the family-uniqueness rows of tools/census_digest.py.

A SEPARATE FILE, deliberately: tools/test_census_digest.py is owned by the
digest's own history (every case there is a shape that broke a real corpus run)
and its assertions must keep passing unchanged.

WHAT #52 IS. Within a `time_reference_#` family every member describes the same
instant or extent, and `value.clock` on the REFERENCED document must be unique
across the family -- that clock is the only thing that makes two members
different, so without the rule a bare `_1`/`_2` index means nothing.
`did2.validate.silentLoss` measures it in batch (it is the only instrument that
holds the referenced documents) and writes
`family_uniqueness_violation` + `uniqueness_denominator` into the corpus report.

WHY THE DENOMINATORS ARE TESTED AS HARD AS THE COUNT. This counter has FOUR
distinct ways to read zero:

    the rule fired and found nothing wrong
    no document carried two members, so it could not fire
    the referenced documents were not in the batch
    the referents declare no `value.clock` at all  (TRUE OF ALMOST EVERYTHING
    TODAY: only `relative_reference` declares one, and every live anchor is
    still a session_*_reference)

A digest that prints only "0 violations" makes those four identical -- which is
precisely the failure that let `silentLoss` report a clean census for two days
while reading nothing. So the tests below assert that the denominators PRINT,
and that a zero multi-member denominator prints its own warning.

STATUS: this file is Python and it runs here. The MATLAB half it describes
(`did2.validate.silentLoss`) has NOT been executed -- there is no MATLAB in this
container -- so nothing here proves the numbers are produced correctly, only
that a report carrying them is rendered honestly.

Run: python3 tools/test_census_digest_uniqueness.py
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from census_digest import render_report, rollup  # noqa: E402


def _report(corpus, violations, den):
    return {
        "corpus": corpus,
        "total": 10,
        "migrated_count": 10,
        "quarantine_count": 0,
        "silent_loss": {
            "total_docs": 10,
            "skipped_docs": 0,
            "empty_dependency_count": 0,
            "vacuous_field_count": 0,
            "family_violation_count": 0,
            "family_uniqueness_violation": violations,
            "family_uniqueness_violation_count":
                sum(v["count"] for v in violations) if violations else 0,
            "uniqueness_denominator": den,
        },
    }


CAN_FIRE = {
    "families_declared": 3,
    "docs_with_family": 8,
    "docs_multi_member": 4,
    "members_examined": 12,
    "members_resolved": 12,
    "members_unresolved": 0,
    "members_no_key": 0,
    "members_keyed_by_node": 0,
    "members_keyed_by_name": 12,
}

CANNOT_FIRE = dict(CAN_FIRE, docs_multi_member=0, members_examined=8,
                   members_resolved=8, members_keyed_by_name=8)


def _render(r):
    out = []
    render_report(r, out)
    return "\n".join(out)


class TestPerCorpusRendering(unittest.TestCase):
    def test_the_violation_line_prints_even_at_zero(self):
        text = _render(_report("A", [], CAN_FIRE))
        self.assertIn("family-uniqueness violation(s)", text)

    def test_all_three_denominator_lines_print(self):
        text = _render(_report("A", [], CAN_FIRE))
        self.assertIn("famil(ies) declare a uniqueness rule", text)
        self.assertIn("member(s) examined", text)
        self.assertIn("compared on", text)

    def test_a_zero_that_could_not_fire_says_so(self):
        # The whole point. Today NOTHING carries two members of a governed
        # family (every migrator writes only `time_reference_1`), so this is
        # the branch a real corpus run takes right now.
        text = _render(_report("A", [], CANNOT_FIRE))
        self.assertIn("COULD NOT FIRE", text)
        self.assertIn("'untested', not 'clean'", text)

    def test_a_zero_that_could_have_fired_does_NOT_claim_untested(self):
        text = _render(_report("A", [], CAN_FIRE))
        self.assertNotIn("COULD NOT FIRE", text)

    def test_a_violation_row_names_the_class_the_edge_and_the_shared_key(self):
        v = [{"class_name": "epoch", "edge_name": "time_reference_#",
              "unique_by": "value.clock", "key": "name:dev_local_time",
              "count": 7}]
        text = _render(_report("A", v, CAN_FIRE))
        self.assertIn("epoch.time_reference_#", text)
        self.assertIn("value.clock", text)
        self.assertIn("name:dev_local_time", text)
        self.assertIn("7", text)

    def test_a_single_violation_struct_is_tolerated(self):
        # MATLAB's jsonencode writes a one-element struct array as a bare
        # object. The digest has been killed by exactly this once already.
        r = _report("A", [], CAN_FIRE)
        r["silent_loss"]["family_uniqueness_violation"] = {
            "class_name": "epoch", "edge_name": "time_reference_#",
            "unique_by": "value.clock", "key": "name:utc", "count": 3}
        r["silent_loss"]["family_uniqueness_violation_count"] = 3
        text = _render(r)
        self.assertIn("name:utc", text)

    def test_a_report_from_before_this_counter_existed_still_renders(self):
        # Old artifacts have neither field. The digest must degrade to '?',
        # not raise -- a rollup that dies takes the per-corpus output with it.
        r = _report("A", [], CAN_FIRE)
        del r["silent_loss"]["family_uniqueness_violation"]
        del r["silent_loss"]["family_uniqueness_violation_count"]
        del r["silent_loss"]["uniqueness_denominator"]
        text = _render(r)
        self.assertIn("family-uniqueness violation(s)", text)


class TestRollup(unittest.TestCase):
    def _roll(self, reports):
        out = []
        rollup(reports, out)
        return "\n".join(out)

    def test_the_rollup_has_its_own_section_and_denominators(self):
        text = self._roll([_report("A", [], CAN_FIRE),
                           _report("B", [], CAN_FIRE)])
        self.assertIn("EDGE-FAMILY UNIQUENESS VIOLATIONS", text)
        self.assertIn("doc-family pair(s) carried a member", text)
        # 4 + 4 multi-member pairs summed across the two corpora
        self.assertIn("8 carried MORE THAN ONE", text)

    def test_same_row_from_two_corpora_is_merged_not_listed_twice(self):
        v = [{"class_name": "epoch", "edge_name": "time_reference_#",
              "unique_by": "value.clock", "key": "name:utc", "count": 5}]
        text = self._roll([_report("A", v, CAN_FIRE),
                           _report("B", v, CAN_FIRE)])
        self.assertIn("EDGE-FAMILY UNIQUENESS VIOLATIONS: 10 document(s) "
                      "across 1 row(s)", text)

    def test_a_rollup_where_nothing_could_fire_says_so_loudly(self):
        text = self._roll([_report("A", [], CANNOT_FIRE),
                           _report("B", [], CANNOT_FIRE)])
        self.assertIn("NOTHING IN REACH CARRIES TWO MEMBERS", text)

    def test_a_rollup_where_the_rule_could_fire_does_not(self):
        text = self._roll([_report("A", [], CAN_FIRE)])
        self.assertNotIn("NOTHING IN REACH CARRIES TWO MEMBERS", text)

    def test_missing_denominators_do_not_break_the_rollup(self):
        r = _report("A", [], CAN_FIRE)
        del r["silent_loss"]["uniqueness_denominator"]
        text = self._roll([r])
        self.assertIn("EDGE-FAMILY UNIQUENESS VIOLATIONS", text)


if __name__ == "__main__":
    unittest.main(verbosity=2)
