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
%
%   Each row is a decision (Decided by Jess Haley, did-schema
%   V_eta_go_forward_class_audit.md), under [element type is a device kind
%   term] (2026-10-27: one term per instrument; a type with no decided term
%   keeps today's assertion only), and each term is a row of did-schema
%   schemas/V_eta_term_registry.json:
%     n-trode             wikidata:Q1952355 multielectrode array
%                         [n-trode is a multielectrode array]
%     accelerometer       NCIT:C88166 Accelerometer
%     thermometer         NCIT:C50059 Thermometer Device
%     ppg                 NCIT:C224112 Photoplethysmography Sensor
%     optogenetic-fiber   NCIT:C50358 Fiber Optic Device
%     intraoral-cannula   NCIT:C50343 Cannula Device
%                         [five probe kinds from NCIT]
%     ecg                 OBI:0003806 electrocardiograph
%     eeg                 wikidata:Q4531135 electroencephalograph
%                         [ecg and eeg are recorders] (Wikidata searched
%                         2026-10-28: the item exists, so `eeg` takes it)
%     one-photon-imaging, two-photon-imaging
%                         OBI:0400169 microscope
%                         [imaging probes are microscopes or carried]
%   NOT HERE, because no term is registered yet: patch*, sharp*, stimulator,
%   lick-spout, reward-well ([device kinds minted], [device kind labels and
%   synonyms]: empty-ontology and did-schema builds pending), and `event` and
%   the electrode spellings (no kind proposed). wide-field-imaging and
%   brightfield-imaging are carried (carry-121), not given a kind.
%
%   See also did2.convert.migrators_j.element, did2.convert.roundtrip.element.

arguments
    elementType = ''
end

types = {
    'n-trode',            'wikidata:Q1952355', 'multielectrode array'
    'accelerometer',      'NCIT:C88166',       'Accelerometer'
    'thermometer',        'NCIT:C50059',       'Thermometer Device'
    'ppg',                'NCIT:C224112',      'Photoplethysmography Sensor'
    'optogenetic-fiber',  'NCIT:C50358',       'Fiber Optic Device'
    'intraoral-cannula',  'NCIT:C50343',       'Cannula Device'
    'ecg',                'OBI:0003806',       'electrocardiograph'
    'eeg',                'wikidata:Q4531135', 'electroencephalograph'
    'one-photon-imaging', 'OBI:0400169',       'microscope'
    'two-photon-imaging', 'OBI:0400169',       'microscope'};
variable = did2.build.term('NCIT:C178920', 'Equipment Type');
kind = [];
ix = find(strcmp(strtrim(char(elementType)), types(:, 1)), 1);
if ~isempty(ix)
    kind = did2.build.term(types{ix, 2}, types{ix, 3});
end
end
