% +did2  DID v2 (V_gamma) MATLAB toolbox — development scaffold.
%
%   The +did2 package is the parallel-namespace v2 line of DID-matlab.
%   It consumes the V_gamma schema set from the did-schema repository
%   directly, without translating to the V_alpha base.* /
%   document_class.* / <property_list_name> nesting that the legacy +did
%   package uses. See docs/v2/PLAN.md for the full design and the
%   step-by-step order of work.
%
%   Files
%     document      - V_gamma document object (load / validate /
%                     serialise / dot-path access).
%     Contents      - this overview.
%
%   Subpackages
%     +schema       - schema cache and validation entry points.
%     +convert      - (planned) v1-to-v2 conversion utilities.
%     +query        - (planned) query tree, in-memory evaluator,
%                     SQLite/JSON1 compiler.
%
%   Conventions
%     - New code uses camelCase identifiers and arguments-block input
%       validation, per AGENTS.md.
%     - Document data is the flat V_gamma JSON shape (top-level
%       snake_case keys; system metadata prefixed with `_`).
%     - The schema cache is the single source of truth for what
%       "valid" means; runtime reflection over values never substitutes
%       for the schema.
%
%   See also: did, docs/v2/PLAN.md.
