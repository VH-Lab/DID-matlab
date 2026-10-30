function [v1, spec] = syncrule(bodies)
%SYNCRULE Rebuild a v1 `syncrule` from what the migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.syncrule(BODIES). V1 is the rule in
%   NDI's v1 shape (syncrule.json + base.json at the locked NDI-matlab `main`,
%   3cb19a8, as +ndi/+time/syncrule.m newdocument writes it for filematch.m,
%   filefind.m, commonTriggersOverlappingEpochs.m and randomPulses.m). BODIES
%   is one of:
%
%   the pass-1 passthrough (a device-pair rule before its systems are
%   resolved): its outbound renames undone;
%
%   the `clock_alignment_configuration` and its `software` entity (a filematch
%   rule in pass 1), plus, for the device-pair fold did2.convert.
%   resolveClockAlignment makes, the two `acquisition_system`s its
%   `from_acquisition_system_id` / `to_acquisition_system_id` edges name:
%     base.id, session_id, datestamp   the configuration's
%     base.name                        '' (the writer sets none)
%     syncrule.ndi_syncrule_class      the software entity's name
%     syncrule.parameters              the method parameters, by name:
%       number_fullpath_matches        'minimum matching file paths'
%       syncfilename                   'sync file name'
%       minEmbeddedFileOverlap         'minimum embedded file overlap'
%       daqsystem_ch1, daqsystem_ch2   'from trigger channel', 'to trigger
%                                      channel' ([trigger channels named by
%                                      their link], Jess Haley, 2026-10-30);
%                                      a configuration migrated before
%                                      holds them as 'daqsystem ch1' /
%                                      'daqsystem ch2', read below as any
%                                      other name
%       any other                      its own name ('_' written as a space;
%                                      errorOnFailure)
%       epochclocktype                 the configuration's clock
%       daqsystem1, daqsystem2         (filefind) the names of the
%                                      acquisition systems the from / to
%                                      edges name, from first
%       daqsystem1_name, daqsystem2_name  the same, for
%                                      commonTriggersOverlappingEpochs and
%                                      randomPulses (the key each writer uses)
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.syncrule,
%            did2.convert.resolveClockAlignment.

arguments
    bodies cell
end

CLASS = 'syncrule';
spec = emptySpec();
v1 = struct();
if isscalar(bodies) && strcmp(classNameOf(bodies{1}), CLASS)
    v1 = undoOutbound(bodies{1});
    return;
end
% the systems the from / to edges name are claimed first; daqParts places
% the configuration and its software, and finds no role for anything else
ids = cellfun(@(b) char(getIn(b, 'base', 'id')), bodies, 'UniformOutput', false);
cfg = [];
for k = 1:numel(bodies)
    if strcmp(classNameOf(bodies{k}), 'clock_alignment_configuration')
        cfg = bodies{k};
        break;
    end
end
claimed = false(1, numel(bodies));
systemNames = {};
if ~isempty(cfg)
    if ~isempty(edgeIds(cfg, 'acquisition_channels_id'))
        spec.unplaced{end+1} = ['the configuration names acquisition_channels ' ...
            '(a migrated sync rule links its systems directly)'];
    end
    for role = {'from_acquisition_system_id', 'to_acquisition_system_id'}
        sysIds = edgeIds(cfg, role{1});
        if isempty(sysIds)
            continue;
        end
        s = find(strcmp(ids, sysIds{1}), 1);
        if isempty(s) || ~strcmp(classNameOf(bodies{s}), 'acquisition_system')
            spec.unplaced{end+1} = sprintf('%s names no acquisition_system among the documents', role{1}); %#ok<AGROW>
            continue;
        end
        claimed(s) = true;
        systemNames{end+1} = fieldText(getIn(bodies{s}, 'acquisition_system'), 'name'); %#ok<AGROW>
    end
end
[doc, ~, swName, spec] = daqParts(bodies(~claimed), 'clock_alignment_configuration', spec);
if isempty(doc)
    return;
end
blk = getIn(doc, 'clock_alignment_configuration');
spec.unplaced = [spec.unplaced, others(blk, {'clock', 'method'}, ...
    'clock_alignment_configuration')];
[params, bad] = ruleParameters(getIn(blk, 'method', 'parameters'));
spec.unplaced = [spec.unplaced, bad];
if ~allEmpty(getIn(blk, 'method', 'term'))
    spec.unplaced{end+1} = 'the configuration''s method states a term (pass 1 writes none)';
end
[~, clockName] = termParts(getIn(blk, 'clock'));
if ~isempty(clockName)
    params.epochclocktype = clockName;
end
if numel(systemNames) == 2
    if strcmp(swName, 'ndi.time.syncrule.filefind')
        params.daqsystem1 = systemNames{1};
        params.daqsystem2 = systemNames{2};
    else
        params.daqsystem1_name = systemNames{1};
        params.daqsystem2_name = systemNames{2};
    end
elseif ~isempty(systemNames)
    spec.unplaced{end+1} = sprintf('%d acquisition systems (a rule names 0 or 2)', numel(systemNames));
end
base = rebuildBase(doc);
v1.document_class = struct('class_name', CLASS);
v1.base = struct('id', base.id, 'session_id', base.session_id, 'name', '', ...
    'datestamp', base.datestamp);
v1.syncrule = struct('ndi_syncrule_class', swName, 'parameters', params);
end

% ===================== helpers =========================================

function [s, bad] = ruleParameters(params)
%RULEPARAMETERS The rule's v1 parameters from the configuration's method
%   parameters: the five the migrator names back to their writer spelling,
%   every other one by its own name (a space read back as '_', a '.' as a
%   nested field: private/jParameterList's naming).
%
%   The trigger channels (Decided by Jess Haley, 2026-10-30, did-schema
%   V_eta_go_forward_class_audit.md [trigger channels named by their link]):
%   'from trigger channel' is v1 daqsystem_ch1 and 'to trigger channel'
%   daqsystem_ch2. A configuration migrated before that decision holds them
%   under the v1 names, 'daqsystem ch1' / 'daqsystem ch2', which the own-name
%   path below reads back to the same two fields. A configuration holding a
%   channel under both spellings is reported, not merged.
s = struct();
bad = {};
if isempty(params)
    return;
end
if isstruct(params)
    params = num2cell(reshape(params, 1, []));
end
named = {'minimum matching file paths', 'number_fullpath_matches'; ...
    'sync file name', 'syncfilename'; ...
    'minimum embedded file overlap', 'minEmbeddedFileOverlap'; ...
    'from trigger channel', 'daqsystem_ch1'; ...   % [trigger channels named by their link]
    'to trigger channel', 'daqsystem_ch2'};
for k = 1:numel(params)
    e = params{k};
    [~, name] = termParts(getIn(e, 'variable'));
    if isempty(name)
        bad{end+1} = sprintf('method parameter %d has no name', k); %#ok<AGROW>
        continue;
    end
    [v, ok] = entryValue(e);
    if ~ok
        bad{end+1} = sprintf('method parameter "%s" states no value', name); %#ok<AGROW>
        continue;
    end
    hit = strcmp(named(:, 1), name);
    if any(hit)
        steps = named(hit, 2);
    else
        steps = strsplit(strrep(name, ' ', '_'), '.');
    end
    if isscalar(steps) && any(strcmp(steps{1}, {'daqsystem_ch1', 'daqsystem_ch2'})) ...
            && isfield(s, steps{1})
        % the same trigger channel under its link label and its v1 name
        % ([trigger channels named by their link]): the first is kept, the
        % second reported, so a disagreement cannot pass as a round trip
        bad{end+1} = sprintf('method parameter "%s": %s is stated twice', name, steps{1}); %#ok<AGROW>
        continue;
    end
    s = setPath(s, steps, v);
end
end

function [v, ok] = entryValue(e)
v = [];
ok = true;
c = getIn(e, 'count');
if ~isempty(c)
    v = c;
    return;
end
q = getIn(e, 'quantity', 'value');
if ~isempty(q)
    v = q;
    return;
end
t = getIn(e, 'text');
if ~isempty(t)
    v = char(t);
    if any(v(1) == '[{')
        try
            v = jsondecode(v);
        catch
        end
    end
    return;
end
l = getIn(e, 'logical');
if ~isempty(l)
    v = l;
    return;
end
ok = false;
end

function s = setPath(s, steps, v)
if isscalar(steps)
    s.(steps{1}) = v;
    return;
end
inner = struct();
if isfield(s, steps{1}) && isstruct(s.(steps{1})) && isscalar(s.(steps{1}))
    inner = s.(steps{1});
end
s.(steps{1}) = setPath(inner, steps(2:end), v);
end
