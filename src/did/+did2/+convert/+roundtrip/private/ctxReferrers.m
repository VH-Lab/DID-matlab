function idx = ctxReferrers(ctx, id)
%CTXREFERRERS The positions, in batch order, of every document of a batch
%   index (batchContext) whose depends_on names ID (any edge but session_id);
%   [] when none does (or CTX is empty). Read each with CTX.docs{k}.
idx = [];
if isempty(ctx) || isempty(id)
    return;
end
id = char(id);
if isKey(ctx.referrers, id)
    idx = ctx.referrers(id);
end
end
