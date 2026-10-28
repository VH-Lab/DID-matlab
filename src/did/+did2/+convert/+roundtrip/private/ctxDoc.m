function [b, k] = ctxDoc(ctx, id)
%CTXDOC The document of base.id ID in a batch index (batchContext), and its
%   position; [] and 0 when the batch has none (or CTX is empty).
b = [];
k = 0;
if isempty(ctx) || isempty(id)
    return;
end
id = char(id);
if isKey(ctx.byId, id)
    k = ctx.byId(id);
    b = ctx.docs{k};
end
end
