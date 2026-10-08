function bodies = stimulus_response_scalar(preBody)
%STIMULUS_RESPONSE_SCALAR Brainstorm-J migrator: did_v1 stimulus_response_scalar
%   -- CONVERTED TO A GUARDED PASSTHROUGH in PR #68 (Waltham-Data-Science/
%   DID-schema/pull/68). The previous target class `harmonic_component_calculation`
%   was DELETED from V_eta under the calculator restructure -- see issue #67
%   decision 10 -- so there is no destination for the fold. The document is
%   passed through UNCHANGED for the NDI second pass.
%
%   THE OLD FOLD, FOR REFERENCE ONLY (superseded by PR #68):
%     stimulus_response_scalar -> the subject_calculation LEAF
%     harmonic_component_calculation (id PRESERVED) + a time anchor. The full
%     mapping and its evidence -- element_id -> subject_id, stimulator_id ->
%     instrument_id (recovered), stimulus_control_id -> derived_from_2
%     (recovered), the epoch-gate three-branch, the parameters-id re-home to
%     `subject_interaction.method_parameters_id`, the stimid deferral, ... --
%     lived here through 2026-08-10 and is preserved in git history if a
%     replacement leaf is minted. Do NOT re-attach any of it without a new
%     signed target class; a fold to a class that does not exist quarantines
%     every document silently, which is the exact defect this rewrite prevents.
%
%   The v1 tombstone for `stimulus_response_scalar` is kept (STABLE tier) so
%   the passthrough validates. Routed from did2.convert.v1_to_v2 only when
%   TargetVersion == 'V_eta'.
%
%   1 -> 1. Presence of this file (vs. an omission) preserves the migrator-
%   roster gate's expectation that every v1 class has an EXPLICIT disposition.
arguments
    preBody (1,1) struct
end
bodies = {preBody};
end
