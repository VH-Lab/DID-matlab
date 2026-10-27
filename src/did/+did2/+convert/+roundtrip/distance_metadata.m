function [v1, spec] = distance_metadata(bodies)
%DISTANCE_METADATA Rebuild a v1 `distance_metadata` from what the migration
%   made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.distance_metadata(BODIES). V1 is the
%   document in NDI's v1 shape (element/distance_metadata.json + base.json at
%   the locked NDI-matlab `main`, 3cb19a8, as +setup/+conv/+haley/doImport.m
%   writes it). BODIES holds the one V2 `distance_metadata` the migrator
%   reshapes it into:
%
%     base.id, session_id, name, datestamp  the document's (name is kept on a
%                                           class-preserving document)
%     depends_on element_id                 its element_id edge
%     distance_metadata.ontologyNode_<L>    endpoints(i).measurement.node, L
%                                           the endpoint's label
%     distance_metadata.integerIDs_<L>      endpoints(i).integer_ids, as the
%                                           column jsondecode gives a list
%     distance_metadata.ontologyNumericValues_<L>
%                                           endpoints(i).numeric_values, as a
%                                           column
%     distance_metadata.ontologyStringValues_<L>
%                                           endpoints(i).string_ids joined with
%                                           ',' (the writer's strjoin)
%     distance_metadata.units               units.node
%
%   Any other emitted document is unplaced.
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.distance_metadata.

arguments
    bodies cell
end

spec = emptySpec();
v1 = struct();
doc = [];
for k = 1:numel(bodies)
    if isempty(doc) && strcmp(classNameOf(bodies{k}), 'distance_metadata')
        doc = bodies{k};
    else
        spec.unplaced{end+1} = sprintf('emitted document %d (%s) has no role in a distance metadata', ...
            k, classNameOf(bodies{k}));
    end
end
if isempty(doc)
    spec.unplaced{end+1} = 'no distance_metadata was emitted';
    return;
end
base = rebuildBase(doc);
[name, ok] = getIn(doc, 'base', 'name');
if ~ok; name = ''; end
element = edgeIds(doc, 'element_id');
if isempty(element); element = {''}; end
block = struct();
endpoints = asCell(getIn(doc, 'distance_metadata', 'endpoints'));
for k = 1:numel(endpoints)
    ep = endpoints{k};
    L = char(getIn(ep, 'label'));
    [node, ~] = termParts(getIn(ep, 'measurement'));
    block.(['ontologyNode_' L]) = node;
    block.(['integerIDs_' L]) = reshape(double(getIn(ep, 'integer_ids')), [], 1);
    block.(['ontologyNumericValues_' L]) = reshape(double(getIn(ep, 'numeric_values')), [], 1);
    ids = getIn(ep, 'string_ids');
    if isstring(ids) || iscell(ids)
        ids = strjoin(cellstr(ids), ',');
    end
    block.(['ontologyStringValues_' L]) = char(ids);
end
[unode, ~] = termParts(getIn(doc, 'distance_metadata', 'units'));
block.units = unode;
v1.document_class = struct('class_name', 'distance_metadata');
v1.depends_on = struct('name', 'element_id', 'value', element{1});
v1.base = struct('id', base.id, 'session_id', base.session_id, 'name', char(name), ...
    'datestamp', base.datestamp);
v1.distance_metadata = block;
end
