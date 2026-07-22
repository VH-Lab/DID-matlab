function bodies = distance_metadata(preBody)
%DISTANCE_METADATA Brainstorm-J migrator: reshape a did_v1 distance_metadata into
%   the validated V_eta distance_metadata. 1 -> 1.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'. The v1
%   doc is FLAT and records the two ENDPOINTS of a distance measurement, not the
%   distance itself: `ontologyNode_A` is the animal-subject doc id, `ontologyNode_B`
%   a patch (ontology_table_row) doc id, `ontologyNumericValues_A/_B` are `[]` by
%   design, `units` a CURIE, and `depends_on element_id` points at the `distance`
%   TIMESERIES element (where the actual distances over time live).
%
%   The V_eta distance_metadata schema is shape-identical to V_delta's (the flat
%   per-endpoint A/B fields collapse into a nested `endpoints` array-of-records +
%   an `units` ontology_term), so this DELEGATES to the proven, tested V_delta
%   migrator (did2.convert.migrators.distance_metadata -- regex label discovery,
%   string/numeric handling, ndi.ontology.lookup name resolution) and wraps its one
%   body in the cell the J pipeline expects.
%
%   It deliberately does NOT:
%     - emit a `length_observation`: there is no scalar distance in the metadata
%       doc (the value is the linked element's timeseries) -- Part B, a genuine
%       second pass riding on the element-data -> observation decomposition
%       (deferred, overlaps #9); do not fabricate a values-less observation; and
%     - mint an endpoint relation: both endpoint ids are PRE-migration ids that
%       dangle in a single-doc pass (Part A was tried and reverted, corpus
%       946faf95: 4156 JH orphans, a gating failure). The endpoints can only be
%       resolved by the second pass, which sees the migrated-id graph.
%
%   The reshape clears the ~2078 JH quarantines (the old J code read a nested
%   `endpoints.numeric_values` that never exists -> no-vals passthrough of the flat
%   doc -> failed the required non-empty `endpoints`). See
%   schemas/V_eta_distance_metadata_plan.md.
arguments
    preBody (1,1) struct
end
bodies = { did2.convert.migrators.distance_metadata(preBody) };
end
