function v2Body = ontology_image(preBody)
%ONTOLOGY_IMAGE Base migrator: did_v1 ontologyImage body -> the class-preserving V2 shape.
%
%   The class is renamed from ontologyImage (camelCase, V_alpha) to
%   ontology_image (snake_case, V2) by
%   did2.convert.universalRenames; this migrator collapses the two
%   coordinated chars inside the ontology_image property block into a
%   single `region` field of `ontology_term` composite type:
%
%       ontology_image.ontology_name   -> ontology_image.region.node
%       ontology_image.ontology_region -> ontology_image.region.name
%
%   See did-schema's
%   did-schema's per-class conversion notes (deleted with did-schema #88).

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
