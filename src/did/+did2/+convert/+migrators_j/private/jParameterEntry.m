function e = jParameterEntry(variableName, canonicalValue, sourceUnit, sourceValue)
%JPARAMETERENTRY Build ONE `parameter` entry for a V_eta method_parameters list.
%
%   The entry shape is declared on schemas/V_eta/stable/method_parameters.json
%   (field `method_parameters`, an array of structs) and is mounted under the
%   SAME field name in both places it appears -- inline on subject_interaction
%   and in the method_parameters document:
%
%       variable     ontology_term   REQUIRED, bound, unique within the list
%       unit         ontology_term   canonical unit of a number
%       source_unit  char            the unit as the source wrote it
%       approximate  boolean
%       quantity     { value, source_value }   numeric knobs
%       term         ontology_term             categorical knobs
%       count        integer                   integer knobs
%       text         char                      free strings
%
%   (data_body AMENDMENT 3: the same entry as a statement's `conditions`.)
%
%   This helper builds the NUMERIC form only (variable + source_unit +
%   quantity), because every bound knob in the spike-processing family is
%   numeric. The other slots are optional and are left off rather than emitted
%   blank -- a blank {node:'',name:''} term on every row is noise the
%   fragment/vacuous counters would have to learn to ignore.
%
%   THIS HELPER WRITES NO `unit` (and the entry has no `data_type`): a
%   parameter's dimension comes from its bound `variable` via the registry, the
%   same rule the `axis` entry follows. `source_unit` is not that -- it records
%   WHAT THE SOURCE WROTE, and across all four v1 spike-parameter templates the
%   source writes no unit at all, so callers in this family pass ''.
%
%   canonicalValue is a double; sourceValue is the source's own spelling kept
%   verbatim (v1 writes vmspikefilteringparameters.threshold as the STRING
%   "0.030", and that string survives whatever the registry later says).
%
%   Shared helper for the Brainstorm-J (+migrators_j) method_parameters fold.
arguments
    % NO SIZE SPECS ON THE CHAR ARGUMENTS, deliberately: '' is 0-by-0 and a
    % `(1,:) char` constraint rejects it. Every caller here passes '' for at
    % least one of source_unit / source_value (v1 records no units in this
    % family, and a COMPUTED value has no source spelling), so the constraint
    % that reads as tidy would fail on the ordinary path.
    variableName char
    canonicalValue (1,1) double
    sourceUnit char = ''
    sourceValue char = ''
end

% did-schema #88: one entry {variable, unit, source_unit, approximate,
% quantity {value, source_value}} (data_body AMENDMENT 3), built by
% did2.build.parameter. SOURCEUNIT, given as text, becomes a term (jSourceUnit).
args = {'Value', canonicalValue};
if ~isempty(sourceValue); args = [args, {'SourceValue', sourceValue}]; end
if ~isempty(sourceUnit); args = [args, {'SourceUnit', jSourceUnit(sourceUnit)}]; end
e = did2.build.parameter(jLabel(variableName), args{:});
end
