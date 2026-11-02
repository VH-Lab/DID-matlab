%SCRATCH PROBE (agent R, not for merge): what did2.convert.ensureClassBlocks
%   changes on each converted body, by v1 class, on corpora 20211116, B, JH.
global RDUMP;
classes = {'syncrule','element_epoch','stimulus_response_scalar_parameters_basic', ...
    'stimulus_response_scalar','epochfiles_ingested','daqreader_mfdaq_epochdata_ingested','openminds'};
corpora = {'20211116','B','JH'};
for c = 1:numel(corpora)
    z = fullfile(tempdir, [corpora{c} '.zip']);
    websave(z, ['https://ndi-programming-development.s3.us-east-1.amazonaws.com/' corpora{c} '.zip']);
    d = fullfile(tempdir, corpora{c}); unzip(z, d);
    files = dir(fullfile(d, '**', '*.json'));
    taken = containers.Map();
    sel = {};
    for k = 1:numel(files)
        txt = fileread(fullfile(files(k).folder, files(k).name));
        m = regexp(txt, '"class_name"\s*:\s*"([^"]+)"', 'tokens', 'once');
        if isempty(m) || ~any(strcmp(m{1}, classes)); continue; end
        n = 0; if isKey(taken, m{1}); n = taken(m{1}); end
        lim = 4; if any(strcmp(m{1}, {'syncrule','openminds'})); lim = 30; end
        if n >= lim; continue; end
        taken(m{1}) = n + 1;
        sel{end+1} = jsondecode(txt); %#ok<SAGROW>
    end
    fprintf('\n######## CORPUS %s: %d sample documents\n', corpora{c}, numel(sel));
    for k = 1:numel(sel)
        RDUMP = {};
        r = did2.convert.v1_to_v2(sel{k}, 'Validate', true);
        cn = sel{k}.document_class.class_name;
        fprintf('\n== %s %s: migrated %d quarantined %d emitted-changed-by-pad %d\n', cn, ...
            sel{k}.base.id, r.summary.migrated_count, r.summary.quarantine_count, numel(RDUMP));
        if r.summary.quarantine_count > 0
            q = r.quarantine(1); try, fprintf('   Q: %s\n', q.error.message); catch, disp(q); end
        end
        for j = 1:numel(RDUMP)
            a = RDUMP{j}{2}; b = RDUMP{j}{3};
            fa = fieldnames(a); fb = fieldnames(b);
            fprintf('  -> emitted %s | added: [%s] dropped: [%s]', b.document_class.class_name, ...
                strjoin(setdiff(fb, fa)', ','), strjoin(setdiff(fa, fb)', ','));
            ch = {};
            for f = intersect(fa, fb)'
                if ~isequaln(a.(f{1}), b.(f{1})); ch{end+1} = f{1}; end %#ok<AGROW>
            end
            fprintf(' changed: [%s]\n', strjoin(ch, ','));
            if any(strcmp(ch, 'document_class'))
                fprintf('     dc before: %s\n     dc after:  %s\n', jsonencode(a.document_class), jsonencode(b.document_class));
            end
            for f = setdiff(fb, fa)'
                fprintf('     added %s = %s\n', f{1}, jsonencode(b.(f{1})));
            end
            for f = setdiff(fa, fb)'
                fprintf('     dropped %s = %s\n', f{1}, jsonencode(a.(f{1})));
            end
        end
    end
end
