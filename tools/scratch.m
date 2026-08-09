%SCRATCH Ad-hoc MATLAB probe, run by .github/workflows/matlab-scratch.yml.
%
%   The dev container has no MATLAB, so this file plus that workflow are how a
%   value gets LOOKED AT rather than guessed. Overwrite it freely; it gates
%   nothing and runs only on manual dispatch.
%
%   CURRENT PROBE: #79 -- why did the numbered-family count come out 0?
%   The schema declares subject_interaction.time_reference_# with min_count 1, and
%   a document carrying no such edge should have been reported. It was not, and
%   the failure survived the fix for the [deps{:}] throw. So: print what the cache
%   actually returns, one layer at a time, instead of reasoning about it.

fprintf('=== schema path ===\n%s\n\n', getenv('DID_SCHEMA_PATH'));

cache = did2.schema.cache.shared();

fprintf('=== classChain(voltage_observation) ===\n');
chain = cache.classChain('voltage_observation');
disp(chain(:)');

fprintf('\n=== subject_interaction raw depends_on ===\n');
c = cache.getClass('subject_interaction');
d = c.depends_on;
fprintf('class of depends_on : %s\n', class(d));
fprintf('numel               : %d\n', numel(d));
if isstruct(d)
    fprintf('fieldnames          : %s\n', strjoin(fieldnames(d)', ', '));
    for k = 1:numel(d)
        fprintf('  [%d] name=%s  mustBeNonEmpty=%d  hasMin=%d\n', k, d(k).name, ...
            d(k).mustBeNonEmpty, isfield(d(k), 'min_count'));
        if isfield(d(k), 'min_count')
            fprintf('       min_count = %s (class %s, isempty=%d)\n', ...
                mat2str(d(k).min_count), class(d(k).min_count), isempty(d(k).min_count));
        end
    end
elseif iscell(d)
    for k = 1:numel(d)
        e = d{k};
        fprintf('  [%d] name=%s  fields=%s\n', k, e.name, strjoin(fieldnames(e)', ','));
    end
end

fprintf('\n=== what a no-edge voltage_observation body looks like ===\n');
b = struct();
b.document_class = struct('class_name', 'voltage_observation', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}), ...
    'schema_version', 'V_eta');
b.depends_on = struct('name', {}, 'value', {});
b.base = struct('id', 'probe_1', 'session_id', 'sess_1', 'name', 'probe_1', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
doc = did2.document(b);
props = doc.documentProperties;
fprintf('documentProperties depends_on class : %s, numel %d\n', ...
    class(props.depends_on), numel(props.depends_on));
fprintf('document_class.class_name           : %s\n', props.document_class.class_name);

fprintf('\n=== silentLoss on it ===\n');
rep = did2.validate.silentLoss({doc});
disp(rep);
fprintf('\nDONE\n');
