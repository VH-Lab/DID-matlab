function c = tuningAxisNamingCounts(n)
%TUNINGAXISNAMINGCOUNTS The count [tuning label choices confirmed] asks for,
%   from the run's 'tuning_axis_naming' notes.
%
%   C = did2.convert.tuningAxisNamingCounts(N) reads N, the
%   did2.convert.reportNote('collect') summary of kind 'tuning_axis_naming'
%   (one note per raw tuning curve jCalculation folded, its DETAIL what the
%   curve's axis was named from), and returns, DENOMINATOR FIRST:
%     C.curves_folded                 the folded raw curves (N.count)
%     C.named_from_varied_parameter   named from v1 independent_parameter
%                                     through did2.convert.tuningNames
%     C.named_from_label              named from the v1 display label, the
%                                     sum of the three below
%     C.label_no_independent_parameter  the curve's calculator states none
%                                     (the tuning_response app's bare curve)
%     C.label_not_in_name_table       one the name table does not hold
%     C.label_count_mismatch          a count that is not the number of
%                                     columns
%     C.no_detail                     notes with no DETAIL (none is written;
%                                     counted so the parts sum to the whole)
%     C.unread, C.unread_details      notes whose DETAIL is none of the
%                                     above (none is written; counted and
%                                     named rather than dropped or thrown:
%                                     a count must not cost the run)
%     C.not_in_name_table             each independent_parameter the table
%                                     does not hold, and
%     C.not_in_name_table_counts      how many curves name it
%     C.by_class                      N.by_class
%
%   [tuning label choices confirmed] (Decided by Jess Haley, 2026-11-17,
%   did-schema docs/plans/did_v2_go_forward_class_audit.md): "a curve with no
%   `independent_parameter`, or one the name table does not hold, is still
%   named from its label, and such curves are counted and reported."
%
%   See also did2.convert.reportNote, did2.convert.tuningNames.

arguments
    n (1,1) struct
end
det = reshape(cellstr(n.distinct_details), 1, []);
cnt = reshape(double(n.distinct_detail_counts), 1, []);
notInTable = 'label: independent_parameter not in the name table: ';
isVaried = strcmp(det, 'varied parameter');
isNone = strcmp(det, 'label: no independent_parameter');
isTable = strncmp(det, notInTable, numel(notInTable));
isCount = ~cellfun(@isempty, regexp(det, ...
    '^label: \d+ independent_parameter\(s\) for \d+ column\(s\)$', 'once'));
c = struct();
c.curves_folded = double(n.count);
c.named_from_varied_parameter = sum(cnt(isVaried));
c.label_no_independent_parameter = sum(cnt(isNone));
c.label_not_in_name_table = sum(cnt(isTable));
c.label_count_mismatch = sum(cnt(isCount));
c.named_from_label = c.label_no_independent_parameter + c.label_not_in_name_table + ...
    c.label_count_mismatch;
c.no_detail = c.curves_folded - sum(cnt);
other = ~(isVaried | isNone | isTable | isCount);
c.unread = sum(cnt(other));
c.unread_details = det(other);
c.not_in_name_table = cellfun(@(d) d(numel(notInTable) + 1:end), det(isTable), ...
    'UniformOutput', false);
c.not_in_name_table_counts = cnt(isTable);
c.by_class = n.by_class;
end
