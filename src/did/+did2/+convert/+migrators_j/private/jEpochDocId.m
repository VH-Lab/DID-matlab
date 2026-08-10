function epochDocId = jEpochDocId(preBody)
%JEPOCHDOCID The `epoch` DOCUMENT id this body is scoped to, or '' if unknown.
%
%   V_eta reifies the epoch as a document (`epoch` -- entity, local_identifier
%   REQUIRED, session_id REQUIRED). Every class that used to carry the did_v1
%   `epochid` SUPERCLASS -- a bare string such as 't00001' -- gains an `epoch_id`
%   EDGE to that document instead (the rule recorded in CLAUDE.md: "epoch -- the
%   document IS the fact and the string was only ever a way to find it").
%
%   ---------------------------------------------------------------------
%   THIS RETURNS '' FOR EVERY did_v1 DOCUMENT TODAY, BY CONSTRUCTION
%   ---------------------------------------------------------------------
%   Two independent reasons, both checked rather than assumed:
%
%   1. NO SOURCE DOCUMENT CARRIES THE EDGE. All three ingest templates on NDI
%      `origin/main` declare exactly ONE dependency each:
%
%        git show origin/main:src/ndi/ndi_common/database_documents/ingestion/\
%            daqreader_epochdata_ingested.json
%           "depends_on": [ { "name": "daqreader_id", "value": "" } ]
%        ...daqmetadatareader_epochdata_ingested.json
%           "depends_on": [ { "name": "daqmetadatareader_id", "value": "" } ]
%        ...daqreader_image_epochdata_ingested.json
%           "depends_on": [ { "name": "daqreader_id", "value": "" } ]
%
%      The epoch is joined by the STRING `epochid.epochid`, not by an edge --
%      which is exactly why the epoch model reifies it.
%
%   2. NO MIGRATOR MINTS AN `epoch` DOCUMENT. Swept across the whole toolbox:
%
%        grep -rn "classBlock('epoch'\|class_name', 'epoch'" \
%             --include=*.m /home/user/DID-matlab/src/did
%           (no output -- 0 matches)
%
%      Minting one per SOURCE DOCUMENT is not the fix: several documents share
%      one epoch, so a per-document mint produces duplicate epoch entities. Open
%      item #60 records the correct shape -- "mint one `epoch` per distinct
%      `epochid.epochid` by GROUPING (a second pass -- a single-document migrator
%      cannot see the group)".
%
%   So this helper is the SWITCH the ingested-payload migrators are guarded on.
%   Until #60's migrator half lands it answers '', every one of them passes its
%   document through intact, and NOTHING emits a required edge it cannot fill --
%   the failure mode that put 26,406 documents into the invented-empty-edge
%   census while validating clean (`+did2/+validate/references.m:90` skips empty
%   edges). The day the epoch pass stamps an `epoch_id` edge, these migrators
%   convert with no further change; the tests drive both branches.
%
%   Shared helper for the Brainstorm-J (+migrators_j) ingested-payload migrators.

epochDocId = '';
if ~isfield(preBody, 'depends_on') || ~isstruct(preBody.depends_on)
    return;
end
deps = preBody.depends_on;
for k = 1:numel(deps)
    d = deps(k);
    if ~isfield(d, 'name') || ~strcmp(char(d.name), 'epoch_id')
        continue;
    end
    % Read tolerantly: a raw migrator body spells the target `value`, a body that
    % has been through did2.convert.universalRenames spells it `document_id`, and
    % an unconverted v1 body spells it `id`.
    for key = {'document_id', 'value', 'id'}
        f = key{1};
        if isfield(d, f) && ~isempty(d.(f))
            epochDocId = char(d.(f));
            return;
        end
    end
    return;
end
end
