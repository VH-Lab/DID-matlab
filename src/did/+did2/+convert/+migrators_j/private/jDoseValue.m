function v = jDoseValue(chemicals)
%JDOSEVALUE Build a V_eta `dose.value` composite: a formulation (one or more
%   {substance, amount} chemicals) delivered at a volume/route. `chemicals` is a
%   struct array with fields substance (ontology_term) and amount
%   (concentration composite). Volume and route are left blank for curator /
%   discovery-mode fill-in (route -> `method` when the source names one).
%
%   Built by dot-assignment, NOT the struct(...) constructor: passing a
%   non-scalar struct array as a constructor value would broadcast the whole
%   composite into a struct array. Assignment stores `chemicals` as a single
%   field value regardless of its length.
%
%   The concentration / volume composite shapes are discovery-tuned seeds
%   (matched to real corpora in the corpus test), consistent with how the
%   +migrators_i injection mixture was seeded.
%
%   Shared helper for the Brainstorm-J (+migrators_j) split migrators.
formulation = struct();
formulation.chemicals = chemicals;

v = struct();
v.formulation = formulation;
% `volume` is a dimensioned composite type ({source_unit, source_value,
% approximate}), not a bare double -- a scalar would fail validation. Blank
% (0.0, '') is the curator's signal that a delivered volume was not recovered.
v.volume = struct('source_unit', '', 'source_value', 0.0, 'approximate', false);
v.route = jOntologyTerm('', '');
end
