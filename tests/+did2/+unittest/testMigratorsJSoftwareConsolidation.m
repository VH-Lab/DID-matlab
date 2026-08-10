function tests = testMigratorsJSoftwareConsolidation
%TESTMIGRATORSJSOFTWARECONSOLIDATION Brainstorm-J: ONE builder for `software`.
%
%   Item #25 (software follow-ups) had three copies of the `software` fold:
%
%     private/jSoftware.m            the R1 builder -- writes local_identifier
%     private/jSyncSoftware.m        syncrule/syncgraph -- did NOT write it
%     softwareEntity() inside
%       private/jMethodParameters.m  the settings classes -- did NOT write it
%
%   Two of the three omitted `software.local_identifier`, which is the dedup
%   HANDLE the deferred corpus-wide merge reads, so two thirds of the corpus's
%   software entities carried no handle. jSyncSoftware's own comment gave the
%   reason -- "jCalculation's software entities do not set it either" -- and that
%   had stopped being true: jCalculation folds through jSoftwareFromApp, which
%   calls jSoftware, which sets it. A justification that expired silently.
%
%   Both now delegate to jSoftware. This file pins the consolidation from the
%   OUTSIDE: it asserts what the emitted documents contain, so the assertions
%   survive any later re-arrangement of which helper calls which.
%
%   ---------------------------------------------------------------------
%   EVERY TEST HERE DRIVES did2.convert.v1_to_v2, NOT THE MIGRATOR DIRECTLY
%   ---------------------------------------------------------------------
%   Same reason as testMigratorsJFileNavSoftware.m, and it is not a stylistic
%   choice. did2.convert.universalRenames runs FIRST on the real pipeline and
%   rewrites `app.name` -> `app.app_name` / `app.version` -> `app.app_version`
%   (universalRenames.m:145-164). A direct call skips it, which is exactly how
%   the app -> software fold shipped reading a field name that no real document
%   has, minted no entity on any real document, and stayed green.
%
%   ---------------------------------------------------------------------
%   STATUS: NOT VERIFIED BY EXECUTION
%   ---------------------------------------------------------------------
%   There is no MATLAB in the authoring environment. No test in this file has
%   ever been run.
%
%   Run with:  results = runtests('did2.unittest.testMigratorsJSoftwareConsolidation');

tests = functiontests(localfunctions);
end

% ============ family 1: the sync cluster (was jSyncSoftware's own build) ====

function testSyncruleSoftwareCarriesTheDedupHandle(testCase)
% THE REGRESSION TEST for the consolidation. Before it, this document's
% `software` had name and base.name but no local_identifier, so the dedup pass
% would have had to special-case sync entities.
%
% Source values are what NDI's own writer stores:
%   git show origin/main:src/ndi/+ndi/+time/syncrule.m:183-187
%     ndi.document('syncrule', 'syncrule.ndi_syncrule_class', class(obj), ...)
% and the ctoe parameter set is the closed set isvalidparameters validates
% (commonTriggersOverlappingEpochs.m:36).
out = runJ(syncruleBody('ndi.time.syncrule.commonTriggersOverlappingEpochs'));
verifyEmpty(testCase, out.quarantine);

sw = firstOfClass(testCase, out, 'software');
verifyEqual(testCase, sw.get('software.name'), ...
    'ndi.time.syncrule.commonTriggersOverlappingEpochs');
% THE POINT OF THE FILE
verifyEqual(testCase, sw.get('software.local_identifier'), ...
    'ndi.time.syncrule.commonTriggersOverlappingEpochs');

% and the configuration still points at it
cfg = firstOfClass(testCase, out, 'clock_alignment_configuration');
verifyEqual(testCase, depValue(cfg.toStruct(), 'software_id'), sw.get('base.id'));
end

function testSyncSoftwareVersionStaysEmptyAndTheHandleHasNoAtSign(testCase)
% v1 records no release for the implementation that computed an alignment, so
% `version` is EMPTY and the handle is the BARE class name -- jSoftware appends
% `@<version>` only when there is one. Guessing a version would be exactly the
% fabrication the ground-truth track exists to stop.
out = runJ(syncruleBody('ndi.time.syncrule.commonTriggersOverlappingEpochs'));
sw = firstOfClass(testCase, out, 'software');
% verifyEmpty, NOT verifyEqual(...,''): verifyEqual compares SIZE and MATLAB has
% more than one empty char (0x0 vs 1x0), which is a fact about how the empty was
% built, not about the migration.
verifyClass(testCase, sw.get('software.version'), 'char');
verifyEmpty(testCase, sw.get('software.version'));
verifyFalse(testCase, contains(sw.get('software.local_identifier'), '@'));
end

function testSyncSoftwareGlobalIdentifierStaysEmpty(testCase)
% A MATLAB class name is not an identifier in any scheme we can name, so the
% array is present-and-empty rather than absent-and-guessed-at. This behaviour
% moved from jSyncSoftware into jSoftware with the consolidation; pin it so the
% move cannot quietly invent a scheme.
out = runJ(syncruleBody('ndi.time.syncrule.filefind'));
sw = firstOfClass(testCase, out, 'software');
verifyEmpty(testCase, sw.get('entity.global_identifier'));
end

function testSyncruleWithNoImplementationClassMintsNoSoftware(testCase)
% No identity -> no entity AND no edge, rather than a `software` named '' with
% an edge pointing at it. An empty edge is INVISIBLE, not absent
% (+did2/+validate/references.m:90 skips empty edges), which is the mechanism
% behind the whole invented-empty-edge census.
out = runJ(syncruleBody(''));
verifyEmpty(testCase, out.quarantine);
names = classNames(out);
verifyFalse(testCase, any(strcmp(names, 'software')));
cfg = firstOfClass(testCase, out, 'clock_alignment_configuration');
verifyEqual(testCase, depValue(cfg.toStruct(), 'software_id'), '');
end

% ====== family 2: method_parameters (was jMethodParameters.softwareEntity) ==

function testSettingsSoftwareCarriesTheDedupHandleWithItsVersion(testCase)
% The other consolidated copy. This one DOES have a version (ndi.app/newdocument
% populates the whole app block -- src/ndi/+ndi/app.m:105-114), so the handle is
% NAME@VERSION.
out = runJ(extractionParamsBody('ndi.app.spikeextractor', '2.1'));
verifyEmpty(testCase, out.quarantine);

sw = firstOfClass(testCase, out, 'software');
verifyEqual(testCase, sw.get('software.name'), 'ndi.app.spikeextractor');
verifyEqual(testCase, sw.get('software.version'), '2.1');
verifyEqual(testCase, sw.get('software.local_identifier'), ...
    'ndi.app.spikeextractor@2.1');

mp = firstOfClass(testCase, out, 'method_parameters');
verifyEqual(testCase, depValue(mp.toStruct(), 'software_id'), sw.get('base.id'));
% base.id PRESERVED: three templates point at it
% (spike_extraction_parameters_modification / spikewaves / spike_clusters, all
% `extraction_parameters_id`), and both consumers are deferred passthroughs in
% pass 1, so the edges have to keep resolving.
verifyEqual(testCase, mp.get('base.id'), 'sep_1');
end

function testSettingsAppBlockReadsThePostRenameSpelling(testCase)
% universalRenames has already rewritten app.name -> app.app_name by the time
% this migrator runs. The fixture is built PRE-rename (as a v1 document is), so
% a fold that read only the bare spelling would mint nothing here -- and would
% still pass a direct-call test. That is the bug this whole file's harness
% choice exists to catch.
out = runJ(extractionParamsBody('ndi.app.spikeextractor', '2.1'));
names = classNames(out);
verifyTrue(testCase, any(strcmp(names, 'software')), ...
    ['no software entity was minted -- the app fold read a field name that ' ...
     'universalRenames had already rewritten']);
end

function testSettingsExecutionEnvironmentIsParkedNotDropped(testCase)
% `execution_environment` is a subject_interaction field and method_parameters
% is NOT a statement, so the four per-run facts have no typed home on this
% class. They are PARKED in `other.execution_environment` rather than dropped.
% (Unchanged by the consolidation; pinned because the parking now happens on the
% far side of a shared helper, where it is easier to lose.)
out = runJ(extractionParamsBody('ndi.app.spikeextractor', '2.1'));
mp = firstOfClass(testCase, out, 'method_parameters');
env = mp.get('method_parameters.other.execution_environment');
verifyEqual(testCase, env.interpreter, 'MATLAB');
verifyEqual(testCase, env.os, 'Linux');
end

function testSettingsWithNoSessionParksTheWholeAppBlock(testCase)
% THE RequireSession GUARD, which the consolidation had to carry across.
% `base.session_id` is "mustBeNonEmpty": true (did-schema
% schemas/V_eta/stable/base.json), so a `software` minted with no session cannot
% validate -- and v1_to_v2 quarantines the SOURCE when a body it produced fails,
% turning a clean fold into a loss. So: no entity, no edge, and the app block is
% parked WHOLE in `other.app`.
%
% `other.execution_environment` must NOT also be written here: the same four
% facts would then sit in `other` twice, under two keys. That is why
% jSoftwareFromApp clears execEnv for a caller that asked for the leftover.
v1 = extractionParamsBody('ndi.app.spikeextractor', '2.1');
v1.base.session_id = '';
out = runJ(v1);
names = classNames(out);
verifyFalse(testCase, any(strcmp(names, 'software')));

mp = firstOfClass(testCase, out, 'method_parameters');
verifyEqual(testCase, depValue(mp.toStruct(), 'software_id'), '');
other = mp.get('method_parameters.other');
verifyTrue(testCase, isfield(other, 'app'));
verifyEqual(testCase, other.app.app_name, 'ndi.app.spikeextractor');
verifyFalse(testCase, isfield(other, 'execution_environment'));
end

% ============ family 3: the calculator path must be UNCHANGED ==============

function testCalculatorNamelessAppStillYieldsAnExecutionEnvironment(testCase)
% GUARDS THE ADDITIVE PROMISE. jSoftwareFromApp grew a 4th output and an option;
% jCalculation asks for 3 and passes neither, so its behaviour must be
% byte-identical to before. The sharp edge is the nameless app block: this
% helper's header has always said EXECENV may still be populated from one ("the
% os/interpreter of the run is a fact about the run, not about the software's
% identity"), and a naive "nothing minted -> clear everything" would have
% silently deleted it for every calculator.
v1 = calcBody('', '');
v1.app.os = 'Linux';
v1.app.interpreter = 'MATLAB';
out = runJ(v1);
verifyEmpty(testCase, out.quarantine);
names = classNames(out);
verifyFalse(testCase, any(strcmp(names, 'software')));   % no name -> no entity
leaf = out.migrated{find(~strcmp(names, 'session_relative_reference') ...
    & ~strcmp(names, 'software'), 1)};
verifyEqual(testCase, ...
    leaf.get('subject_interaction.execution_environment.os'), 'Linux');
verifyEqual(testCase, ...
    leaf.get('subject_interaction.execution_environment.interpreter'), 'MATLAB');
end

% ===================== fixtures ============================================

function out = runJ(v1)
%RUNJ The full pipeline at V_eta with validation OFF (transform assertions).
%   Validation is off deliberately: these are assertions about what the fold
%   PRODUCES. testMigratorsJFileNavSoftware.m owns the validating runs for the
%   `software` shape and they are not duplicated here.
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
end

function v1 = syncruleBody(implClass)
%SYNCRULEBODY A did_v1 `syncrule`, shaped as NDI's template declares it.
%   git show origin/main:src/ndi/ndi_common/database_documents/daq/syncrule.json
%      "syncrule": { "ndi_syncrule_class": "...", "parameters": [] }
%      (no depends_on at all)
%   The parameter set is commonTriggersOverlappingEpochs's closed set
%   (isvalidparameters, commonTriggersOverlappingEpochs.m:36). BOTH device names
%   and BOTH channels are present because syncrule.m guards on the pair: with
%   fewer than two `acquisition_channels` it passes the document through and no
%   software is minted, which would test the guard rather than the fold.
v1 = struct();
v1.document_class = struct('class_name', 'syncrule', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.base = struct('id', 'sr_1', 'session_id', 'sess_1', 'name', 'ctoe', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.syncrule = struct('ndi_syncrule_class', implClass, ...
    'parameters', struct( ...
        'daqsystem1_name', 'intan1', 'daqsystem2_name', 'ced1', ...
        'daqsystem_ch1', 'mk1', 'daqsystem_ch2', 'mk1', ...
        'epochclocktype', 'dev_local_time'));
end

function v1 = extractionParamsBody(appName, appVersion)
%EXTRACTIONPARAMSBODY A did_v1 `spike_extraction_parameters`.
%   Template: superclasses [base, app], NO depends_on key at all
%     git show origin/main:src/ndi/ndi_common/database_documents/apps/\
%         spikeextractor/spike_extraction_parameters.json
%   The app block carries EXACTLY the seven fields NDI's app template declares
%   (git show origin/main:src/ndi/ndi_common/database_documents/app.json), in
%   their PRE-rename spelling, because that is what a v1 document holds.
v1 = struct();
v1.document_class = struct('class_name', 'spike_extraction_parameters', ...
    'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base', 'class_version', '1.0.0'), ...
                      struct('class_name', 'app',  'class_version', '1.0.0')]);
v1.base = struct('id', 'sep_1', 'session_id', 'sess_1', ...
    'name', 'default_extraction', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.app = struct('name', appName, 'version', appVersion, ...
    'url', 'https://github.com/VH-Lab/NDI-matlab', 'os', 'Linux', ...
    'os_version', '22.04', 'interpreter', 'MATLAB', 'interpreter_version', '24.2');
v1.spike_extraction_parameters = struct( ...
    'refractory_time', 0.002, 'spike_start_time', -0.001, ...
    'spike_end_time', 0.002, 'threshold_method', 'standard_deviation', ...
    'threshold_parameter', 4, 'threshold_sign', -1, ...
    'do_filter', 1, 'filter_type', 'cheby1high', 'filter_low', 300, ...
    'filter_high', 10000, 'filter_order', 4, 'filter_ripple', 0.8, ...
    'center_range_time', 0.0004, 'overlap', 0.5, 'read_time', 30);
end

function v1 = calcBody(appName, appVersion)
%CALCBODY A minimal calculator output, the jCalculation path.
v1 = struct();
v1.document_class = struct('class_name', 'oridirtuning_calc', ...
    'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base', 'class_version', '1.0.0'), ...
                      struct('class_name', 'orientation_direction_tuning', ...
                             'class_version', '1.0.0'), ...
                      struct('class_name', 'tuning_fit', 'class_version', '1.0.0')]);
v1.depends_on = struct('name', 'element_id', 'value', 'neuron_9');
v1.base = struct('id', 'oc_9', 'session_id', 'sess_09', 'name', 'oc', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.app = struct('name', appName, 'version', appVersion, 'url', '', ...
    'os', '', 'os_version', '', 'interpreter', '', 'interpreter_version', '');
v1.orientation_direction_tuning = struct('vector', ...
    struct('orientation_preference', 12));
end

% ===================== accessors ==========================================

function names = classNames(out)
names = cellfun(@(d) d.get('document_class.class_name'), out.migrated, ...
    'UniformOutput', false);
end

function doc = firstOfClass(testCase, out, className)
names = classNames(out);
idx = find(strcmp(names, className), 1);
verifyNotEmpty(testCase, idx, sprintf( ...
    'no %s document was emitted (got: %s)', className, strjoin(names, ', ')));
doc = out.migrated{idx};
end

function v = depValue(b, name)
%DEPVALUE Read an edge off a RAW BODY STRUCT, accepting BOTH spellings.
%   universalRenames normalises v1's {name, value} to {name, document_id}, so
%   which one a body carries depends on where it came from. Precedence copied
%   from +did2/+validate/references.m:176-179.
v = '';
if ~isstruct(b) || ~isfield(b, 'depends_on') || ~isstruct(b.depends_on)
    return;
end
for k = 1:numel(b.depends_on)
    d = b.depends_on(k);
    if ~isfield(d, 'name') || ~strcmp(d.name, name); continue; end
    if isfield(d, 'document_id') && ~isempty(d.document_id)
        v = char(d.document_id); return;
    elseif isfield(d, 'value') && ~isempty(d.value)
        v = char(d.value); return;
    end
end
end
