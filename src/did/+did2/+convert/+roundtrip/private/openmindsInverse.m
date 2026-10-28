function [v1, spec] = openmindsInverse(bodies, v1Class, edgeName)
%OPENMINDSINVERSE The v1 openMINDS document (`openminds_subject`,
%   `openminds_element`) that +migrators_j/<V1CLASS> converted to one term
%   assertion.
%
%   [V1, SPEC] = openmindsInverse(BODIES, V1CLASS, EDGENAME). BODIES is the one
%   `assertion` (value kind `term`) the migrator wrote, id preserved; EDGENAME
%   is the v1 edge naming what it is about (`subject_id`, `element_id`). V1 is
%   the document in NDI's v1 shape (V1CLASS.json + openminds.json + base.json at
%   the locked NDI-matlab `main`, as ndi.database.fun.openMINDSobj2ndi_document
%   writes it):
%
%     base.id, session_id, datestamp   the assertion's (rebuildBase)
%     base.name                        '' (the writer sets none)
%     depends_on EDGENAME              the assertion's entity_id
%     depends_on openminds             '' (the writer's empty list entry for a
%                                      controlled term: it names no other
%                                      openMINDS document)
%     openminds.openminds_type         the openMINDS type the variable names
%                                      (species -> Species, ...), in the
%                                      https://openminds.om-i.org/types/ IRI
%     openminds.matlab_type            that type's openMINDS MATLAB class
%     openminds.openminds_id           '' (the migrator converts a document
%                                      that states one only when it rebuilds
%                                      from the term, and none does yet:
%                                      did2.convert.openmindsIdRebuilds)
%     openminds.fields.name            the value term's name
%     openminds.fields.preferredOntologyIdentifier (a controlled term) or
%       .ontologyIdentifier (a Strain)  the value term's node (a CURIE's
%                                      prefix case is notation)
%     every other field                ''
%
%   NOT REBUILT, and so reported by the round trip when v1 states them: the
%   term's definition and synonyms, which [openMINDS subject leftovers] (Jess
%   Haley, 2026-10-27) says are "read back from the term" -- nothing in DID
%   holds openMINDS's text for a term (the term registry's own definition is
%   another text); the other fields (description, interlexIdentifier,
%   knowledgeSpaceLink, a Strain's lists). A node taken from another field
%   than the one rebuilt (the migrator reads preferredOntologyIdentifier,
%   ontologyIdentifier, interlexIdentifier, alternateIdentifier, first
%   non-empty) is reported too.
%
%   See also did2.convert.roundtrip.openminds_subject,
%            did2.convert.roundtrip.openminds_element.

spec = emptySpec();
v1 = struct();
st = [];
used = false(1, numel(bodies));
for k = 1:numel(bodies)
    if strcmp(classNameOf(bodies{k}), 'assertion')
        st = bodies{k};
        used(k) = true;
        break;
    end
end
if isempty(st)
    spec.unplaced{end+1} = 'no assertion was emitted';
    return;
end
for k = find(~used)
    spec.unplaced{end+1} = sprintf('emitted document %d (%s) has no role in an %s', ...
        k, classNameOf(bodies{k}), v1Class);
end
base = rebuildBase(st);
[~, variable] = termParts(getIn(st, 'statement', 'variable'));
[kind, value] = statementValue(st);
if ~strcmp(kind, 'term')
    spec.unplaced{end+1} = sprintf('the assertion''s value kind is "%s", not term', kind);
end
[node, name] = termParts(value);
suffix = typeSuffixOf(variable);
about = edgeIds(st, 'entity_id');
if isempty(about); about = {''}; end

if strcmp(suffix, 'Strain')
    flds = struct('alternateIdentifier', '', 'backgroundStrain', [], 'breedingType', [], ...
        'description', '', 'digitalIdentifier', [], 'diseaseModel', [], ...
        'geneticStrainType', [], 'laboratoryCode', '', 'name', name, ...
        'ontologyIdentifier', node, 'phenotype', '', 'species', [], ...
        'stockNumber', [], 'synonym', '');
    matlabType = 'openminds.core.research.Strain';
    nodeField = 'ontologyIdentifier';
else
    flds = struct('definition', '', 'description', '', 'interlexIdentifier', '', ...
        'knowledgeSpaceLink', '', 'name', name, 'preferredOntologyIdentifier', node, ...
        'synonym', '');
    matlabType = ['openminds.controlledterms.' suffix];
    nodeField = 'preferredOntologyIdentifier';
end
v1.document_class = struct('class_name', v1Class);
v1.depends_on = struct('name', {edgeName, 'openminds'}, 'value', {about{1}, ''});
v1.base = struct('id', base.id, 'session_id', base.session_id, 'name', '', ...
    'datestamp', base.datestamp);
v1.openminds = struct('openminds_type', ['https://openminds.om-i.org/types/' suffix], ...
    'matlab_type', matlabType, 'openminds_id', '', 'fields', flds);
v1.(v1Class) = struct();
spec.same(end+1) = struct('path', ['openminds.fields.' nodeField], 'fn', @sameCurie, ...
    'why', ['a CURIE''s prefix case is notation ([spelling is notation], Jess ' ...
    'Haley, 2026-10-26); did2.convert.registeredTerm writes the registered spelling']);
end

function s = typeSuffixOf(variable)
% the openMINDS type the migrator's variableForType maps to VARIABLE
switch lower(strtrim(variable))
    case 'species';             s = 'Species';
    case 'strain';              s = 'Strain';
    case 'genetic strain type'; s = 'GeneticStrainType';
    case 'biological sex';      s = 'BiologicalSex';
    case 'phenotype';           s = 'Phenotype';
    otherwise
        % deCamel's inverse: 'cell type' -> 'CellType'
        words = strsplit(strtrim(char(variable)), ' ');
        words = words(~cellfun('isempty', words));
        for k = 1:numel(words)
            words{k}(1) = upper(words{k}(1));
        end
        s = strjoin(words, '');
end
end
