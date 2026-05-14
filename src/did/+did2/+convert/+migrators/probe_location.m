function v2Body = probe_location(preBody)
%PROBE_LOCATION Migrate a did_v1 probe_location body to V_delta.
%
%   Collapses the two coordinated did_v1 chars inside the
%   probe_location property block into a single `location` field of
%   `ontology_term` composite type:
%
%       probe_location.ontology_name -> probe_location.location.node
%       probe_location.name          -> probe_location.location.name
%
%   See did-schema's
%   schemas/V_delta/conversions/from_did_v1/probe_location.md for the
%   full specification and worked example.

arguments
    preBody (1,1) struct
end

v2Body = preBody;
if ~isfield(v2Body, 'probe_location') || ~isstruct(v2Body.probe_location)
    error('did2:convert:missingBlock', ...
        'probe_location body is missing the probe_location property block.');
end

block = v2Body.probe_location;
node = readChar(block, 'ontology_name');
labelName = readChar(block, 'name');

newBlock = struct();
newBlock.location = struct('node', node, 'name', labelName);
v2Body.probe_location = newBlock;
end

function out = readChar(block, fieldName)
if isfield(block, fieldName)
    out = char(block.(fieldName));
else
    out = '';
end
end
