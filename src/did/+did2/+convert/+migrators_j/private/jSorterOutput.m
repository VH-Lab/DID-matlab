function bodies = jSorterOutput(preBody, sorterName, dirField)
%JSORTEROUTPUT Decompose a spike-sorting RUN output into the D-C analysis-tier
%   shape. Shared by the external-directory sorter classes (kilosort_clusters,
%   kiasort_clusters) whose doc holds a session-relative output DIRECTORY + a
%   curated-output MD5 rather than attached bytes:
%
%     count_observation           the id-preserved discoverable handle on the
%                                 recording subject (variable 'spike cluster
%                                 assignment', subject_interaction.method = the
%                                 sorter algorithm, storage_mode 'body'). Its id
%                                 IS the source doc id, so any inbound reference
%                                 to the sorter-output doc resolves to it.
%     opaque_body                 the unparsed sorter output directory -- an
%                                 uninterpreted blob (we do not read the sorter
%                                 output at migration time): filename = the
%                                 session-relative directory; description carries
%                                 the curated-output MD5; statement -> the obs.
%     session_relative_reference  the 'during' anchor.
%
%   1 -> 3. Sibling of migrators_j.jrclust_clusters (same family, same handle),
%   but jrclust attaches the *_res.mat BYTES -> a sampled_body, while these carry
%   an EXTERNAL directory -> an opaque_body. The MD5 is a regenerable file hash,
%   kept as a body note rather than re-expressed as data.
%
%   sorterName   the algorithm name for subject_interaction.method (e.g. 'kilosort').
%   dirField     the block field holding the output directory path (e.g.
%                'kilosort_directory').
%
%   Shared helper for the Brainstorm-J (+migrators_j) split migrators.

className = '';
if isfield(preBody, 'document_class') && isstruct(preBody.document_class) ...
        && isfield(preBody.document_class, 'class_name')
    className = char(preBody.document_class.class_name);
end
blk = struct();
if ~isempty(className) && isfield(preBody, className) && isstruct(preBody.(className))
    blk = preBody.(className);
end

directory = jGetChar(blk, dirField);
md5 = jGetCharAny(blk, {'curated_output_md5_checksum', 'curated_output_MD5_checksum'});

% ---- the id-preserved count_observation handle (the run) --------------------
obs = jStartInteraction(preBody, 'count_observation', 'subject_observation', ...
    {'count'}, jOntologyTerm('', 'spike cluster assignment'), ...
    {'element_id', 'subject_id'}, false);
obs.subject_statement.storage_mode = 'body';
obs.subject_interaction.method = jOntologyTerm('', sorterName);   % method = algorithm
obs.count = struct();   % value is body-backed (the opaque sorter output)
obsId = obs.base.id;

% ---- the session-relative 'during' anchor -----------------------------------
anchor = jSessionAnchor(preBody, 'during');
obs.depends_on(end+1) = struct('name', 'time_reference_1', 'value', anchor.base.id);

% ---- the opaque_body: the external sorter output directory -------------------
sessionId = '';
datestamp = '2024-01-01T00:00:00.000Z';
if isfield(preBody, 'base') && isstruct(preBody.base)
    if isfield(preBody.base, 'session_id'); sessionId = preBody.base.session_id; end
    if isfield(preBody.base, 'datestamp') && ~isempty(preBody.base.datestamp)
        datestamp = preBody.base.datestamp;
    end
end
descr = sprintf('%s sorter output directory', sorterName);
if ~isempty(md5)
    descr = sprintf('%s (curated_output_md5_checksum: %s)', descr, md5);
end
body = struct();
body.document_class = struct('class_name', 'opaque_body', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'data_body', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
body.depends_on = struct('name', {'statement'}, 'value', {obsId});
body.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', sprintf('migrated_%s_output', sorterName), 'datestamp', datestamp);
body.opaque_body = struct('format', 'directory', ...
    'filename', directory, 'description', descr);
% carry any attached output bytes verbatim (the external directory is the usual
% case, but a doc that ships files owns them on this body now).
if isfield(preBody, 'files'); body.files = preBody.files; end
if isfield(preBody, 'file');  body.file  = preBody.file;  end

bodies = {obs, body, anchor};
end
