% +did2  DID v2 (V_eta) MATLAB toolbox — development scaffold.
%
%   The +did2 package is the parallel-namespace v2 line of DID-matlab.
%   It consumes the V_eta schema set from the did-schema repository
%   directly, without translating to the V_alpha base.* /
%   document_class.* / <property_list_name> nesting that the legacy +did
%   package uses.
%
%   Files
%     document      - V2 document object (load / validate /
%                     serialise / dot-path access).
%     query         - V2 query value and in-memory evaluator
%                     (the executable spec for the SQL compiler).
%     Contents      - this overview.
%
%   Subpackages
%     +schema       - schema cache and validation entry points.
%     +database     - storage backends. Currently `sqlitedb` (sqlite3
%                     + JSON1 fallback, with the step-4 generated
%                     columns for queryable scalars and the step-5
%                     queryable_array_elem sidecar for queryable
%                     array-iteration paths) and `compileQuery` (the
%                     JSON1 SQL compiler that routes scalar leaves to
%                     the generated columns and `[*]` leaves to the
%                     sidecar when their dot-path is in the indexed
%                     set).
%     +convert      - did_v1 -> V2 document migration utilities.
%                     `v1_to_v2` is the dispatcher / CLI entry;
%                     `universalRenames` runs the cross-cutting did_v1
%                     -> V2 rewrites; `+migrators` holds the
%                     per-class migrators (currently `identity` plus
%                     the four 2.0.0-bumped classes `probe_location`,
%                     `treatment`, `ontology_image`, and
%                     `ontology_label`).
%
%   Conventions
%     - New code uses camelCase identifiers and arguments-block input
%       validation, per AGENTS.md.
%     - Document data is the V2 class-scoped JSON shape
%       (top-level `document_class` header, top-level `depends_on`
%       array, and one property block per class in the chain keyed
%       by class name; no underscore-prefixed keys).
%     - The schema cache is the single source of truth for what
%       "valid" means; runtime reflection over values never substitutes
%       for the schema.
%
%   See also: did.
