function [node, name, table] = openmindsInstanceNode(openmindsId, openmindsType)
%OPENMINDSINSTANCENODE The ontology node the team decided for an openMINDS
%   controlled-term instance that names no node of its own.
%
%   [NODE, NAME] = did2.convert.openmindsInstanceNode(OPENMINDSID) is the node
%   and label decided for the openMINDS instance OPENMINDSID, written as v1
%   writes it (openMINDS's own IRI,
%   https://openminds.om-i.org/instances/<terminology>/<name>) or as the
%   registered CURIE `openminds:<terminology>/<name>`. It is '' (and NAME '')
%   for any other id. [NODE, NAME] = ...(OPENMINDSID, OPENMINDSTYPE) also
%   requires the instance's terminology to be the openMINDS type OPENMINDSTYPE
%   names (its IRI, or the type name: `GeneticStrainType` for the
%   `geneticStrainType` terminology), so a GeneticStrainType instance never
%   gives a Species document its node. [~, ~, TABLE] = ...('') is the whole
%   table, a struct array {key, node, name} (key `<terminology>/<name>`), for
%   a reader that starts from the node (the round trip).
%
%   THE TABLE IS THE DECISION, not a lookup in the term registry: it answers
%   the same with or without a schema, so the migrator and the round trip
%   agree whatever registry the schema in use holds. NAME is the decided
%   term's label; a caller writes it through did2.convert.registeredTerm, so a
%   registry that holds the node writes its registered label instead.
%
%     geneticStrainType/wildtype    BAO:0000089  wild type
%     geneticStrainType/transgenic  OBI:1000048  transgenic organism
%     geneticStrainType/knockin     NCIT:C22492  Knock-in
%
%   Decided by Jess Haley, 2026-11-19 [openMINDS ids rebuild the subject
%   terms] (did-schema did_v2_go_forward_class_audit.md): "group A, the
%   GeneticStrainType terms with an openMINDS instance IRI but no ontology
%   node (2,362 documents: wildtype, transgenic, knockin), resolve their node
%   from the openMINDS IRI in the migrator: wildtype to BAO:0000089,
%   transgenic to OBI:1000048". Decided by Jess Haley, 2026-11-19 [knockin is
%   NCIT Knock-in]: "the openMINDS GeneticStrainType knockin resolves to
%   NCIT:C22492 "Knock-in"". Tracked in Waltham-Data-Science/did-schema#212.
%
%   See also did2.convert.openmindsIdRebuilds,
%            did2.convert.migrators_j.openminds_subject.

arguments
    openmindsId {mustBeText}
    openmindsType {mustBeText} = ''
end

persistent TABLE
if isempty(TABLE)
    TABLE = struct( ...
        'key',  {'geneticStrainType/wildtype', 'geneticStrainType/transgenic', ...
                 'geneticStrainType/knockin'}, ...
        'node', {'BAO:0000089', 'OBI:1000048', 'NCIT:C22492'}, ...
        'name', {'wild type', 'transgenic organism', 'Knock-in'});
end

node = '';
name = '';
table = TABLE;
id = strtrim(char(openmindsId));
key = '';
IRI = 'https://openminds.om-i.org/instances/';
if startsWith(id, IRI)
    key = id(numel(IRI)+1:end);
elseif startsWith(id, 'openminds:')
    key = id(numel('openminds:')+1:end);
end
if isempty(key)
    return;
end
hit = find(strcmp({TABLE.key}, key), 1);
if isempty(hit)
    return;
end
typ = strtrim(char(openmindsType));
if ~isempty(typ)
    parts = strsplit(typ, {'/', '#', ':', '.'});
    parts = parts(~cellfun('isempty', parts));
    terminology = strtok(TABLE(hit).key, '/');
    if isempty(parts) || ~strcmpi(parts{end}, terminology)
        return;
    end
end
node = TABLE(hit).node;
name = TABLE(hit).name;
end
