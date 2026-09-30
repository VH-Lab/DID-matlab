function k = key(variable, n, options)
%KEY One entry of a `keys` list: what array dimension k is indexed by.
%
%   K = did2.build.key(VARIABLE, N, ...) describes one dimension of N positions
%   along VARIABLE (a term, or a name). `keys[k]` IS array dimension k, and time
%   is an ordinary key (data_body plan). The positions are given in ONE of
%   four ways, and the schema rules (data: key_regular_origin_spacing,
%   key_positions_one_form) are checked here:
%
%     regular        'Origin' and 'Spacing'  (both, and nothing else)
%     enumerated     'Values'                numeric positions, N of them
%     categorical    'Labels'                N terms (or names)
%     by reference   'LabelsFrom'            the index, among the document's
%                                            `key_labels_id` edges, of the
%                                            document whose rows name the
%                                            positions (item 12)
%
%   Options:
%     'Unit'           canonical unit of origin/spacing/values: a term, or a
%                      name. Absent for a categorical key. Angles are DEGREES.
%     'SourceUnit'     the unit as the source gave it (char)
%     'Approximate'    logical
%     'Origin','Spacing'              canonical, in 'Unit'
%     'SourceOrigin','SourceSpacing'  what the source wrote, in 'SourceUnit'
%     'Values'         numeric array of N positions (canonical)
%     'SourceValues'   the same positions as the source wrote them
%     'Labels'         N terms (struct array), or a cellstr of names
%     'LabelsFrom'     integer
%     'Cyclic'         logical: the dimension wraps (e.g. direction)
%     'Chunk'          positions per stored chunk -- ONLY on a sampled_body's
%                      keys (rule key_chunk_sampled_only, checked when the
%                      document is built)
%     'SchemaCache'    a did2.schema.cache; default the shared one.
%
%   Join several keys with did2.build.list. The variables of one list must be
%   distinct; that, and "a variable appears at most once across keys and
%   conditions", are checked when the document is built.
%
%   Examples:
%     t  = did2.build.key('time', 30000, 'Unit', 'second', ...
%              'Origin', 0, 'Spacing', 1/30000);
%     ch = did2.build.key('channel', 4, 'Labels', {'A1','A2','A3','A4'});
%
%   See also did2.build.list, did2.build.sampledBody, did2.build.condition.

arguments
    variable
    n (1,1) double {mustBeInteger, mustBeNonnegative}
    options.Unit = []
    options.SourceUnit = ''
    options.Approximate = []
    options.Origin = []
    options.Spacing = []
    options.SourceOrigin = []
    options.SourceSpacing = []
    options.Values = []
    options.SourceValues = []
    options.Labels = []
    options.LabelsFrom = []
    options.Cyclic = []
    options.Chunk = []
    options.SchemaCache = []
end

regular = ~isempty(options.Origin) || ~isempty(options.Spacing);
if regular && (isempty(options.Origin) || isempty(options.Spacing))
    error('did2:build:ruleViolated', ...
        'key_regular_origin_spacing: a regular key needs BOTH ''Origin'' and ''Spacing''.');
end
if ~regular && (~isempty(options.SourceOrigin) || ~isempty(options.SourceSpacing))
    error('did2:build:ruleViolated', ...
        'key_regular_origin_spacing: ''SourceOrigin''/''SourceSpacing'' need ''Origin'' and ''Spacing''.');
end
forms = {'Values', 'Labels', 'LabelsFrom'};
given = forms(cellfun(@(f) ~isempty(options.(f)), forms));
if regular && ~isempty(given)
    error('did2:build:ruleViolated', ...
        'key_positions_one_form: a regular key carries none of Values/Labels/LabelsFrom; got %s.', ...
        strjoin(given, ', '));
elseif ~regular && numel(given) ~= 1
    error('did2:build:ruleViolated', ...
        ['key_positions_one_form: give the positions ONE way -- ''Origin''+''Spacing'', ' ...
         '''Values'', ''Labels'' or ''LabelsFrom''; got %d.'], numel(given));
end
if isempty(options.Values) && ~isempty(options.SourceValues)
    error('did2:build:ruleViolated', '''SourceValues'' needs ''Values''.');
end
if ~isempty(options.Values) && numel(options.Values) ~= n
    error('did2:build:ruleViolated', ...
        'key_n_matches: n = %d but %d ''Values''.', n, numel(options.Values));
end
if ~isempty(options.SourceValues) && numel(options.SourceValues) ~= n
    error('did2:build:ruleViolated', ...
        'key_n_matches: n = %d but %d ''SourceValues''.', n, numel(options.SourceValues));
end
labels = options.Labels;
if ~isempty(labels) && (ischar(labels) || isstring(labels) || iscellstr(labels))
    labels = did2.build.label(labels);
end
if ~isempty(labels) && numel(labels) ~= n
    error('did2:build:ruleViolated', ...
        'key_n_matches: n = %d but %d ''Labels''.', n, numel(labels));
end

s = struct('variable', {variableArg(variable)});
if ~isempty(options.Unit);        s.unit = options.Unit;               end
if ~isempty(options.SourceUnit);  s.source_unit = options.SourceUnit;  end
if ~isempty(options.Approximate); s.approximate = options.Approximate; end
s.n = n;
s.regular = regular;
if regular
    s.origin = pair(options.Origin, options.SourceOrigin);
    s.spacing = pair(options.Spacing, options.SourceSpacing);
end
if ~isempty(options.Values)
    s.values = struct('values', reshape(options.Values, 1, []));
    if ~isempty(options.SourceValues)
        s.values.source_values = reshape(options.SourceValues, 1, []);
    end
end
if ~isempty(labels);             s.labels = labels;                 end
if ~isempty(options.LabelsFrom); s.labels_from = options.LabelsFrom; end
if ~isempty(options.Cyclic);     s.cyclic = options.Cyclic;         end
if ~isempty(options.Chunk);      s.chunk = options.Chunk;           end

k = did2.build.composite('data', 'keys', s, 'SchemaCache', options.SchemaCache);
end

function p = pair(value, source)
p = struct('value', value);
if ~isempty(source)
    p.source_value = source;
end
end

function v = variableArg(v)
% A variable is ONE term: a name (char/string) or a scalar struct {node,name}.
if iscell(v) || (isstruct(v) && ~isscalar(v)) || (isstring(v) && ~isscalar(v))
    error('did2:build:typeMismatch', ...
        'The variable is one term: a name or a scalar {node, name} struct.');
end
end
