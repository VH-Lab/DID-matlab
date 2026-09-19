function reasons = topQuarantineReasons(quarantine)
%TOPQUARANTINEREASONS Aggregate quarantine entries by (class, reason).
%
%   REASONS = did2.unittest.helpers.topQuarantineReasons(QUARANTINE) returns
%   a struct array with fields class_name, reason, count, sorted by
%   descending count. Empty struct array when QUARANTINE is empty.

if isempty(quarantine)
    reasons = struct('class_name', {}, 'reason', {}, 'count', {});
    return;
end
keys = cell(1, numel(quarantine));
for k = 1:numel(quarantine)
    keys{k} = sprintf('%s|||%s', quarantine(k).class_name, ...
        quarantine(k).reason);
end
[uniqKeys, ~, idx] = unique(keys);
counts = accumarray(idx, 1);
reasons = struct('class_name', {}, 'reason', {}, 'count', {});
for k = 1:numel(uniqKeys)
    parts = strsplit(uniqKeys{k}, '|||');
    reasons(k).class_name = parts{1};
    reasons(k).reason     = parts{2};
    reasons(k).count      = counts(k);
end
[~, order] = sort(-[reasons.count]);
reasons = reasons(order);
end
