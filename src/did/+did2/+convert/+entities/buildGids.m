function g = buildGids(varargin)
%BUILDGIDS Assemble an `entity.global_identifier` struct array.
%
%   G = did2.convert.entities.buildGids({SCHEME1, VALUE1}, {SCHEME2, VALUE2},
%   ...) returns a struct array with one entry per pair whose VALUE is
%   non-empty, and a 0x0 struct with the right fields when none is.
%
%   Empty pairs are SKIPPED rather than stored blank: an identifier with no
%   value is a vacuous field, which is the shape the vacuous-required-field
%   census exists to find.
%
%   STATUS 2026-08-11: WRITTEN WITHOUT MATLAB -- see entityDoc's header. Moved
%   verbatim out of did2.convert.migrators_j.metadata_editor.
%
%   See also: did2.convert.entities.emptyGids, did2.convert.entities.entityDoc.

g = did2.convert.entities.emptyGids();
for k = 1:numel(varargin)
    pair = varargin{k};
    val = char(pair{2});
    if isempty(val); continue; end
    g(end+1) = struct('scheme', char(pair{1}), 'value', val); %#ok<AGROW>
end
end
