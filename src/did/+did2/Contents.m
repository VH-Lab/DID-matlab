% +did2  DID v2 MATLAB toolbox: V_eta documents, schema, storage and migration.
%
%   The +did2 package is the parallel-namespace v2 line of DID-matlab. It
%   consumes the V_eta schema set from the did-schema repository
%   (schemas/V_eta/{stable,draft,deprecated}) directly, without translating
%   to the V_alpha base.* / document_class.* / <property_list_name> nesting
%   that the legacy +did package uses. did-schema deleted the older sets
%   (V_alpha .. V_zeta, OPEN_WORK #128, 2026-10-21); V_eta is the only one.
%
%   The schema is found through the DID_SCHEMA_PATH environment variable;
%   without it, did2.schema.cache.defaultSchemaPath reads a sibling
%   did-schema checkout's schemas/did_v2/stable (else schemas/V_eta/stable),
%   or schemas/did_v2 itself once it has no tiers ([one folder, final classes
%   only], Jess Haley, 2026-10-29). The CI workflows copy the tiers, or the
%   flat folder's class files, into one directory and set DID_SCHEMA_PATH to it.
%
%   Files
%     document      - document object (load / validate / serialise /
%                     dot-path access).
%     query         - query value and in-memory evaluator (the executable
%                     spec for the SQL compiler).
%     Contents      - this overview.
%
%   Subpackages
%     +schema       - the schema cache (did2.schema.cache: class lookup,
%                     superclass chains, validateDocument and the strict
%                     modes) and the term-registry lookups.
%     +build        - builders for V_eta documents that are right by
%                     construction (statements, bodies, relations, time
%                     references, methods). See +build/Contents.m.
%     +database     - storage backends: `sqlitedb` (sqlite3 + JSON1, with
%                     generated columns for queryable scalars and the
%                     queryable_array_elem sidecar for array paths) and
%                     `compileQuery` (the JSON1 SQL compiler).
%     +convert      - did_v1 -> V_eta migration: the dispatcher `v1_to_v2`,
%                     the per-document migrators (+migrators_j), and the
%                     batch post-passes. See +convert/Contents.m.
%     +validate     - report-only censuses and checks over a migrated batch
%                     (references, silentLoss, fileList, sourceCensus, ...).
%
%   Conventions
%     - New code uses camelCase identifiers and arguments-block input
%       validation, per AGENTS.md.
%     - Document data is the class-scoped JSON shape (top-level
%       `document_class` header, top-level `depends_on` array, and one
%       property block per class in the chain keyed by class name; no
%       underscore-prefixed keys).
%     - The schema cache is the single source of truth for what
%       "valid" means; runtime reflection over values never substitutes
%       for the schema.
%
%   See also: did, did2.schema.cache, did2.build, did2.convert.v1_to_v2.
