function objClass = elementClassOfKind(kind, elementType)
%ELEMENTCLASSOFKIND The v1 `ndi_element_class` of an element, rebuilt from what it is.
%
%   OBJCLASS = did2.convert.elementClassOfKind(KIND, ELEMENTTYPE) is the
%   MATLAB class NDI constructs for an element, rebuilt from what kind of
%   element it is and its v1 element type, or '' when it cannot be rebuilt:
%
%     'probe'     the class NDI's probe type table names for ELEMENTTYPE
%                 (NDI-matlab src/ndi/ndi_common/probe/probetype2object.json,
%                 the same at the locked `main` 73f46d19 and at V2 39d8603c;
%                 copied below, compared exactly as NDI's probestruct2probe
%                 matches its keys, edge blanks aside); '' when the table has
%                 no row for it
%     'unit'      'ndi.neuron' (a single unit, a `cell`, or one multi-unit,
%                 a `Group` with no members; v1 type `spikes`)
%     'ensemble'  'ndi.element.ensemble' (a `Group` that `member_of`
%                 relations point into)
%     anything else  ''
%
%   Decided by Jess Haley (did-schema docs/plans/did_v2_go_forward_class_audit.md):
%   2026-10-27 [ndi element class not kept] ("the round trip rebuilds
%   `element.ndi_element_class` from the entity type and device kind (for a
%   probe type, NDI's `probetype2object.json`), and an element whose class
%   cannot be rebuilt that way is brought to the team"); 2026-11-10 [element
%   recognised by its links] and [ensemble has members]. It is the rule
%   NDI-matlab's reader uses (ndi.vintage.elementClassOfKind, NDI-matlab
%   #1214, 39d8603c).
%
%   See also did2.convert.migrators_j.element, did2.convert.roundtrip.element.

arguments
    kind = ''
    elementType = ''
end

objClass = '';
switch char(kind)
    case 'probe'
        ty = strtrim(char(elementType));
        if isempty(ty)
            return;
        end
        table = PROBE_CLASSES();
        hit = strcmp(table(:, 1), ty);
        if nnz(hit) == 1
            objClass = table{hit, 2};
        end
    case 'unit'
        objClass = 'ndi.neuron';
    case 'ensemble'
        objClass = 'ndi.element.ensemble';
end
end

function t = PROBE_CLASSES()
% NDI-matlab src/ndi/ndi_common/probe/probetype2object.json (locked `main`
% 73f46d19 = V2 39d8603c), row for row
t = {
    'n-trode',             'ndi.probe.timeseries.mfdaq'
    'electrode-$',         'ndi.probe.timeseries.mfdaq'
    'patch',               'ndi.probe.timeseries.mfdaq'
    'patch-Vm',            'ndi.probe.timeseries.mfdaq'
    'patch-I',             'ndi.probe.timeseries.mfdaq'
    'patch-attached',      'ndi.probe.timeseries.mfdaq'
    'sharp',               'ndi.probe.timeseries.mfdaq'
    'sharp-Vm',            'ndi.probe.timeseries.mfdaq'
    'sharp-Im',            'ndi.probe.timeseries.mfdaq'
    'wide-field-imaging',  'ndi.probe.image'
    'two-photon-imaging',  'ndi.probe.image'
    'one-photon-imaging',  'ndi.probe.image'
    'brightfield-imaging', 'ndi.probe.image'
    'lick-spout',          'ndi.probe.timeseries.mfdaq'
    'intraoral-cannula',   'ndi.probe.timeseries.stimulator'
    'optogenetic-fiber',   'ndi.probe.timeseries.stimulator'
    'reward-well',         'ndi.probe.timeseries.mfdaq'
    'stimulator',          'ndi.probe.timeseries.stimulator'
    'ecg',                 'ndi.probe.timeseries.mfdaq'
    'eeg',                 'ndi.probe.timeseries.mfdaq'
    'accelerometer',       'ndi.probe.timeseries.mfdaq'
    'thermometer',         'ndi.probe.timeseries.mfdaq'
    'ppg',                 'ndi.probe.timeseries.mfdaq'
    'event',               'ndi.probe.timeseries.stimulator'};
end
