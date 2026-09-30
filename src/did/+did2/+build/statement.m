function doc = statement(leafClass, subjectId, variable, value, options)
%STATEMENT A statement document: VARIABLE of SUBJECTID has VALUE.
%
%   DOC = did2.build.statement(LEAFCLASS, SUBJECTID, VARIABLE, VALUE, ...)
%   builds a concrete statement leaf -- an observation, assertion, manipulation
%   or calculation ('voltage_observation', 'term_assertion',
%   'dose_manipulation', 'tuning_curve_calculation', ...) -- about the subject
%   SUBJECTID. VARIABLE is a term or a name; VALUE is the leaf's `value`, e.g.
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
%     'Method'            a term (or a name)
%     'MethodParameters'  inline settings (did2.build.parameter / list) --
%                         OR 'MethodParametersId', never both
%     'DatumType'         data_type.datum_type (did2.build.datumType)
%     'SourceDatumType'   the source's own type name
%     'DataBody'          logical: the value is stored in a body
%     'Notes'             char
%     'Fields'            any other declared field, as a struct
%   Edges:
%     'TimeReferenceIds'  cellstr: the statement's time references (T15
%                         `multiple`; the leaf declares how many it needs)
%     'InstrumentId'      the instrument (T7)
%     'SoftwareId'        the software that produced it
%     'MethodParametersId'
%     'AcquisitionChannelsId'
%     'ValueId'           a standalone data_type document holding the value
%     'InputIds'          cellstr: a calculation's inputs (ordered)
%     'InterpreterId', 'OperatingSystemId'   a calculation's run environment
%     'Edges'             any other declared edge (see did2.build.document)
%   Document:
%     'SessionId' (required), 'Id', 'CreationTimestamp', 'Files', 'Validate',
%     'SchemaCache' -- as did2.build.document.
%
%   Example:
%     doc = did2.build.statement('voltage_observation', subjectId, 'voltage', ...
%         did2.build.valueCell('voltage', 0.012, 'SourceValue', 12, 'SourceUnit', 'mV'), ...
%         'SessionId', sessionId, 'TimeReferenceIds', {timeRefId}, ...
%         'InstrumentId', electrodeId);
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
    options.MethodParametersId = ''
    options.AcquisitionChannelsId = ''
    options.ValueId = ''
    options.InputIds = {}
    options.InterpreterId = ''
    options.OperatingSystemId = ''
    options.Edges = struct()
    options.SessionId (1,:) char = ''
    options.Id (1,:) char = ''
    options.CreationTimestamp (1,:) char = ''
    options.Files = {}
    options.Validate (1,1) logical = true
    options.SchemaCache = []
end

fields = struct();
fields.variable = variable;
fields.value = value;
fields.keys = options.Keys;
fields.conditions = options.Conditions;
fields.method = options.Method;
fields.method_parameters = options.MethodParameters;
fields.datum_type = options.DatumType;
fields.source_datum_type = options.SourceDatumType;
fields.data_body = options.DataBody;
fields.notes = options.Notes;
fields = dropAbsent(fields);

edges = struct( ...
    'subject_id', subjectId, ...
    'time_reference_id', {options.TimeReferenceIds}, ...
    'instrument_id', options.InstrumentId, ...
    'software_id', options.SoftwareId, ...
    'method_parameters_id', options.MethodParametersId, ...
    'acquisition_channels_id', options.AcquisitionChannelsId, ...
    'value_id', options.ValueId, ...
    'input_id', {options.InputIds}, ...
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
