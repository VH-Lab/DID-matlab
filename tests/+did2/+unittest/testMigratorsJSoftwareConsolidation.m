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
out = runJ(syncruleBody('ndi.time.syncrule.commonTriggersOverlappingEpochs'));
verifyEmpty(testCase, out.quarantine);
sw = firstOfClass(testCase, out, 'software');
verifyEqual(testCase, sw.get('entity.name'), ...
    'ndi.time.syncrule.commonTriggersOverlappingEpochs');
verifyEqual(testCase, sw.get('entity.local_identifier'), ...
    'ndi.time.syncrule.commonTriggersOverlappingEpochs');
cfg = firstOfClass(testCase, out, 'clock_alignment_configuration');
verifyEqual(testCase, depValue(cfg.toStruct(), 'software_id'), sw.get('base.id'));
end


function testSyncSoftwareVersionStaysEmptyAndTheHandleHasNoAtSign(testCase)
% UPDATED for #88: a version is a text_assertion about the software, so "no
% version" is "no version assertion".
out = runJ(syncruleBody('ndi.time.syncrule.commonTriggersOverlappingEpochs'));
sw = firstOfClass(testCase, out, 'software');
verifyFalse(testCase, any(strcmp(classNames(out), 'assertion+text')));
verifyFalse(testCase, contains(sw.get('entity.local_identifier'), '@'));
end


function testSyncSoftwareGlobalIdentifierStaysEmpty(testCase)
out = runJ(syncruleBody('ndi.time.syncrule.randomPulses'));
sw = firstOfClass(testCase, out, 'software');
e = sw.get('entity');
verifyTrue(testCase, ~isfield(e, 'global_identifier') || isempty(e.global_identifier));
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
% UPDATED for #88: the version is a text_assertion about the software entity.
out = runJ(extractionParamsBody('ndi.app.spikeextractor', '2.1'));
verifyEmpty(testCase, out.quarantine);
sw = firstOfClass(testCase, out, 'software');
verifyEqual(testCase, sw.get('entity.name'), 'ndi.app.spikeextractor');
verifyEqual(testCase, sw.get('entity.local_identifier'), 'ndi.app.spikeextractor@2.1');
ver = firstOfClass(testCase, out, 'assertion+text');
verifyEqual(testCase, depValue(ver.toStruct(), 'entity_id'), sw.get('base.id'));
verifyEqual(testCase, ver.get('text.value').text, '2.1');
mp = firstOfClass(testCase, out, 'method');
verifyEqual(testCase, depValue(mp.toStruct(), 'software_id'), sw.get('base.id'));
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

function testSettingsNamingTheRunEnvironmentAreCarriedAsV1(testCase)
% INVERTED 2026-10-26 (was testSettingsExecutionEnvironmentIsParkedNotDropped,
% which asserted the run environment was dropped from the method). [small
% unread settings] (1) (Jess Haley, 2026-10-26): `method` gains no OS or
% interpreter link (V2 records a run's environment on the calculation), so a
% settings document whose app block names one is carried whole as v1, and no
% software entity is minted for it.
v1 = extractionParamsBody('ndi.app.spikeextractor', '2.1');
v1.app.os = 'Linux';
v1.app.os_version = '22.04';
v1.app.interpreter = 'MATLAB';
v1.app.interpreter_version = '24.2';
out = runJ(v1);
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 1, 'one document: the v1 source');
verifyEqual(testCase, out.migrated{1}.get('document_class.class_name'), ...
    'spike_extraction_parameters');
verifyFalse(testCase, any(strcmp(classNames(out), 'software')));
end


function testSettingsWithNoSessionParksTheWholeAppBlock(testCase)
% UPDATED for #88: a document with no session id cannot be built (every V_eta
% document's session_id edge is required), so it is QUARANTINED by the builder
% rather than emitted with an invented session; no software is minted for it.
v1 = extractionParamsBody('ndi.app.spikeextractor', '2.1');
v1.base.session_id = '';
out = runJ(v1);
verifyEmpty(testCase, out.migrated);
verifyEqual(testCase, numel(out.quarantine), 1);
verifyNotEmpty(testCase, regexp(out.quarantine(1).reason, 'SessionId', 'once'));
end


% ============ family 3: the calculator path must be UNCHANGED ==============

function testCalculatorNamelessAppStillYieldsAnExecutionEnvironment(testCase)
% An app block with no name still states the run's os and interpreter. UPDATED
% for #88: the calculation names them as `software` entities by
% operating_system_id / interpreter_id; the app software is named after the
% calculator method. The fixture now carries a tuning curve: with no curve the
% required result value is empty and the document passes through
% (testCalculatorWithNoCurvePassesThrough).
v1 = calcBody('', '');
v1.app.os = 'Linux';
v1.app.interpreter = 'MATLAB';
v1.orientation_direction_tuning.tuning_curve = struct('direction', [0 90], 'mean', [3 4]);
out = runJ(v1);
verifyEmpty(testCase, out.quarantine);
names = classNames(out);
verifyTrue(testCase, any(strcmp(names, 'software')));
leaf = out.migrated{find(strcmp(names, 'orientation_direction_tuning_calculation'), 1)};
s = leaf.toStruct();
verifyEqual(testCase, nameOf(out, depValue(s, 'operating_system_id')), 'Linux');
verifyEqual(testCase, nameOf(out, depValue(s, 'interpreter_id')), 'MATLAB');
verifyEqual(testCase, nameOf(out, depValue(s, 'software_id')), 'ndi.calc.vis.oridir');
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
% UPDATED for did-schema #88: a FILE-BASED rule (no device pair). A channel-based
% rule passes through on #88 (its DAQ system names cannot become an
% acquisition_system_id inside one document), so the software it would mint is
% exercised here on the rule shape that still folds. The implementation class
% is whatever the test passes; the software is named by it either way.
v1 = struct();
v1.document_class = struct('class_name', 'syncrule', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {}, 'value', {});   % the template declares none
v1.base = struct('id', 'sr_1', ...
    'session_id', '0000000000000000_0000000000000000', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.syncrule = struct('ndi_syncrule_class', implClass, ...
    'parameters', struct('number_fullpath_matches', 2));
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
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
% 2026-10-26: the run-environment four (os, os_version, interpreter,
% interpreter_version) are left empty: a settings document whose app block
% names them is carried whole as v1 ([small unread settings] (1), Jess Haley,
% 2026-10-26; testSettingsNamingTheRunEnvironmentAreCarriedAsV1).
v1.app = struct('name', appName, 'version', appVersion, ...
    'url', 'https://github.com/VH-Lab/NDI-matlab', 'os', '', ...
    'os_version', '', 'interpreter', '', 'interpreter_version', '');
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
v1.base = struct('id', 'oc_9', 'session_id', 'sess_09', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.app = struct('name', appName, 'version', appVersion, 'url', '', ...
    'os', '', 'os_version', '', 'interpreter', '', 'interpreter_version', '');
v1.orientation_direction_tuning = struct('vector', ...
    struct('orientation_preference', 12));
end

% ===================== accessors ==========================================

function names = classNames(out)
names = cellfun(@(d) did2.unittest.helpers.classKey(d), out.migrated, ...
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

function testCalculatorWithNoCurvePassesThrough(testCase)
% did-schema #88's result composite REQUIRES its value. A calculator output whose
% result block carries no curve has nothing to state there, so it passes through
% unchanged (never a quarantine, never an invented curve).
v1 = calcBody('', '');
v1.app.os = 'Linux';
out = runJ(v1);
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, classNames(out), {'oridirtuning_calc'});
verifyEqual(testCase, out.summary.unconverted_count, 1);
end


function n = nameOf(out, id)
n = '';
for k = 1:numel(out.migrated)
    if strcmp(out.migrated{k}.get('base.id'), id)
        e = out.migrated{k}.get('entity');
        if isfield(e, 'name'); n = char(e.name); end
        return;
    end
end
end
