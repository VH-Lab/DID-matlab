function body = jStartInteraction(preBody, className, directionClass, mixinSupers, variable, subjectSrc, freshId)
%JSTARTINTERACTION Seed a V_eta subject_interaction leaf (observation or
%   manipulation) with the Brainstorm-J spine:
%
%     document_class    header (schema_version 'V_eta'); superclasses are the
%                       DIRECT ones -- the direction class plus any shape mixin
%                       (e.g. dose_manipulation -> {subject_manipulation, dose}).
%     depends_on        the carried subject_id (time_reference added by caller).
%     base              the source base; a fresh id is minted when freshId=true
%                       (a secondary sibling) and kept otherwise (the primary
%                       body of the split).
%     subject_statement variable (the queryable "what") + storage_mode='inline'.
%     subject_interaction  method (blank -- the leaf class already names the act)
%                       + a single-point sample_time cadence (D1).
%     <direction>       an empty subject_observation / subject_manipulation block
%                       (manipulation carries `notes`, filled by the caller).
%
%   className      the leaf class (e.g. 'dose_manipulation', 'term_observation').
%   directionClass 'subject_observation' or 'subject_manipulation'.
%   mixinSupers    extra direct superclasses (shape mixin), e.g. {'dose'} or {}.
%   variable       the spine identity ontology_term.
%   subjectSrc     cell of candidate did_v1 depends_on names for the subject.
%   freshId        true to mint a new base id (secondary sibling body).
%
%   Shared helper for the Brainstorm-J (+migrators_j) split migrators.
if nargin < 6 || isempty(subjectSrc); subjectSrc = {'subject_id'}; end
if nargin < 7 || isempty(freshId);    freshId = false; end

chain = [{directionClass}, mixinSupers];
supers = struct('class_name', {}, 'class_version', {});
for k = 1:numel(chain)
    supers(end+1) = struct('class_name', chain{k}, 'class_version', '1.0.0'); %#ok<AGROW>
end

body = struct();
body.document_class = struct('class_name', className, 'class_version', '1.0.0', ...
    'superclasses', supers, 'schema_version', 'V_eta');
body.depends_on = jCarrySubject(preBody, subjectSrc);
if isfield(preBody, 'base') && isstruct(preBody.base)
    body.base = preBody.base;
    if freshId
        body.base.id = did.ido.unique_id();
    end
end
body.subject_statement = struct('variable', variable, 'storage_mode', 'inline');
body.subject_interaction = struct('method', jOntologyTerm('', ''), ...
    'sample_time', struct('kind', 'point'));
body.(directionClass) = struct();
if strcmp(directionClass, 'subject_manipulation')
    body.subject_manipulation = struct('notes', '');
end
end
