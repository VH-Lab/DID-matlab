function doc = statement(leafClass, subjectId, variable, value, options)
%STATEMENT A statement document: VARIABLE of SUBJECTID has VALUE.
%
%   DOC = did2.build.statement(LEAFCLASS, SUBJECTID, VARIABLE, VALUE, ...)
%   builds a statement -- LEAFCLASS a direction ('observation', 'assertion',
%   'manipulation', 'calculation') with its value-kind mixin given as
%   'ValueKind' ('voltage', 'term', 'dose', ...), or a named calculator
%   ('tuning_curve_calculation', ...) -- about the entity
%   SUBJECTID (its `entity_id` edge; usually a subject, any entity may be
%   described). VARIABLE is a term or a name; VALUE is the leaf's `value`, e.g.
%   from did2.build.valueCell or did2.build.term. VALUE may be [] when the
%   value lives elsewhere: in a body ('DataBody', true, then build the body
%   with did2.build.sampledBody/opaqueBody, owner = this document), or in a
%   standalone data_type document ('ValueId').
%
%   Everything else is optional and read from the leaf's schema; only what the
%   leaf declares is accepted.
%
%   Fields:
%     'Keys'              the value's dimensions (did2.build.key / list)
%     'Conditions'        one-value qualifiers (did2.build.condition / list)
%     'Method'            the technique: a term (or a name)
%     'MethodParameters'  the settings it ran with (did2.build.parameter /
%                         list). On the did-schema #88 shape both are
%                         written as ONE block, `method: {term, parameters}`
%                         (DID-schema V_eta_method_plan.md, 2026-10-21);
%                         before it, as `method` and `method_parameters`.
%                         An inline method OR 'MethodId', never both.
%     'DatumType'         value.data_type (value.datum_type before 2026-10-08;
%                         did2.build.datumType)
%     'SourceDatumType'   the source's own type name
%     'DataBody'          logical: the value is stored in a body
%     'Notes'             char
%     'ValueKind'         with LEAFCLASS a DIRECTION ('observation', 'assertion',
%                         'manipulation', 'calculation'): the value-kind mixin
%                         ('time', 'dose', ...) -- the did-schema #88 form; a
%                         joined '<kind>_<direction>' name from an old-vintage
%                         caller still resolves, but is never written here
%     'Fields'            any other declared field, as a struct
%   Edges:
%     'TimeReferenceIds'  cellstr: the statement's time references (T15
%                         `multiple`; the leaf declares how many it needs)
%     'InstrumentId'      the instrument (T7)
%     'SoftwareId'        the software that produced it
%     'MethodId'          a standalone `method` document (did2.build.method)
%                         -- the edge `method_id`, `method_parameters_id`
%                         before #88. 'MethodParametersId' is the same
%                         option under its old name.
%     'AcquisitionChannelsId'
%     'ValueId'           a standalone data_type document holding the value
%     'InputIds'          cellstr: a calculation's inputs (ordered)
%     'KeyIds'            cellstr: data_type documents a key takes its
%                         positions from (a key's `positions_from` indexes them)
%     'InterpreterId', 'OperatingSystemId'   a calculation's run environment
%     'Edges'             any other declared edge (see did2.build.document)
%   Document:
%     'SessionId' (required), 'Id', 'CreationTimestamp', 'Files', 'Validate',
%     'SchemaCache' -- as did2.build.document.
%
%   Example:
%     doc = did2.build.statement('observation', subjectId, 'voltage', ...
%         did2.build.valueCell('voltage', 0.012, 'SourceValue', 12, 'SourceUnit', 'mV'), ...
%         'SessionId', sessionId, 'TimeReferenceIds', {timeRefId}, ...
%         'InstrumentId', electrodeId, 'ValueKind', 'voltage');
%
%   See also did2.build.document, did2.build.valueCell, did2.build.key.

arguments
    leafClass (1,:) char
    subjectId (1,:) char
    variable
    value
    options.Keys = []
    options.Conditions = []
    options.Method = []
    options.MethodParameters = []
    options.DatumType = ''
    options.SourceDatumType = ''
    options.DataBody = []
    options.Notes = ''
    options.Fields (1,1) struct = struct()
    options.TimeReferenceIds = {}
    options.InstrumentId = ''
    options.SoftwareId = ''
    options.MethodId = ''
    options.MethodParametersId = ''
    options.AcquisitionChannelsId = ''
    options.ValueId = ''
    options.InputIds = {}
    options.KeyIds = {}
    options.InterpreterId = ''
    options.OperatingSystemId = ''
    options.Edges = struct()
    options.SessionId (1,:) char = ''
    options.Id (1,:) char = ''
    options.CreationTimestamp (1,:) char = ''
    options.Files = {}
    options.Validate (1,1) logical = true
    options.SchemaCache = []
    options.ValueKind (1,:) char = ''
end

fields = struct();
fields.variable = variable;
fields.value = value;
fields.keys = options.Keys;
fields.conditions = options.Conditions;
fields = methodFields(fields, options.Method, options.MethodParameters, options.SchemaCache);
[~, entityEdge, dataTypeField] = vetaNames(options.SchemaCache);   % `subject_id` / `datum_type` before 2026-10-08
fields.(dataTypeField) = options.DatumType;
fields.(['source_' dataTypeField]) = options.SourceDatumType;
fields.data_body = options.DataBody;
fields.notes = options.Notes;
fields = dropAbsent(fields);

shape = methodShape(options.SchemaCache);
methodId = options.MethodId;
if ~isAbsent(options.MethodParametersId)
    if ~isAbsent(methodId)
        error('did2:build:badOption', ...
            '''MethodId'' and ''MethodParametersId'' name the same edge; give one.');
    end
    methodId = options.MethodParametersId;
end
edges = struct( ...
    entityEdge, subjectId, ...
    'time_reference_id', {options.TimeReferenceIds}, ...
    'instrument_id', options.InstrumentId, ...
    'software_id', options.SoftwareId, ...
    shape.edge, methodId, ...
    'acquisition_channels_id', options.AcquisitionChannelsId, ...
    'value_id', options.ValueId, ...
    'input_id', {options.InputIds}, ...
    'key_id', {options.KeyIds}, ...
    'interpreter_id', options.InterpreterId, ...
    'operating_system_id', options.OperatingSystemId);

doc = forward(leafClass, fields, edges, options);
end

function s = dropAbsent(s)
names = fieldnames(s);
for k = 1:numel(names)
    if isAbsent(s.(names{k}))
        s = rmfield(s, names{k});
    end
end
end
