function t = formatTerm(format)
%FORMATTERM A body's `format` as the ontology term it is (lightsheet point 4).
%
%   T = formatTerm(FORMAT) returns FORMAT as a {node, name} struct.
%   `data_body.format` is a bound `ontology_term` (did-schema 877bbde, Jess
%   2026-10-14: EDAM format terms, EMPTY where EDAM has none), no longer an
%   IANA media-type string. FORMAT may be:
%     a {node, name} struct   returned as given (a missing half becomes '')
%     a CURIE char/string     the node; the name is filled from the table below
%                             when the CURIE is one of these, else ''
%     any other char/string   the NAME, no node -- the rule did2.build.document
%                             applies to every ontology_term given as text
%     '' or []                returned as [] (absent), so the caller's
%                             required-field check sees it missing
%
%   KNOWN FORMAT TERMS (checked on OLS by Jess, 2026-10-14; OME-Zarr minted in
%   EMPTY, Waltham-Data-Science/empty-ontology#22, not yet released):
%     EDAM:format_3591  TIFF
%     EDAM:format_3997  MPEG-4
%     EDAM:format_2333  Binary format
%     EDAM:format_3915  Zarr
%     EMPTY:0000259     OME-Zarr   (a kind of EDAM:format_3915)

t = [];
if isempty(format)
    return;
end
if isstruct(format)
    t = struct('node', textOf(format, 'node'), 'name', textOf(format, 'name'));
    return;
end
if isstring(format) && isscalar(format), format = char(format); end
if ~ischar(format) || size(format, 1) > 1
    error('did2:build:typeMismatch', ...
        'A body''s format is a term: a {node, name} struct or a CURIE.');
end
format = strtrim(format);
if isempty(format)
    return;
end
if ~isempty(regexp(format, '^[A-Za-z][A-Za-z0-9_.-]*:[^\s/]+$', 'once'))
    t = struct('node', format, 'name', knownName(format));
else
    t = struct('node', '', 'name', format);
end
end

function v = textOf(s, f)
v = '';
if isfield(s, f) && ~isempty(s.(f))
    v = char(s.(f));
end
end

function name = knownName(curie)
known = { ...
    'EDAM:format_3591', 'TIFF'; ...
    'EDAM:format_3997', 'MPEG-4'; ...
    'EDAM:format_2333', 'Binary format'; ...
    'EDAM:format_3915', 'Zarr'; ...
    'EMPTY:0000259',    'OME-Zarr'};
name = '';
k = find(strcmpi(known(:, 1), curie), 1);
if ~isempty(k)
    name = known{k, 2};
end
end
