function tests = testMigratorsJMethodParams
%TESTMIGRATORSJMETHODPARAMS The spike-processing-parameters family -> ONE
%   `method_parameters` class (TargetVersion 'V_eta').
%
%   Four did_v1 settings classes fold into one generic document
%   (TEAM-SIGN-OFF 2026-08-09, did-schema/schemas/V_eta_method_parameters_plan.md):
%
%     spike_extraction_parameters               a GLOBAL protocol, no v1 edges
%     spike_extraction_parameters_modification  the same 15 fields + scope +
%                                               lineage (v1 stores a FULL copy,
%                                               never a diff)
%     sorting_parameters                        a GLOBAL protocol, no bound
%                                               variables by decision
%     vmspikefilteringparameters                folds ONLY when `spiketimes`
%                                               (OUTPUT data in a config class)
%                                               is empty
%
%   THE FIXTURES ARE THE NDI TEMPLATES, FIELD FOR FIELD. Every body below was
%   transcribed from `git show origin/main:<path>` in NDI-matlab, not from a
%   DID-side schema -- fixtures built from our own schema are how a migrator
%   comes to read fields no real document has (V_eta_ground_truth_plan.md), and
%   this family already had one instance of that: vmspikefilteringparameters'
%   old tombstone declared `filter_type`/`filter_window`, neither of which the
%   template has.
%
%     .../database_documents/apps/spikeextractor/spike_extraction_parameters.json
%     .../database_documents/apps/spikeextractor/spike_extraction_parameters_modification.json
%     .../database_documents/apps/spikesorter/sorting_parameters.json
%     .../database_documents/apps/vhlab_voltage2firingrate/vmspikefilteringparameters.json
%
%   Most tests run with Validate=false so they assert the TRANSFORM without
%   needing a V_eta schema cache; testMethodParametersValidatesAgainstItsSchema
%   turns validation ON, because "the fold and the schema agree" is not
%   something the other tests can prove.
%
%   Do not merge these into testMigratorsJ -- that file is being edited
%   concurrently.
%
%   Run with:  results = runtests('did2.unittest.testMigratorsJMethodParams');

tests = functiontests(localfunctions);
end

% ===================== harness =============================================

function out = runJ(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
end

function d = onlyClass(testCase, out, className)
%ONLYCLASS The single migrated document of CLASSNAME (fails if not exactly one).
d = [];
n = 0;
for k = 1:numel(out.migrated)
    if strcmp(out.migrated{k}.get('document_class.class_name'), className)
        d = out.migrated{k};
        n = n + 1;
    end
end
verifyEqual(testCase, n, 1, sprintf('expected exactly one %s document', className));
end

function v = depValue(doc, name)
% READ THE EDGE TOLERANTLY. A depends_on entry is spelled `value` on a body a
% migrator built and `document_id` once did2.convert.universalRenames has
% normalised it (universalRenames.m:369-422); BOTH shapes are live on this path,
% because a fold builds its edges while a passthrough's came through the rename.
% Precedence copied from +did2/+validate/references.m -- document_id first, then
% value. Reading one spelling broke two tests in testMigratorsJ already.
v = '';
s = doc;
if isa(doc, 'did2.document')
    s = doc.toStruct();
end
if ~isfield(s, 'depends_on') || isempty(s.depends_on)
    return;
end
for k = 1:numel(s.depends_on)
    d = s.depends_on(k);
    if ~isfield(d, 'name') || ~strcmp(char(d.name), name)
        continue;
    end
    if isfield(d, 'document_id') && ~isempty(d.document_id)
        v = char(d.document_id);
    elseif isfield(d, 'value') && ~isempty(d.value)
        v = char(d.value);
    end
    return;
end
end

function names = edgeNames(doc)
names = {};
s = doc;
if isa(doc, 'did2.document')
    s = doc.toStruct();
end
if ~isfield(s, 'depends_on') || isempty(s.depends_on)
    return;
end
for k = 1:numel(s.depends_on)
    names{end+1} = char(s.depends_on(k).name); %#ok<AGROW>
end
end

function e = paramEntry(testCase, doc, variableName)
%PARAMENTRY The one `parameter` row whose bound variable is VARIABLENAME.
list = doc.get('method_parameters.method_parameters');
e = [];
for k = 1:numel(list)
    if strcmp(list(k).variable.name, variableName)
        e = list(k);
        return;
    end
end
verifyFail(testCase, sprintf('no parameter entry for variable "%s"', variableName));
end

function names = paramVariables(doc)
list = doc.get('method_parameters.method_parameters');
names = {};
for k = 1:numel(list)
    names{end+1} = list(k).variable.name; %#ok<AGROW>
end
end

% ===================== fixtures: the NDI templates =========================

function v1 = extractionBody(id, name, sessionId)
% spike_extraction_parameters.json, verbatim: superclasses base + app, NO
% depends_on key at all, and the fifteen settings with the template's defaults.
v1 = struct();
v1.document_class = struct('class_name', 'spike_extraction_parameters', ...
    'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base', 'class_version', '1.0.0'), ...
                      struct('class_name', 'app',  'class_version', '1.0.0')]);
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct('id', id, 'session_id', sessionId, 'name', name, ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.app = appBlock();
v1.spike_extraction_parameters = extractionSettings();
end

function s = extractionSettings()
s = struct( ...
    'center_range_time',   0.0005, ...
    'overlap',             0.5, ...
    'read_time',           30, ...
    'refractory_time',     0.001, ...
    'spike_start_time',    -0.00045, ...
    'spike_end_time',      0.001, ...
    'do_filter',           1, ...
    'filter_type',         'cheby1high', ...
    'filter_low',          0, ...
    'filter_high',         300, ...
    'filter_order',        4, ...
    'filter_ripple',       0.8, ...
    'threshold_method',    'standard_deviation', ...
    'threshold_parameter', -4, ...
    'threshold_sign',      -1);
end

function a = appBlock()
% ndi.app/newdocument (src/ndi/+ndi/app.m:105-114) fills all seven. The v1 field
% names are `name`/`version`; did2.convert.universalRenames rewrites them to
% `app_name`/`app_version` before the migrator sees them, so the fixture uses
% the v1 spelling and lets the rename happen -- testing the real path.
a = struct('name', 'ndi_app_spikeextractor', 'version', '1.2.3', ...
    'url', 'https://github.com/VH-Lab/NDI-matlab', ...
    'os', 'MACA64', 'os_version', '14.5', ...
    'interpreter', 'MATLAB', 'interpreter_version', '24.1');
end

function v1 = modificationBody(id, name, sessionId, baseParamsId, elementId, epochString)
% spike_extraction_parameters_modification.json + WHAT THE WRITER ADDS. The
% template declares superclasses base + app and NO epochid, but
% spikeextractor.m:309-313 sets 'epochid.epochid' on every one it writes -- so
% the fixture carries the epochid block. Where template and writer disagree, the
% writer wins.
v1 = struct();
v1.document_class = struct('class_name', 'spike_extraction_parameters_modification', ...
    'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base', 'class_version', '1.0.0'), ...
                      struct('class_name', 'app',  'class_version', '1.0.0')]);
v1.depends_on = [ ...
    struct('name', 'extraction_parameters_id', 'value', baseParamsId), ...
    struct('name', 'element_id',               'value', elementId)];
v1.base = struct('id', id, 'session_id', sessionId, 'name', name, ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.app = appBlock();
v1.epochid = struct('epochid', epochString);
v1.spike_extraction_parameters_modification = extractionSettings();
end

function v1 = sortingBody(id, name, sessionId)
% sorting_parameters.json, verbatim: base + app, no depends_on, six knobs.
v1 = struct();
v1.document_class = struct('class_name', 'sorting_parameters', ...
    'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base', 'class_version', '1.0.0'), ...
                      struct('class_name', 'app',  'class_version', '1.0.0')]);
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct('id', id, 'session_id', sessionId, 'name', name, ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.app = struct('name', 'ndi_app_spikesorter', 'version', '1.2.3', ...
    'url', '', 'os', 'MACA64', 'os_version', '14.5', ...
    'interpreter', 'MATLAB', 'interpreter_version', '24.1');
v1.sorting_parameters = struct('graphical_mode', 1, 'num_pca_features', 10, ...
    'interpolation', 3, 'min_clusters', 3, 'max_clusters', 10, 'num_start', 5);
end

function v1 = vmspikeBody(id, sessionId, elementId, epochString, spiketimes)
% vmspikefilteringparameters.json, verbatim -- INCLUDING the two shapes that
% look like mistakes and are not: `threshold` is the STRING "0.030" (its own
% schema_documents pair calls it a number), and `rm60Hz` is camelCase, which
% universalRenames turns into `rm60_hz`.
v1 = struct();
v1.document_class = struct('class_name', 'vmspikefilteringparameters', ...
    'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base',    'class_version', '1.0.0'), ...
                      struct('class_name', 'epochid', 'class_version', '1.0.0'), ...
                      struct('class_name', 'app',     'class_version', '1.0.0')]);
v1.depends_on = struct('name', 'element_id', 'value', elementId);
v1.base = struct('id', id, 'session_id', sessionId, 'name', 'vmfilter', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.app = struct('name', 'vhlab_voltage2firingrate', 'version', '0.9', ...
    'url', '', 'os', 'MACA64', 'os_version', '14.5', ...
    'interpreter', 'MATLAB', 'interpreter_version', '24.1');
v1.epochid = struct('epochid', epochString);
v1.vmspikefilteringparameters = struct( ...
    'sampling_rate',     0, ...
    'new_sampling_rate', 0, ...
    'threshold',         '0.030', ...
    'spiketimes',        spiketimes, ...
    'filter_algorithm',  '0', ...
    'filter_algorithm_parameters', struct( ...
        'filter_algorithm_parameter_name',  '', ...
        'filter_algorithm_parameter_value', ''), ...
    'rm60Hz',            1, ...
    'refract',           0.0025);
end

% ===================== spike_extraction_parameters =========================

function testExtractionFoldsToMethodParametersPreservingIdAndName(testCase)
% THE LOAD-BEARING ASSERTION OF THE WHOLE FAMILY. base.id is pointed at by three
% NDI templates (spikewaves, spike_clusters, and the _modification class) and
% base.name is queried by exact_string at spikeextractor.m:372, so a fold that
% moved either would break consumers that pass through untouched in pass 1.
out = runJ(extractionBody('sep_1', 'default', 'sess_A'));
verifyEmpty(testCase, out.quarantine);
d = onlyClass(testCase, out, 'method_parameters');
verifyEqual(testCase, d.get('document_class.schema_version'), 'V_eta');
verifyEqual(testCase, d.get('base.id'), 'sep_1');
verifyEqual(testCase, d.get('base.name'), 'default');
% and again on the declared field that exists for that query
verifyEqual(testCase, d.get('method_parameters.name'), 'default');
end

function testExtractionEmitsTheFourBoundVariables(testCase)
% Exactly the four the plan names -- "threshold, refractory period, waveform
% window start and duration". Not five: promoting a fifth (threshold_sign is the
% obvious candidate) would be a modelling decision, and only the team makes
% those. If this list grows, the plan has to have grown first.
d = onlyClass(testCase, runJ(extractionBody('sep_2', 'default', 'sess_A')), ...
    'method_parameters');
verifyEqual(testCase, sort(paramVariables(d)), sort({ ...
    'refractory period', 'waveform window start', ...
    'waveform window duration', 'standard-deviation threshold'}));
end

function testExtractionRefractoryPeriodUnifiesWithVmspikeRefract(testCase)
% The losslessness win the extraction exists for: refractory_time (0.001) and
% vmspikefilteringparameters.refract (0.0025) are two v1 names for ONE concept,
% and after the fold a query can see that. Asserted here on both sides at once.
dExtract = onlyClass(testCase, runJ(extractionBody('sep_3', 'default', 'sess_A')), ...
    'method_parameters');
dVm = onlyClass(testCase, runJ(vmspikeBody('vm_3', 'sess_A', 'elem_1', 't00001', '')), ...
    'method_parameters');
a = paramEntry(testCase, dExtract, 'refractory period');
b = paramEntry(testCase, dVm, 'refractory period');
verifyEqual(testCase, a.value.value, 0.001, 'AbsTol', 1e-12);
verifyEqual(testCase, b.value.value, 0.0025, 'AbsTol', 1e-12);
verifyEqual(testCase, a.variable.name, b.variable.name);
end

function testExtractionWaveformWindowIsAnchorPlusExtent(testCase)
% ANSWER 1 of the sign-off review: start + DURATION, not start + end -- the same
% interval shape the signed time_reference model uses, so one spelling spans
% V_eta. `end` is exactly recoverable (start + duration = 0.001) and is
% deliberately NOT stored, which is why `waveform window end` must be absent.
d = onlyClass(testCase, runJ(extractionBody('sep_4', 'default', 'sess_A')), ...
    'method_parameters');
st = paramEntry(testCase, d, 'waveform window start');
du = paramEntry(testCase, d, 'waveform window duration');
verifyEqual(testCase, st.value.value, -0.00045, 'AbsTol', 1e-12);
verifyEqual(testCase, du.value.value, 0.00145, 'AbsTol', 1e-12);
verifyEqual(testCase, st.value.value + du.value.value, 0.001, 'AbsTol', 1e-12);
verifyFalse(testCase, any(strcmp(paramVariables(d), 'waveform window end')));
% the source's own spelling is kept for the recorded number, and is EMPTY for
% the computed one -- v1 recorded an end, not a duration.
verifyEqual(testCase, st.value.source_value, '-0.00045');
verifyEqual(testCase, du.value.source_value, '');
end

function testExtractionSourceUnitIsEmptyBecauseV1RecordsNone(testCase)
% `source_unit` records what the SOURCE wrote, and no template in this family
% writes a unit for any field. The canonical value is seconds -- read off
% spikeextractor.m:140-143, which multiplies these numbers by sample_rate to get
% samples -- but that is the REGISTRY's business, not source provenance.
% Claiming source_unit 's' would put a unit in the record v1 never recorded.
d = onlyClass(testCase, runJ(extractionBody('sep_5', 'default', 'sess_A')), ...
    'method_parameters');
verifyEqual(testCase, paramEntry(testCase, d, 'refractory period').value.source_unit, '');
verifyEqual(testCase, paramEntry(testCase, d, 'waveform window start').value.source_unit, '');
end

function testExtractionThresholdSplitsByMethodStandardDeviation(testCase)
% The threshold splits into TWO variables and the method field disappears into
% that choice. A standard-deviation multiple and an absolute level are not the
% same quantity; making the dimension depend on a sibling `threshold_method`
% field is the same mistake as a `unit` field.
d = onlyClass(testCase, runJ(extractionBody('sep_6', 'default', 'sess_A')), ...
    'method_parameters');
e = paramEntry(testCase, d, 'standard-deviation threshold');
verifyEqual(testCase, e.value.value, -4, 'AbsTol', 1e-12);
verifyEqual(testCase, e.value.source_value, '-4');
% consumed into the variable, so it must NOT also sit in the bag
bag = d.get('method_parameters.other');
verifyFalse(testCase, isfield(bag, 'threshold_method'));
verifyFalse(testCase, isfield(bag, 'threshold_parameter'));
end

function testExtractionThresholdSplitsByMethodAbsolute(testCase)
% The writer enumerates exactly two methods and errors on anything else
% (spikeextractor.m:211-225), so 'absolute' is the other half of a CLOSED set --
% and it lands on the same variable vmspikefilteringparameters.threshold uses.
v1 = extractionBody('sep_7', 'default', 'sess_A');
v1.spike_extraction_parameters.threshold_method = 'absolute';
v1.spike_extraction_parameters.threshold_parameter = -0.05;
d = onlyClass(testCase, runJ(v1), 'method_parameters');
e = paramEntry(testCase, d, 'absolute voltage threshold');
verifyEqual(testCase, e.value.value, -0.05, 'AbsTol', 1e-12);
verifyFalse(testCase, any(strcmp(paramVariables(d), 'standard-deviation threshold')));
end

function testUnknownThresholdMethodIsNotGivenADimension(testCase)
% THE SAFE BRANCH, and the reason it exists. A third method value cannot be
% given a dimension without inventing one, so no bound entry is emitted and BOTH
% fields survive verbatim in the bag. Unreachable for any document NDI itself
% can read; it exists so a hand-written document cannot make this migrator
% assert a quantity it does not know.
v1 = extractionBody('sep_8', 'default', 'sess_A');
v1.spike_extraction_parameters.threshold_method = 'median_absolute_deviation';
d = onlyClass(testCase, runJ(v1), 'method_parameters');
verifyEqual(testCase, sort(paramVariables(d)), sort({ ...
    'refractory period', 'waveform window start', 'waveform window duration'}));
bag = d.get('method_parameters.other');
verifyEqual(testCase, bag.threshold_method, 'median_absolute_deviation');
verifyEqual(testCase, bag.threshold_parameter, -4);
end

function testExtractionTailIsKeptWholeNotDropped(testCase)
% The bag is built by SUBTRACTION from the whole source block, not from an
% allow-list, so a field NDI adds later survives by default. Every one of the
% eleven fields that is not a bound variable has to be findable here.
d = onlyClass(testCase, runJ(extractionBody('sep_9', 'default', 'sess_A')), ...
    'method_parameters');
bag = d.get('method_parameters.other');
verifyEqual(testCase, bag.center_range_time, 0.0005, 'AbsTol', 1e-12);
verifyEqual(testCase, bag.overlap, 0.5, 'AbsTol', 1e-12);
verifyEqual(testCase, bag.read_time, 30, 'AbsTol', 1e-12);
verifyEqual(testCase, bag.threshold_sign, -1);
% filter settings are GROUPED, not flattened: the built method_parameters class
% carries no filter_id edge (its depends_on is software_id / subject_id /
% epoch_id / derived_from_id), so the frequency_filter extraction the plan
% describes cannot be built yet. Grouping keeps them whole and findable for it.
verifyEqual(testCase, bag.filter.filter_type, 'cheby1high');
verifyEqual(testCase, bag.filter.filter_low, 0);
verifyEqual(testCase, bag.filter.filter_high, 300);
verifyEqual(testCase, bag.filter.filter_order, 4);
verifyEqual(testCase, bag.filter.filter_ripple, 0.8, 'AbsTol', 1e-12);
verifyEqual(testCase, bag.filter.do_filter, 1);
end

function testExtractionCarriesAnUnknownFieldRatherThanDroppingIt(testCase)
% The subtraction rule, stated as a test: a field this migrator has never heard
% of must arrive in the bag intact. An allow-list would have dropped it
% silently, which is the failure the vocabulary audit exists to catch, pointed
% the other way.
v1 = extractionBody('sep_10', 'default', 'sess_A');
v1.spike_extraction_parameters.some_future_knob = 17;
d = onlyClass(testCase, runJ(v1), 'method_parameters');
verifyEqual(testCase, d.get('method_parameters.other').some_future_knob, 17);
end

function testExtractionHasNoScopeEdgesAtAll(testCase)
% NEVER EMIT AN EMPTY REQUIRED EDGE -- and never emit an empty OPTIONAL one
% either, which is what actually produced the silent-loss census (an empty edge
% validates clean because references.m:90 skips it). This class has no v1
% dependencies at all, so subject_id / epoch_id / derived_from_id must be
% ABSENT, not present-and-blank.
d = onlyClass(testCase, runJ(extractionBody('sep_11', 'default', 'sess_A')), ...
    'method_parameters');
names = edgeNames(d);
verifyFalse(testCase, any(strcmp(names, 'subject_id')));
verifyFalse(testCase, any(strcmp(names, 'epoch_id')));
verifyFalse(testCase, any(strcmp(names, 'derived_from_id')));
end

function testExtractionAppBecomesASoftwareEntityWithAResolvingEdge(testCase)
% `method_parameters` subclasses `base` ONLY -- there is no app block on the
% target -- while all four v1 classes declare `app` and NDI populates it for
% real. So the app block leaves as a `software` entity (R1) and the edge points
% at a document MINTED IN THE SAME BATCH, so it cannot orphan.
out = runJ(extractionBody('sep_12', 'default', 'sess_A'));
verifyEqual(testCase, numel(out.migrated), 2);
mp = onlyClass(testCase, out, 'method_parameters');
sw = onlyClass(testCase, out, 'software');
verifyEqual(testCase, sw.get('software.name'), 'ndi_app_spikeextractor');
verifyEqual(testCase, sw.get('software.version'), '1.2.3');
verifyEqual(testCase, sw.get('base.session_id'), 'sess_A');
verifyEqual(testCase, depValue(mp, 'software_id'), sw.get('base.id'));
gid = sw.get('entity.global_identifier');
verifyEqual(testCase, numel(gid), 1);
verifyEqual(testCase, gid(1).scheme, 'URL');
end

function testExtractionParksTheEnvironmentFieldsRatherThanDroppingThem(testCase)
% os / os_version / interpreter / interpreter_version have NO typed home:
% `software` does not declare them and `execution_environment` lives on
% subject_interaction, which method_parameters is not. Parked whole in the bag
% rather than dropped -- an open question, not a solved one.
d = onlyClass(testCase, runJ(extractionBody('sep_13', 'default', 'sess_A')), ...
    'method_parameters');
env = d.get('method_parameters.other').execution_environment;
verifyEqual(testCase, env.os, 'MACA64');
verifyEqual(testCase, env.interpreter, 'MATLAB');
verifyEqual(testCase, env.interpreter_version, '24.1');
end

function testNoSoftwareIsMintedWithoutASessionToHangItOn(testCase)
% base.session_id is REQUIRED and non-empty on every V_eta document. Minting a
% software entity without one would fail validation and quarantine the WHOLE
% SOURCE body (v1_to_v2 quarantines the input when any produced body fails),
% turning a clean fold into a loss. So the app block is parked instead and no
% edge is written.
v1 = extractionBody('sep_14', 'default', '');
out = runJ(v1);
verifyEqual(testCase, numel(out.migrated), 1);
d = onlyClass(testCase, out, 'method_parameters');
verifyFalse(testCase, any(strcmp(edgeNames(d), 'software_id')));
verifyEqual(testCase, d.get('method_parameters.other').app.app_name, ...
    'ndi_app_spikeextractor');
end

% ===================== spike_extraction_parameters_modification ============

function testModificationCarriesLineageScopeAndTheSamePayload(testCase)
% v1 stores a FULL copy of all fifteen fields, never a diff, so this folds
% exactly like its base class and simply carries two more edges.
%   extraction_parameters_id -> derived_from_id  LINEAGE ONLY (precedence comes
%                                                from the scope, not this edge)
%   element_id               -> subject_id       (D2: element ids are preserved)
out = runJ(modificationBody('sepm_1', 'default', 'sess_A', 'sep_1', 'elem_9', 't00042'));
verifyEmpty(testCase, out.quarantine);
d = onlyClass(testCase, out, 'method_parameters');
verifyEqual(testCase, d.get('base.id'), 'sepm_1');
verifyEqual(testCase, d.get('method_parameters.name'), 'default');
verifyEqual(testCase, depValue(d, 'derived_from_id'), 'sep_1');
verifyEqual(testCase, depValue(d, 'subject_id'), 'elem_9');
verifyEqual(testCase, sort(paramVariables(d)), sort({ ...
    'refractory period', 'waveform window start', ...
    'waveform window duration', 'standard-deviation threshold'}));
end

function testModificationParksTheEpochStringInsteadOfInventingAnEdge(testCase)
% The epoch scope here is the WRITER's, not the template's: spikeextractor.m:310
% sets 'epochid.epochid' on a class whose template declares only base + app.
% Where template and writer disagree the writer wins, so the scope is real -- and
% a LIVE three-way lookup depends on it (spikeextractor.m:388-391 matches epoch
% AND element AND base parameter set at once).
%
% `epoch_id -> epoch` cannot be filled in pass 1: jEpochDocId answers '' for
% every did_v1 document by construction, because no source carries the edge and
% no migrator mints an `epoch` (#60). So the edge is OMITTED -- not written blank
% and not pointed at a document that does not exist -- and the string is parked.
d = onlyClass(testCase, ...
    runJ(modificationBody('sepm_2', 'default', 'sess_A', 'sep_1', 'elem_9', 't00042')), ...
    'method_parameters');
verifyFalse(testCase, any(strcmp(edgeNames(d), 'epoch_id')));
verifyEqual(testCase, d.get('method_parameters.other').epochid, 't00042');
end

function testModificationOmitsLineageWhenTheSourceEdgeIsEmpty(testCase)
% derived_from_id is optional and must never be written blank. An empty v1
% extraction_parameters_id means NO edge, not an edge to nowhere.
v1 = modificationBody('sepm_3', 'default', 'sess_A', '', 'elem_9', 't00042');
d = onlyClass(testCase, runJ(v1), 'method_parameters');
verifyFalse(testCase, any(strcmp(edgeNames(d), 'derived_from_id')));
verifyEqual(testCase, depValue(d, 'subject_id'), 'elem_9');
end

% ===================== sorting_parameters ==================================

function testSortingFoldsWithAnEmptyParameterListAndAFullBag(testCase)
% NOT AN OVERSIGHT -- THE DECIDED OUTCOME. The plan puts all six of this class's
% fields in the bag BY NAME ("graphical_mode -- a GUI flag; num_pca_features,
% interpolation, num_start -- algorithm-specific; min_clusters, max_clusters --
% JUDGMENT CALL"). So the document carries an empty parameter list, and every
% field survives in `other`. Promoting min/max_clusters is a team call.
out = runJ(sortingBody('sp_1', 'default', 'sess_A'));
verifyEmpty(testCase, out.quarantine);
d = onlyClass(testCase, out, 'method_parameters');
verifyEmpty(testCase, d.get('method_parameters.method_parameters'));
bag = d.get('method_parameters.other');
verifyEqual(testCase, bag.graphical_mode, 1);
verifyEqual(testCase, bag.num_pca_features, 10);
verifyEqual(testCase, bag.interpolation, 3);
verifyEqual(testCase, bag.min_clusters, 3);
verifyEqual(testCase, bag.max_clusters, 10);
verifyEqual(testCase, bag.num_start, 5);
end

function testSortingPreservesTheIdAndTheNameSpikesorterQueriesBy(testCase)
% spike_clusters.sorting_parameters_id points at the id; spikesorter.m:373 looks
% the protocol up by base.name with exact_string. Both have to survive.
d = onlyClass(testCase, runJ(sortingBody('sp_2', 'default', 'sess_A')), ...
    'method_parameters');
verifyEqual(testCase, d.get('base.id'), 'sp_2');
verifyEqual(testCase, d.get('base.name'), 'default');
verifyEqual(testCase, d.get('method_parameters.name'), 'default');
verifyFalse(testCase, any(strcmp(edgeNames(d), 'subject_id')));
end

% ===================== vmspikefilteringparameters ==========================

function testVmspikeFoldsWhenSpiketimesIsEmpty(testCase)
% The template's own `spiketimes` value is "", so a settings-only document folds.
out = runJ(vmspikeBody('vm_1', 'sess_A', 'elem_1', 't00001', ''));
verifyEmpty(testCase, out.quarantine);
d = onlyClass(testCase, out, 'method_parameters');
verifyEqual(testCase, d.get('base.id'), 'vm_1');
verifyEqual(testCase, depValue(d, 'subject_id'), 'elem_1');
verifyEqual(testCase, sort(paramVariables(d)), sort({ ...
    'refractory period', 'absolute voltage threshold'}));
end

function testVmspikeThresholdKeepsItsVerbatimStringAndBecomesANumber(testCase)
% v1 writes the threshold as the STRING "0.030" while its own schema_documents
% pair declares it a number. Both are honoured: value.value is the number a
% query can compare, value.source_value is the string the source wrote, kept
% whatever the registry later says.
d = onlyClass(testCase, runJ(vmspikeBody('vm_2', 'sess_A', 'elem_1', 't00001', '')), ...
    'method_parameters');
e = paramEntry(testCase, d, 'absolute voltage threshold');
verifyEqual(testCase, e.value.value, 0.030, 'AbsTol', 1e-12);
verifyEqual(testCase, e.value.source_value, '0.030');
verifyEqual(testCase, e.value.source_unit, '');
end

function testVmspikeGuardsNonEmptySpiketimesWithAPassthrough(testCase)
% THE GUARD. `spiketimes` is OUTPUT data sitting in a configuration document. It
% is not a parameter and must not be folded into the settings bag, and there is
% no writer anywhere in NDI to document its encoding (seconds? sample indices?
% which clock?) -- which is exactly why its three sibling
% vhlab_voltage2firingrate classes are deferred passthroughs too.
%
% So a document that carries any is passed through UNCHANGED for the second
% pass: nothing is lost and nothing is invented. This is not a regression on
% today's behaviour either -- before this migrator existed, EVERY document of
% this class reached validation in its did_v1 shape.
out = runJ(vmspikeBody('vm_4', 'sess_A', 'elem_1', 't00001', [0.11 0.22 0.35]));
verifyEqual(testCase, numel(out.migrated), 1);
d = out.migrated{1};
verifyEqual(testCase, d.get('document_class.class_name'), 'vmspikefilteringparameters');
verifyEqual(testCase, d.get('base.id'), 'vm_4');
verifyEqual(testCase, d.get('vmspikefilteringparameters.spiketimes'), [0.11 0.22 0.35], ...
    'AbsTol', 1e-12);
% and the report can tell a deliberate passthrough from a successful fold
verifyEqual(testCase, out.summary.unconverted_count, 1);
end

function testVmspikeKeepsSamplingRateRatherThanDroppingIt(testCase)
% The plan says DROP sampling_rate as a duplicate of the data body's own time
% axis (#45). But #45 is not built, this class has no body, and this document is
% the only place the number exists -- so dropping it now would lose it against a
% duplicate that does not yet exist. Kept in the bag; raised as an open question
% rather than decided by a migrator.
d = onlyClass(testCase, runJ(vmspikeBody('vm_5', 'sess_A', 'elem_1', 't00001', '')), ...
    'method_parameters');
bag = d.get('method_parameters.other');
verifyEqual(testCase, bag.sampling_rate, 0);
verifyEqual(testCase, bag.new_sampling_rate, 0);
end

function testVmspikeGroupsItsFilterSettingsIncludingTheRenamedRm60Hz(testCase)
% `rm60Hz` is camelCase in the template; did2.convert.universalRenames snake_cases
% block field names, so the migrator sees `rm60_hz`. Reading only the camelCase
% spelling is the shape of bug that has bitten this repo repeatedly, so the
% rename is exercised rather than assumed.
d = onlyClass(testCase, runJ(vmspikeBody('vm_6', 'sess_A', 'elem_1', 't00001', '')), ...
    'method_parameters');
f = d.get('method_parameters.other').filter;
verifyEqual(testCase, f.rm60_hz, 1);
verifyEqual(testCase, f.filter_algorithm, '0');
verifyTrue(testCase, isfield(f, 'filter_algorithm_parameters'));
end

function testVmspikeParksItsEpochStringToo(testCase)
% Unlike _modification, this class DOES declare the epochid superclass in its
% template. Same treatment either way: no `epoch` document exists to point at in
% pass 1, so the string is parked instead of the edge being invented.
d = onlyClass(testCase, runJ(vmspikeBody('vm_7', 'sess_A', 'elem_1', 't00099', '')), ...
    'method_parameters');
verifyFalse(testCase, any(strcmp(edgeNames(d), 'epoch_id')));
verifyEqual(testCase, d.get('method_parameters.other').epochid, 't00099');
end

% ===================== validation ==========================================

function testMethodParametersValidatesAgainstItsSchema(testCase)
% VALIDATION ON -- the point every test above can only infer. The fold and the
% schema have to agree, and only a validating run proves they do: the validator
% is strict BOTH ways (undeclaredField on anything the block does not declare,
% missingField/emptyField on anything required that is absent).
%
% All four sources are driven at once, so a defect in any one of them fails
% here, and the software entity each fold mints is validated alongside.
%
% runJ deliberately passes Validate=false, so this calls v1_to_v2 directly.
% Requires the V_eta schema set on DID_SCHEMA_PATH (the quick gate assembles it
% from schemas/V_eta/{stable,draft,deprecated}).
v1 = { ...
    extractionBody('sep_v', 'default', 'sess_V'), ...
    modificationBody('sepm_v', 'default', 'sess_V', 'sep_v', 'elem_v', 't00042'), ...
    sortingBody('sp_v', 'default', 'sess_V'), ...
    vmspikeBody('vm_v', 'sess_V', 'elem_v', 't00001', '')};
out = did2.convert.v1_to_v2(v1, 'Validate', true, 'TargetVersion', 'V_eta');
if ~isempty(out.quarantine)
    verifyFail(testCase, sprintf('%s quarantined under validation: %s', ...
        out.quarantine(1).class_name, out.quarantine(1).reason));
end
% 4 method_parameters + 4 software entities
verifyEqual(testCase, numel(out.migrated), 8);
n = 0;
for k = 1:numel(out.migrated)
    if strcmp(out.migrated{k}.get('document_class.class_name'), 'method_parameters')
        n = n + 1;
    end
end
verifyEqual(testCase, n, 4);
% and no empty required edge was manufactured on the way. An empty edge
% VALIDATES CLEAN (+did2/+validate/references.m:90 skips it), so the validating
% run above cannot see one -- this census is the only thing that can.
verifyTrue(testCase, isfield(out.silent_loss, 'empty_dependency_count'), ...
    sprintf('silent-loss audit did not run: %s', ...
        getfieldOrDefault(out.silent_loss, 'audit_failed', '<no reason given>')));
verifyEqual(testCase, out.silent_loss.empty_dependency_count, 0);
end

function v = getfieldOrDefault(s, name, default)
v = default;
if isstruct(s) && isfield(s, name)
    v = s.(name);
end
end
