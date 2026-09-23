function [names, counts] = aggregateOrphans(orphans)
%AGGREGATEORPHANS Count dangling edges by "doc_class.edge_name", descending.
%   The COMPLETE aggregate: bounded by the number of distinct class.edge pairs
%   rather than by the number of orphans, so it stays small on a corpus with
%   hundreds of thousands of dangling edges while losing no count. That is what
%   lets `referenceIntegrityBlock` cap its `orphans` SAMPLE without the report
%   quietly understating the damage.
%
%   PROMOTED from a local subfunction of runCorpusDiscovery.m 2026-08-13,
%   unchanged. It had two callers inside that file and now has a third in
%   +helpers/referenceIntegrityBlock.m; a copy in each is how two counters of
%   the same thing start disagreeing.
%
%   STATUS: NOT VERIFIED BY EXECUTION in the authoring environment (no MATLAB).

names = {};
counts = [];
for k = 1:numel(orphans)
    key = sprintf('%s.%s', orphans(k).doc_class, orphans(k).edge_name);
    idx = find(strcmp(names, key), 1);
    if isempty(idx)
        names{end+1} = key;  %#ok<AGROW>
        counts(end+1) = 1;   %#ok<AGROW>
    else
        counts(idx) = counts(idx) + 1;
    end
end
if ~isempty(counts)
    [counts, order] = sort(counts, 'descend');
    names = names(order);
end
end
