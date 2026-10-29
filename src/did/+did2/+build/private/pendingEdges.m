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
%     None is pending. The one entry this held, coordinate_system_id on
%     `statement` ([site frame is a coordinate system], Decided by Jess Haley,
%     2026-10-27, did-schema V_eta_go_forward_class_audit.md), was deleted
%     once did-schema declared that edge: did-schema 64ad58b8 declares
%     `coordinate_system_id` on `statement` (schemas/did_v2/stable/
%     statement.json: optional, one id, to a `coordinate_system`), so the
%     schema's declaration is the one did2.build reads. The mechanism stays
%     for the next edge that must be accepted ahead of the schema.

pending = struct('on', {}, 'def', {});
end
