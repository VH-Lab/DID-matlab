% +convert  did_v1 -> V_eta document conversion utilities.
%
%   The +convert subpackage migrates did_v1 document bodies to the V_eta
%   schema (did-schema schemas/V_eta). It holds the dispatcher, the
%   per-document migrators, the batch post-passes that need a whole corpus,
%   and the legacy-database readers.
%
%   THE TARGET. v1_to_v2's TargetVersion is 'V_delta' (the argument's default)
%   or 'V_eta'. Only 'V_eta' routes through +migrators_j; the V_delta schema
%   set the default names was deleted from did-schema (OPEN_WORK #128,
%   2026-10-21), as were the 'V_epsilon' and 'V_zeta' targets and their
%   +migrators_e / +migrators_i packages. The unit tests that still run the
%   'V_delta' target read a small V_delta fixture schema
%   (tests/+did2/fixtures/V_delta). See v1_to_v2's own help.
%
%   STATEMENTS. A V_eta statement's class is its direction (`observation`,
%   `assertion`, `manipulation`, `calculation`) and its value kind (`voltage`,
%   `term`, `dose`, ...) is a mixin in `superclasses`; the only named
%   statement classes are the eight vision calculators. A joined
%   '<kind>_<direction>' name is not a class: statementKind reads one from
%   old-vintage input, and nothing writes one
%   (tests/+did2/+unittest/testNoOldLeafNames.m).
%
%   Dispatcher and per-document steps
%     v1_to_v2           - dispatcher and CLI entry point. Accepts one or
%                          more did_v1 bodies (struct, struct array, cell
%                          array, or JSON string) and returns a result
%                          struct with `migrated`, `quarantine` and
%                          `summary` fields (plus the audit censuses).
%     universalRenames   - the cross-cutting did_v1 renames applied before
%                          any migrator.
%     ensureClassBlocks  - give a body exactly the class blocks its schema
%                          chain hosts.
%     isAlreadyTarget    - true when a body is already at (or past) the
%                          target version, so a re-run skips it.
%     schemaVersionRank  - where a schema version sits in the did_v1 ->
%                          V_eta line.
%     statementKind      - the direction class and value kind of a statement.
%     fromV1Database     - end-to-end orchestrator: reads a v1 database
%                          (file -> sqliteV1, directory -> dumbJsonV1),
%                          runs v1_to_v2 with its default TargetVersion,
%                          writes the successes into a fresh
%                          did2.database.sqlitedb and the quarantine to
%                          <dst>.quarantine.json.
%
%   Shared helpers used by migrators
%     calcCommon, channelType, epochIndex, ethicsJurisdiction,
%     registeredTerm, reportNote, mintSessionDuring
%
%   Batch post-passes (run over a migrated batch, after v1_to_v2; each
%   carries a BATCH-PASS declaration read by tools/batch_pass_declarations.py)
%     epochMint, foldGenericFiles, resolveClockAlignment, resolveDatasetEntities,
%     resolveDeferredBaths, resolveEpochProbemap, resolveLawnPlateSubjects,
%     resolveOpenmindsCitations, resolveResponseParameters,
%     resolveSessionAnchors, resolveValidIntervals (census only)
%
%   Subpackages
%     +migrators_j     - the did_v1 -> V_eta per-document migrators, one file
%                        per v1 class, routed when TargetVersion is 'V_eta'.
%                        +migrators_j/+super holds the superclass migrators.
%                        Its Contents.m carries a GENERATED roster of every
%                        migrator (tools/check_migrator_roster.py).
%     +migrators       - the per-class migrators for the 'V_delta' target,
%                        and the fallback for a class with no +migrators_j
%                        file: `identity` returns the body unchanged.
%     +entities        - shared emitters for the entity tier (entityDoc,
%                        relationDoc, orgFor, ...).
%     +readers         - pure-read entry points for the two v1 DID
%                        storage formats. sqliteV1 reads the legacy
%                        did.implementations.sqlitedb docs.json_code
%                        column; dumbJsonV1 walks a
%                        did.implementations.matlabdumbjsondb tree
%                        and returns the latest version of every
%                        Object_id_*_v#####.json file.
%
%   See also: did2.convert.v1_to_v2, did2.build.statement.
