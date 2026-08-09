%SCRATCH Ad-hoc MATLAB probe, run by .github/workflows/matlab-scratch.yml.
%
%   PROBE 2 (#79): the first probe established that the schema's `depends_on`
%   decodes to a CELL and that `min_count` survives on the numbered family. So
%   the reverted counter should have worked. Run its logic here, step by step,
%   printing every intermediate, instead of inferring.

cache = did2.schema.cache.shared();
className = 'voltage_observation';

fprintf('=== walk the chain looking for numbered families ===\n');
chain = cache.classChain(className);
fams = struct('name', {}, 'min_count', {}, 'max_count', {});
for k = 1:numel(chain)
    try
        c = cache.getClass(chain{k});
    catch ME
        fprintf('  getClass(%s) THREW: %s\n', chain{k}, ME.message);
        continue;
    end
    if ~isfield(c, 'depends_on')
        fprintf('  %-24s no depends_on field\n', chain{k});
        continue;
    end
    deps = c.depends_on;
    if isstruct(deps)
        items = num2cell(deps(:)');
    elseif iscell(deps)
        items = deps(:)';
    else
        fprintf('  %-24s depends_on is %s -- skipped\n', chain{k}, class(deps));
        continue;
    end
    fprintf('  %-24s %d dep(s), class %s\n', chain{k}, numel(items), class(deps));
    for d = 1:numel(items)
        dep = items{d};
        if ~isstruct(dep) || ~isfield(dep, 'name'); continue; end
        n = char(dep.name);
        if ~contains(n, '#'); continue; end
        lo = 0; hi = NaN;
        if isfield(dep, 'min_count') && ~isempty(dep.min_count); lo = double(dep.min_count); end
        if isfield(dep, 'max_count') && ~isempty(dep.max_count); hi = double(dep.max_count); end
        fprintf('      FAMILY %s  lo=%g hi=%g\n', n, lo, hi);
        if any(strcmp({fams.name}, n))
            fprintf('        (already seen -- skipping)\n');
            continue;
        end
        try
            fams(end+1) = struct('name', n, 'min_count', lo, 'max_count', hi); %#ok<AGROW>
        catch ME
            fprintf('        APPEND THREW: %s / %s\n', ME.identifier, ME.message);
        end
    end
end
fprintf('families found: %d\n', numel(fams));

fprintf('\n=== count instances on a no-edge body ===\n');
b = struct();
b.document_class = struct('class_name', className, 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}), ...
    'schema_version', 'V_eta');
b.depends_on = struct('name', {}, 'value', {});
b.base = struct('id', 'probe_1', 'session_id', 'sess_1', 'name', 'probe_1', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
doc = did2.document(b);
body = doc.documentProperties;

for f = 1:numel(fams)
    fam = fams(f);
    n = 0;
    if isfield(body, 'depends_on') && isstruct(body.depends_on)
        prefix = strrep(fam.name, '#', '');
        for k = 1:numel(body.depends_on)
            nm = char(body.depends_on(k).name);
            if startsWith(nm, prefix)
                tail = nm(numel(prefix)+1:end);
                if ~isempty(tail) && all(isstrprop(tail, 'digit')); n = n + 1; end
            end
        end
    end
    bad = n < fam.min_count || (~isnan(fam.max_count) && n > fam.max_count);
    fprintf('  %-20s found=%d  min=%g  VIOLATION=%d\n', fam.name, n, fam.min_count, bad);
end

fprintf('\nDONE\n');
