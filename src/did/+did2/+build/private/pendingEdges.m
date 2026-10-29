function pending = pendingEdges()
%PENDINGEDGES Edges did2.build accepts before did-schema declares them.
%
%   PENDING = pendingEdges() is a struct array {on, def}: did2.build.document
%   accepts the edge DEF (a `depends_on` entry, as a schema would declare it)
%   on any document whose class chain contains the class ON, but ONLY while no
%   class in that chain declares an edge of that name. Once the schema
%   declares it, the schema's declaration is the one used, whatever it says.
%
%   WHY THIS EXISTS. A new edge on a schema class is read live by DID-matlab
%   and NDI-matlab CI, so "did2.build accepts the edge first" (did-schema
%   CLAUDE.md section 3, "Changes the siblings must follow land in the
%   siblings first"): a class that declared an edge before the builder knew
%   it would only be safe because did2.build reads declarations, and a
%   migrator that wrote it before the schema declared it would be refused
%   (did2:build:unknownEdge). An entry here lets both halves land in either
%   order. Delete an entry once did-schema declares the edge.
%
%   THE ENTRIES
%
%     coordinate_system_id on `statement`, optional, one id, to a
%       `coordinate_system`. [site frame is a coordinate system] (Decided by
%       Jess Haley, 2026-10-27, did-schema V_eta_go_forward_class_audit.md):
%       "each probe gets one `coordinate_system` whose referent is the device
%       entity ... and each site value links to it by a new optional
%       `coordinate_system_id` edge on statements. Build pending: DID-matlab
%       (`did2.build` accepts the edge first; `+migrators_j/probe_geometry.m`),
%       did-schema (the edge on the statement classes; `coordinate_system` out
%       of draft)." One id: a value is in one coordinate system (the draft
%       `position.coordinate_system_id` is one id to the same class).
%       Declared on `statement`, so every direction (assertion, observation,
%       manipulation, calculation) inherits it.

pending = struct('on', {}, 'def', {});
pending(end+1) = struct('on', 'statement', 'def', struct( ...
    'name', 'coordinate_system_id', ...
    'mustBeNonEmpty', false, ...
    'must_refer_to_document_class', 'coordinate_system', ...
    'documentation', ['The coordinate system the value''s coordinates are in ' ...
        '([site frame is a coordinate system], Jess Haley, 2026-10-27). ' ...
        'Accepted by did2.build ahead of did-schema (+build/private/pendingEdges.m).']));
end
