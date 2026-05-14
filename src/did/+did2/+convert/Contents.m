% +convert  did_v1 -> V_delta document conversion utilities.
%
%   The +convert subpackage implements PLAN.md §7 plus the step-6
%   sub-steps in §9.6: the v1-to-V_delta migration dispatcher, the
%   universal-rename pass, and per-class migrator functions for the
%   four 2.0.0-bumped classes.
%
%   Files
%     v1_to_v2         - dispatcher and CLI entry point. Accepts one
%                        or more did_v1 bodies (struct, struct array,
%                        cell array, or JSON string) and returns a
%                        result struct with `migrated`, `quarantine`,
%                        and `summary` fields.
%     universalRenames - the cross-cutting did_v1 -> V_delta rewrites
%                        (snake-case class names, schema_version on
%                        base, depends_on entry shape) from
%                        did-schema's _universal_renames.md.
%
%   Subpackages
%     +migrators       - per-class migration functions, named after
%                        the v1 class name (post-universal-rename).
%                        `identity` is the default fallback for
%                        unregistered classes. The dispatcher resolves
%                        a function under this namespace by class
%                        name and calls it with the post-universal
%                        body.
%
%   See also: docs/v2/PLAN.md §7, §9.6.
