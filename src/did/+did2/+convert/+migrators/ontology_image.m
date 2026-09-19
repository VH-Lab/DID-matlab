function v2Body = ontology_image(preBody)
%ONTOLOGY_IMAGE Migrate a did_v1 ontologyImage body to V_delta.
%
%   The class is renamed from ontologyImage (camelCase, V_alpha) to
%   ontology_image (snake_case, V_delta) by
%   did2.convert.universalRenames; this migrator collapses the two
%   coordinated chars inside the ontology_image property block into a
%   single `region` field of `ontology_term` composite type:
%
%       ontology_image.ontology_name   -> ontology_image.region.node
%       ontology_image.ontology_region -> ontology_image.region.name
%
%   See did-schema's
%   schemas/V_delta/conversions/from_did_v1/ontology_image.md.

arguments
    preBody (1,1) struct
end

v2Body = preBody;
if ~isfield(v2Body, 'ontology_image') || ~isstruct(v2Body.ontology_image)
    error('did2:convert:missingBlock', ...
        'ontology_image body is missing the ontology_image property block.');
end

block = v2Body.ontology_image;
if isfield(block, 'ontology_name')
    node = char(block.ontology_name);
else
    node = '';
end
if isfield(block, 'ontology_region')
    labelName = char(block.ontology_region);
else
    labelName = '';
end

newBlock = struct();
newBlock.region = struct('node', node, 'name', labelName);
v2Body.ontology_image = newBlock;
end
