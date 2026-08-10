function e = jParameterEntry(variableName, canonicalValue, sourceUnit, sourceValue)
%JPARAMETERENTRY Build ONE `parameter` entry for a V_eta method_parameters list.
%
%   The entry shape is declared on schemas/V_eta/stable/method_parameters.json
%   (field `method_parameters`, an array of structs) and is mounted under the
%   SAME field name in both places it appears -- inline on subject_interaction
%   and in the method_parameters document:
%
%       variable   ontology_term   REQUIRED, bound, unique within the list
%       value      { value, source_unit, source_value }   numeric knobs
%       term       ontology_term                          categorical knobs
%       text       char                                   free strings
%
%   This helper builds the NUMERIC form only (variable + value), because every
%   bound knob in the spike-processing family is numeric. The other two slots
%   are optional and are left off rather than emitted blank -- a blank
%   {node:'',name:''} term on every row is noise the fragment/vacuous counters
%   would have to learn to ignore.
%
%   THERE IS NO `unit` FIELD AND NO `data_type` FIELD, by decision: a
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
    variableName (1,:) char
    canonicalValue (1,1) double
    sourceUnit (1,:) char = ''
    sourceValue (1,:) char = ''
end

e = struct();
e.variable = jOntologyTerm('', variableName);
e.value = struct('value', canonicalValue, ...
    'source_unit', sourceUnit, ...
    'source_value', sourceValue);
end
