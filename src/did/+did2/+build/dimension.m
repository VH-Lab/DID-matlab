function d = dimension(term, n, options)
%DIMENSION One entry of a value's `dimensions`: one axis of the stored array.
%
%   D = did2.build.dimension(TERM, N) describes one axis of N positions. TERM
%   says what the axis IS (a term, or a name: 'time', 'channel', a label
%   {name:'row'}). `dimensions[k]` IS array axis k (did-schema data_body
%   AMENDMENT 6, Jess Haley 2026-10-22 [covariates]). Terms need not be
%   unique: a channel x channel matrix has two `channel` dimensions.
%
%   A dimension says nothing about its positions. What is known about them
%   (the time of each sample, the name of each channel, the onset of each
%   presentation) is a COVARIATE along it (did2.build.covariate), which points
%   at the dimension by its 0-based index. A dimension may have none
%   [bare dimension].
%
%   Options:
%     'Chunk'        positions per stored chunk -- ONLY on a sampled_body's
%                    dimensions (checked when the document is built)
%     'SchemaCache'  a did2.schema.cache; default the shared one.
%
%   Join several with did2.build.list, in array order.
%
%   Example:
%     dims = did2.build.list(did2.build.dimension('time', 30000), ...
%                            did2.build.dimension('channel', 4));
%     covs = did2.build.list( ...
%         did2.build.covariate('time', 0, 'Origin', 0, 'Spacing', 1/30000, 'Unit', 'second'), ...
%         did2.build.covariate('channel', 1, 'Term', {'A1','A2','A3','A4'}));
%
%   See also did2.build.covariate, did2.build.list, did2.build.sampledBody.

arguments
    term
    n (1,1) double {mustBeInteger, mustBeNonnegative}
    options.Chunk = []
    options.SchemaCache = []
end

if iscell(term) || (isstruct(term) && ~isscalar(term)) || (isstring(term) && ~isscalar(term))
    error('did2:build:typeMismatch', ...
        'A dimension''s term is one term: a name or a scalar {node, name} struct.');
end
s = struct('term', {term}, 'n', n);
if ~isAbsent(options.Chunk)
    s.chunk = options.Chunk;
end
d = did2.build.composite('data', 'dimensions', s, 'SchemaCache', options.SchemaCache);
end
