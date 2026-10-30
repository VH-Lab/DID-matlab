function [kind, variable, types] = elementDeviceKind(elementType)
%ELEMENTDEVICEKIND The decided device kind of a v1 probe type.
%
%   [KIND, VARIABLE] = did2.convert.elementDeviceKind(ELEMENTTYPE) returns the
%   device-kind term (a {node, name} struct) of the v1 element type
%   ELEMENTTYPE (compared exactly, edge blanks aside, as NDI's
%   probestruct2probe matches its keys), or [] when no kind is decided for it.
%   VARIABLE is the term the kind is asserted under: NCIT:C178920 "Equipment
%   Type", the binding registry's subject-defining variable for a device's
%   finer kind (did-schema binding_registry_meta.json
%   subject_statement_bindings; schemas/did_v2/stable/interaction.json
%   `instrument_id`: "its finer kind is an `Equipment Type` assertion").
%
%   [~, ~, TYPES] = did2.convert.elementDeviceKind('') lists the v1 types
%   that have a kind, with their terms: an N x 3 cell {type, node, name}.
%   Several types share a kind (a patch electrode, a sharp electrode, a
%   microscope); did2.convert.elementTypeOfKind reads a kind back to its type
%   only where one type has it.
%
%   Each row is a decision (Decided by Jess Haley, did-schema
%   V_eta_go_forward_class_audit.md), under [element type is a device kind
%   term] (2026-10-27: one term per instrument), for an element whose
%   `ndi_element_class` starts `ndi.probe.`; each term is a row of did-schema
%   schemas/V_eta_term_registry.json:
%     n-trode             wikidata:Q1952355 multielectrode array
%                         [n-trode is a multielectrode array],
%                         [element types batch 1]
%     patch, patch-Vm, patch-I, patch-attached
%                         EMPTY:0000411 patch electrode
%     sharp, sharp-Vm, sharp-Im
%                         EMPTY:0000412 sharp electrode
%                         [element types batch 1]; the suffix is the
%                         recording mode, on the recording observation
%     wide-field-imaging, two-photon-imaging, one-photon-imaging,
%     brightfield-imaging OBI:0400169 microscope
%                         [element types batch 2] (narrows [imaging probes
%                         are microscopes or carried]: wide-field and
%                         brightfield are no longer carried); the imaging
%                         mode is a method term on the recording observation
%                         ([imaging mode is a method term])
%     lick-spout          EMPTY:0000414 lick spout
%     reward-well         EMPTY:0000415 reward port
%     intraoral-cannula   NCIT:C50343 Cannula Device
%     optogenetic-fiber   NCIT:C50358 Fiber Optic Device
%                         [element types batch 2]
%     ecg                 OBI:0003806 electrocardiograph
%     eeg                 wikidata:Q4531135 electroencephalograph
%     accelerometer       NCIT:C88166 Accelerometer
%     thermometer         NCIT:C50059 Thermometer Device
%     ppg                 NCIT:C224112 Photoplethysmography Sensor
%                         [element types batch 3]
%     electrode-$         NCIT:C49936 Electrode Device (the literal key of
%                         NDI probetype2object.json) [element types batch 4]
%   NOT HERE: `stimulator`, `event` and the spellings `electrode-<spec>` /
%   `<prefix>_electrode-<spec>`, which [element types batch 4] carries whole
%   as v1, needs_mapping.
%
%   See also did2.convert.elementTypeOfKind, did2.convert.migrators_j.element,
%   did2.convert.roundtrip.element.

arguments
    elementType = ''
end

types = {
    'n-trode',             'wikidata:Q1952355', 'multielectrode array'
    'patch',               'EMPTY:0000411',     'patch electrode'
    'patch-Vm',            'EMPTY:0000411',     'patch electrode'
    'patch-I',             'EMPTY:0000411',     'patch electrode'
    'patch-attached',      'EMPTY:0000411',     'patch electrode'
    'sharp',               'EMPTY:0000412',     'sharp electrode'
    'sharp-Vm',            'EMPTY:0000412',     'sharp electrode'
    'sharp-Im',            'EMPTY:0000412',     'sharp electrode'
    'wide-field-imaging',  'OBI:0400169',       'microscope'
    'two-photon-imaging',  'OBI:0400169',       'microscope'
    'one-photon-imaging',  'OBI:0400169',       'microscope'
    'brightfield-imaging', 'OBI:0400169',       'microscope'
    'lick-spout',          'EMPTY:0000414',     'lick spout'
    'reward-well',         'EMPTY:0000415',     'reward port'
    'intraoral-cannula',   'NCIT:C50343',       'Cannula Device'
    'optogenetic-fiber',   'NCIT:C50358',       'Fiber Optic Device'
    'ecg',                 'OBI:0003806',       'electrocardiograph'
    'eeg',                 'wikidata:Q4531135', 'electroencephalograph'
    'accelerometer',       'NCIT:C88166',       'Accelerometer'
    'thermometer',         'NCIT:C50059',       'Thermometer Device'
    'ppg',                 'NCIT:C224112',      'Photoplethysmography Sensor'
    'electrode-$',         'NCIT:C49936',       'Electrode Device'};
variable = did2.build.term('NCIT:C178920', 'Equipment Type');
kind = [];
ix = find(strcmp(strtrim(char(elementType)), types(:, 1)), 1);
if ~isempty(ix)
    kind = did2.build.term(types{ix, 2}, types{ix, 3});
end
end
