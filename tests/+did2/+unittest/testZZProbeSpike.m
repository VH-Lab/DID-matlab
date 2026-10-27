function tests = testZZProbeSpike
% TEMPORARY probe (removed before the final push): prints what the spike family
% emits, as JSON, so the inverses can be written against the real output.
tests = functiontests(localfunctions);
end

function testProbe(testCase)
thisDir = fileparts(mfilename('fullpath'));
wo = fullfile(fileparts(thisDir), 'fixtures', 'ndi_writer_outputs');
h = jsondecode(fileread(fullfile(wo, 'hartley_calc.mock.1.json')));
n = 12;
h.hartley_reverse_correlation.frameTimes = h.hartley_reverse_correlation.frameTimes(1:n);
for f = {'S', 'KXV', 'KYV', 'ORDER'}
    h.hartley_reverse_correlation.hartley_numbers.(f{1}) = h.hartley_reverse_correlation.hartley_numbers.(f{1})(1:n);
end
pres = struct();
pres.document_class = struct('class_name', 'stimulus_presentation', 'class_version', 1, ...
    'superclasses', struct('definition', {'$NDIDOCUMENTPATH/base.json'}));
pres.depends_on = struct('name', {'stimulus_element_id'}, 'value', {'stim_1'});
pres.base = struct('id', h.depends_on(2).value, 'session_id', h.base.session_id, 'name', '', ...
    'datestamp', '2026-08-27T00:22:18.600Z');
sp = h.hartley_reverse_correlation.stimulus_properties;
pres.stimulus_presentation = struct('presentation_order', 1, 'stimuli', struct('parameters', struct( ...
    'rect', sp.rect, 'M', sp.M, 'K_absmax', sp.K_max, 'L_absmax', sp.L_max, 'sfmax', sp.sf_max, ...
    'chromhigh', sp.color_high, 'chromlow', sp.color_low, 'fps', sp.fps)));
s = jsondecode(fileread(fullfile(wo, 'speedtuning_calc.mock.1.json')));
cases = {'hartley', {h, pres}; 'speed', {s}; 'jrclust', {jrc()}; 'neuron', {neu()}; ...
    'neuron_corpusvintage', {neuCorpus()}};
for k = 1:size(cases, 1)
    for raw = [true false]
        if raw
            out = did2.convert.v1_to_v2(cases{k, 2}, 'Validate', false, 'TargetVersion', 'V_eta');
        else
            out = did2.convert.v1_to_v2(cases{k, 2}, 'Validate', false, 'TargetVersion', 'V_eta', 'RawV1Classes', {});
        end
        docs = cellfun(@(d) d.toStruct(), out.migrated, 'UniformOutput', false);
        fprintf('\nPROBEBEGIN %s raw=%d q=%d p=%d\n', cases{k, 1}, raw, numel(out.quarantine), numel(out.passthrough));
        for j = 1:numel(out.quarantine)
            fprintf('QUAR %s %s %s\n', out.quarantine(j).class_name, out.quarantine(j).identifier, out.quarantine(j).message);
        end
        if isfield(out.summary.migration_notes, 'carried_as_v1')
            fprintf('NOTE %s\n', strjoin(cellstr(out.summary.migration_notes.carried_as_v1.distinct_details), ' || '));
        end
        fprintf('%s\n', jsonencode(docs, 'ConvertInfAndNaN', false));
        fprintf('PROBEEND\n');
        if raw
            try
                v1in = cases{k, 2}{1};
                mine = out.migrated;
                if numel(cases{k, 2}) > 1
                    keep = cellfun(@(d) ~strcmp(d.get('document_class.class_name'), 'stimulus_presentation'), mine);
                    mine = mine(keep);
                end
                r = did2.convert.roundtrip.check(v1in, mine);
                fprintf('RT %s ok=%d lost=%s invented=%s unplaced=%s\n', cases{k, 1}, r.ok, ...
                    strjoin({r.lost.path}, ','), strjoin(r.invented, ','), strjoin(r.unplaced, ';'));
            catch err
                fprintf('RT %s ERROR %s\n', cases{k, 1}, err.message);
            end
        end
    end
end
verifyTrue(testCase, true);
end

function app = jrcApp()
app = struct('name', 'JRCLUST to ndi.fun.probe.import.jrclust', 'version', '4.1.0', ...
    'url', 'https://github.com/VH-Lab/JRCLUST', 'os', 'GLNXA64', 'os_version', '', ...
    'interpreter', 'MATLAB', 'interpreter_version', '24.2');
end

function d = jrc()
d = struct();
d.document_class = struct('definition', '$NDIDOCUMENTPATH/apps/jrclust/jrclust_clusters.json', ...
    'validation', '$NDISCHEMAPATH/apps/jrclust/jrclust_clusters_schema.json', ...
    'class_name', 'jrclust_clusters', 'property_list_name', 'jrclust_clusters', 'class_version', 1, ...
    'superclasses', struct('definition', {'$NDIDOCUMENTPATH/base.json', '$NDIDOCUMENTPATH/app.json'}));
d.depends_on = struct('name', 'element_id', 'value', 'probe_1');
d.base = struct('id', 'jc_1', 'session_id', 'sess_1', 'name', 'jrclust.prm', 'datestamp', '2026-08-27T00:22:18.600Z');
d.app = jrcApp();
d.jrclust_clusters = struct('res_mat_MD5_checksum', '0cc175b9c0f1b6a831c399e269772661');
d = jsondecode(jsonencode(d));
end

function d = neu()
d = struct();
d.document_class = struct('definition', '$NDIDOCUMENTPATH/neuron/neuron_extracellular.json', ...
    'validation', '$NDISCHEMAPATH/neuron/neuron_extracellular_schema.json', ...
    'class_name', 'neuron_extracellular', 'property_list_name', 'neuron_extracellular', 'class_version', 1, ...
    'superclasses', struct('definition', {'$NDIDOCUMENTPATH/base.json', '$NDIDOCUMENTPATH/app.json'}));
d.depends_on = struct('name', {'element_id', 'spike_clusters_id'}, 'value', {'neuron_el_1', 'jc_1'});
d.base = struct('id', 'ne_1', 'session_id', 'sess_1', 'name', '', 'datestamp', '2026-08-27T00:22:18.600Z');
d.app = jrcApp();
w = reshape(sin(1:(21*4)) * 100, 21, 4);
ne = struct();
ne.number_of_samples_per_channel = 21;
ne.number_of_channels = 4;
ne.mean_waveform = w;
ne.waveform_sample_times = (-5:15)' / 20000;
ne.cluster_index = 7;
ne.quality_number = 1;
ne.quality_label = 'single';
d.neuron_extracellular = ne;
d = jsondecode(jsonencode(d));
end

function d = neuCorpus()
d = neu();
d.depends_on(2).value = '';
d.neuron_extracellular.waveform_sample_times = [-0.00025;-0.0002;-0.00015;-0.0001;-5e-05;0;5e-05;0.0001;0.00015;0.0002;0.00025;0.0003;0.00035;0.0004;0.00045;0.0005;0.00055;0.0006;0.00065;0.0007;0.00075];
d.neuron_extracellular.quality_number = 4;
d.neuron_extracellular.quality_label = 'multi';
end
