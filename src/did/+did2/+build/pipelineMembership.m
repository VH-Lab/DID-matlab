function rels = pipelineMembership(pipelineId, programIds, options)
%PIPELINEMEMBERSHIP The ordered `member of` relations from a pipeline's programs to it.
%
%   RELS = did2.build.pipelineMembership(PIPELINEID, PROGRAMIDS, 'SessionId', SID)
%   builds one directed_relation per program: PROGRAMIDS{k} `member of`
%   (RO:0002350) PIPELINEID, with `order` k-1, so the first program run is
%   0 (Jess Haley, did-schema did_v2_go_forward_class_audit.md: [pipeline is a
%   software entity], 2026-11-06; [pipeline order counts from 0] and
%   [pipeline steps use member of], 2026-11-12: "Kilosort 0, Phy 1, the NDI
%   importer 2"). RELS is a cell array in program order.
%
%   PIPELINEID is the id of the pipeline `software` entity; PROGRAMIDS a
%   cellstr of the program `software` entities' ids, in the order the
%   programs ran (at least one, no repeats). The statements a run produces
%   point at the pipeline by their single `software_id`. Check the finished
%   set with did2.build.checkPipelineMembers.
%
%   Options:
%     'SessionId' (required), 'Validate', 'SchemaCache' -- as
%     did2.build.directedRelation.
%
%   See also did2.build.checkPipelineMembers, did2.build.directedRelation.

arguments
    pipelineId (1,:) char
    programIds
    options.SessionId (1,:) char = ''
    options.Validate (1,1) logical = true
    options.SchemaCache = []
end

programIds = cellstr(programIds);
if isempty(programIds) || any(cellfun(@isempty, programIds))
    error('did2:build:badOption', ...
        'pipelineMembership: PROGRAMIDS lists the pipeline''s programs, at least one, none blank.');
end
if numel(unique(programIds)) ~= numel(programIds)
    error('did2:build:badOption', ...
        'pipelineMembership: a program appears more than once in PROGRAMIDS.');
end
if any(strcmp(programIds, pipelineId))
    error('did2:build:badOption', ...
        'pipelineMembership: the pipeline cannot be one of its own programs.');
end
relation = did2.build.term(did2.build.vocabulary('relation', 'member_of'), 'member of');
rels = cell(1, numel(programIds));
for k = 1:numel(programIds)
    rels{k} = did2.build.directedRelation(programIds{k}, pipelineId, relation, ...
        'Order', k - 1, 'SessionId', options.SessionId, ...
        'Validate', options.Validate, 'SchemaCache', options.SchemaCache);
end
end
