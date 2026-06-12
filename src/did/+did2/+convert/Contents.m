% +convert  did_v1 -> active-set document conversion utilities.
%
%   The +convert subpackage implements PLAN.md §7 plus the step-6
%   sub-steps in §9.6: the v1-to-active-set migration dispatcher, the
%   universal-rename pass, per-class migrator functions, and the
%   legacy-database readers plus end-to-end orchestrator that drive the
%   dispatcher off real v1 database files.
%
%   The target schema set is whatever did2.schema.cache is pointed at —
%   V_epsilon by default. The dispatcher reads the set-version string
%   from the cache (index.json `schema_version_value`) and stamps it on
%   every migrated document, so retargeting a new set version needs no
%   code change here. Migrators may fan out (return a cell array of
%   bodies) when a single v1 document maps to several target documents
%   (e.g. the treatment split, subject_group -> subject + group
%   assignments, and any interaction that mints a time_reference).
%
%   Files
%     fromV1Database   - end-to-end orchestrator. Sniffs the source
%                        path (file -> sqliteV1 reader, directory ->
%                        dumbJsonV1 reader), pipes the raw JSON bodies
%                        through v1_to_v2, writes the successes into a
%                        fresh did2.database.sqlitedb at the
%                        destination, and writes any quarantine
%                        entries to <dst>.quarantine.json. Refuses to
%                        overwrite existing files unless Overwrite=true.
%     v1_to_v2         - dispatcher and CLI entry point. Accepts one
%                        or more did_v1 bodies (struct, struct array,
%                        cell array, or JSON string) and returns a
%                        result struct with `migrated`, `quarantine`,
%                        and `summary` fields.
%     universalRenames - the cross-cutting did_v1 -> V_delta rewrites
%                        (snake-case class names, schema_version on
%                        document_class, depends_on entry shape) from
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
%     +readers         - pure-read entry points for the two v1 DID
%                        storage formats. sqliteV1 reads the legacy
%                        did.implementations.sqlitedb docs.json_code
%                        column; dumbJsonV1 walks a
%                        did.implementations.matlabdumbjsondb tree
%                        and returns the latest version of every
%                        Object_id_*_v#####.json file.
%
%   See also: docs/v2/PLAN.md §7, §9.6.
