function v2Body = filter(preBody)
%FILTER Migrate a did_v1 filter block to V_delta.
%
%   v1's filter block carries a `type` field (e.g., 'high', 'low',
%   'bandpass') describing the filter character. V_delta renamed
%   this to `filter_type` to avoid collision with the more
%   universal `type` keyword. The other fields (label, algorithm,
%   parameters) match V_delta verbatim and pass through.
%
%   This is a *superclass migrator*: filter is rarely a concrete
%   class; it ships as a superclass-contributed property block on
%   classes like pyraview. The dispatcher walks
%   document_class.superclasses (as normalised by universalRenames)
%   and runs this migrator on any document that declares filter
%   among its superclasses, before the concrete-class migrator
%   runs.

arguments
    preBody (1,1) struct
end

v2Body = preBody;
if ~isfield(v2Body, 'filter') || ~isstruct(v2Body.filter)
    return;
end

block = v2Body.filter;

if isfield(block, 'type') && ~isfield(block, 'filter_type')
    block.filter_type = char(block.type);
    block = rmfield(block, 'type');
elseif isfield(block, 'type')
    block = rmfield(block, 'type');
end

v2Body.filter = block;
end
