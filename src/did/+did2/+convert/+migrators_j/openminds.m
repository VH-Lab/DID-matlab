function v2Body = openminds(preBody)
%OPENMINDS Brainstorm-J migrator: did_v1 `openminds` -- a GUARDED PASSTHROUGH.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   STATUS 2026-08-11: WRITTEN WITHOUT MATLAB. There is neither MATLAB nor
%   Octave in the container this was authored in, so THIS FILE HAS NOT BEEN
%   EXECUTED. CI is the first execution.
%
%   ---------------------------------------------------------------------
%   WHAT THE CLASS ACTUALLY HOLDS
%   ---------------------------------------------------------------------
%   `openminds` is not one kind of document. It is whatever
%   ndi.database.fun.openMINDSobj2ndi_document was handed with NO
%   dependency_type -- that function's switch defaults `docName = 'openminds'`
%   (openMINDSobj2ndi_document.m:45-50), and every child object of the object
%   it is given becomes its own document of the same class. Two producers reach
%   it today:
%
%     THE DATASET CITATION GRAPH.  ndi.database.metadata_ds_core.
%     convertFormDataToDocuments builds an openminds.core.Dataset ->
%     DatasetVersion -> {Person, Affiliation, Organization, ORCID,
%     ContactInformation, Funding, Contribution, ContributionType, DOI,
%     WebResource, License, SemanticDataType, ExperimentalApproach, technique}
%     and calls openMINDSobj2ndi_document(dataset, sessionId) at :197 with no
%     dependency_type. The ENTIRE graph lands as bare `openminds`.
%
%     THE STRAIN FAMILY.  +ndi/+setup/+conv/+haley/doImport.m:87,706 writes
%     openminds.core.research.Strain objects (OP50, OP50-GFP) the same way,
%     dragging Species / GeneticStrainType fragments in with them.
%
%   ---------------------------------------------------------------------
%   WHY A PASSTHROUGH, AND WHO CONSUMES IT
%   ---------------------------------------------------------------------
%   Neither producer can be migrated by a single-document migrator, for the
%   same reason: the values live in OTHER documents. A parent's field is
%   replaced by an `ndi://<childId>` string and an `openminds_#` dependency
%   (openMINDSobj2struct.m, openMINDSobj2ndi_document.m:77-90), so one
%   `person` needs FIVE documents (Person + Affiliation + Organization + ORCID
%   + ContactInformation) joined by those strings. Pass 1 therefore carries the
%   document INTACT and two batch assemblers do the work with the graph in
%   hand:
%
%     did2.convert.resolveOpenmindsCitations       DID-side, the citation graph
%                                                  (TEAM DECISION 2026-08-11,
%                                                  "Do B")
%     ndi.migrate.internal.strainAssembly          NDI-side, the strain family
%                                                  (signed model, V_eta_openminds_
%                                                  family_record.md Part 7)
%
%   Carrying the body VERBATIM is what both of them depend on. This function
%   must not reshape, rename or drop anything.
%
%   ---------------------------------------------------------------------
%   THE GUARD -- AND, EXPLICITLY, WHAT IT DOES NOT GUARD
%   ---------------------------------------------------------------------
%   The `ontology_image` pattern: branch on the document's own type marker and
%   ERROR rather than emit something empty. Two conditions error here, and
%   BOTH are provably no worse than today's behaviour:
%
%     (a) no `openminds` property block at all -- the class has nothing to
%         carry, and a passthrough would fail validation for a missing class
%         block anyway;
%     (b) neither `matlab_type` nor `openminds_type` carries text -- the
%         document cannot be classified by ANY consumer, and
%         schemas/V_eta/stable/openminds.json declares `openminds_type`
%         mustBeNonEmpty, so such a document quarantines on validation
%         regardless. Erroring here changes the REASON, not the outcome.
%
%   AN UNRECOGNISED `matlab_type` DOES NOT ERROR, deliberately, and that is a
%   departure from `ontology_image` worth stating rather than leaving implicit.
%   The openMINDS type set here is OPEN-ENDED BY CONSTRUCTION: technique
%   instances are built as `openminds.controlledterms.<schemaName>` where
%   schemaName is parsed out of a user-entered string --
%
%       convertFormDataToDocuments.m (convertTechnique)
%           splitStr = strsplit(value, '(');
%           schemaName = strrep(strtrim(splitStr{2}), ')', '');
%           fcn = sprintf('openminds.controlledterms.%s', schemaName);
%
%   -- so an allow-list of type names cannot be complete, and a type absent
%   from it would be a NEW quarantine against a measured 0-quarantine gate.
%   The three routes below are branched and named so the classification is
%   visible, but every one of them passes the document through unchanged.
%
%   MATCHING IS ON THE TRAILING SEGMENT, not the full string, because both the
%   MATLAB namespace and the IRI vary: the app writes `openminds.core.Person`
%   while `class()` records the concrete `openminds.core.actors.Person` (the
%   reader queries `openminds.core.products.DatasetVersion` for what the writer
%   constructed as `openminds.core.DatasetVersion`), and two IRI vintages ship
%   (`https://openminds.ebrains.eu/core/...` and
%   `https://openminds.om-i.org/types/...`). Same idiom as
%   ndi.migrate.internal.strainAssembly.isOpenmindsType.
%
%   ---------------------------------------------------------------------
%   THE `fields` KEYS STAY camelCase
%   ---------------------------------------------------------------------
%   did2.convert.universalRenames snake-cases only ONE level -- it walks
%   `fieldnames(block)` per top-level property block and stops
%   (universalRenames.m:351-367). `fields` is a nested struct inside the
%   `openminds` block, so `fullName`, `givenName`, `relatedPublication` and the
%   rest arrive unchanged. Every consumer reads them with a snake_case
%   fallback anyway, per the standing migrator lesson.
%
%   See also: did2.convert.resolveOpenmindsCitations,
%   did2.convert.migrators_j.openminds_subject,
%   did2.convert.migrators_j.ontology_image.

arguments
    preBody (1,1) struct
end

if ~isfield(preBody, 'openminds') || ~isstruct(preBody.openminds) ...
        || isempty(preBody.openminds)
    error('did2:convert:missingBlock', ...
        ['openminds body is missing the openminds property block. Nothing ' ...
         'downstream can classify or consume it, and it carries no payload.']);
end
block = preBody.openminds(1);

matlabType    = jGetChar(block, 'matlab_type');
openmindsType = jGetChar(block, 'openminds_type');

if isempty(strtrim(matlabType)) && isempty(strtrim(openmindsType))
    error('did2:convert:openmindsUnknownShape', ...
        ['openminds body carries neither `matlab_type` nor `openminds_type`, ' ...
         'so no consumer can tell which openMINDS object it holds. The V_eta ' ...
         '`openminds` schema declares openminds_type mustBeNonEmpty, so this ' ...
         'document could not have validated either way -- refusing to pass ' ...
         'an unclassifiable body through silently.']);
end

% Branch on the type. Every arm passes the document through UNCHANGED; the
% branch exists so the routing is stated in one place and so a census of what
% is present is a one-line change here rather than a new scan.
switch routeFor(matlabType, openmindsType)
    case 'citation'
        % Consumed by did2.convert.resolveOpenmindsCitations, all-or-none per
        % connected component.
        v2Body = {preBody};
    case 'subject'
        % OUT OF SCOPE for the citation build (team brief, 2026-08-11): these
        % overlap the existing openminds_subject route and the signed strain
        % decision. Consumed NDI-side by ndi.migrate.internal.strainAssembly.
        v2Body = {preBody};
    otherwise
        % An openMINDS object neither assembler claims. Carried intact; the
        % class tombstone describes it faithfully (openminds_type, matlab_type,
        % openminds_id and the open-shape `fields` struct).
        v2Body = {preBody};
end
end

% ===================== local helpers ===================================

function route = routeFor(matlabType, openmindsType)
%ROUTEFOR Which consumer claims this openMINDS object: 'citation', 'subject',
%   or 'other'. Names only -- see the header for why an unlisted name is not an
%   error.
citation = {'Dataset', 'DatasetVersion', 'Person', 'Organization', ...
    'Affiliation', 'ContactInformation', 'ORCID', 'RORID', 'GRIDID', ...
    'Funding', 'Contribution', 'ContributionType', 'DOI', 'ISBN', ...
    'WebResource', 'License', 'Copyright', 'SemanticDataType', ...
    'ExperimentalApproach'};
subject = {'Subject', 'SubjectState', 'BiologicalSex', 'Species', 'Strain', ...
    'GeneticStrainType', 'Phenotype', 'RRID', 'StockNumber', ...
    'TissueSample', 'TissueSampleState'};

if matchesAny(matlabType, openmindsType, citation)
    route = 'citation';
elseif matchesAny(matlabType, openmindsType, subject)
    route = 'subject';
else
    route = 'other';
end
end

function tf = matchesAny(matlabType, openmindsType, names)
tf = false;
for k = 1:numel(names)
    if endsWithSegment(matlabType, '.', names{k}) ...
            || endsWithSegment(openmindsType, '/', names{k})
        tf = true;
        return;
    end
end
end

function tf = endsWithSegment(str, sep, seg)
%ENDSWITHSEGMENT Does STR's last SEP-delimited segment equal SEG (case-folded)?
tf = false;
str = char(str);
if isempty(str); return; end
parts = strsplit(str, sep);
tf = strcmpi(strtrim(parts{end}), seg);
end
