% +convert  did_v1 -> V_eta document conversion utilities.
%
%   The +convert subpackage migrates did_v1 document bodies to the V_eta
%   schema (did-schema schemas/V_eta). It holds the dispatcher, the
%   per-document migrators, the batch post-passes that need a whole corpus,
%   and the legacy-database readers.
%
%   THE TARGET. V_eta is the only migration target of v1_to_v2 (and its
%   TargetVersion default); it routes through +migrators_j. The 'V_epsilon'
%   and 'V_zeta' targets and their +migrators_e / +migrators_i packages were
%   deleted with did-schema's older schema sets (OPEN_WORK #128,
%   2026-10-21). See v1_to_v2's own help.
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
%                          any migrator of a class NOT yet switched to raw
%                          v1 (deleted once the last class has switched,
%                          [migrators read raw v1]).
%     rawV1Classes       - the classes whose migrator reads the RAW v1
%                          document (no universalRenames, no superclass
%                          migrators); one family at a time.
%     +v1read            - shared raw-v1 reading helpers: readDependsOn,
%                          readBase, readApp, readStamp. They read v1 as the
%                          NDI templates define it and drop nothing.
%     +roundtrip         - the round trip of a switched class
%                          ([migration reliability practices] (a)): check
%                          rebuilds the v1 document from the emitted V2
%                          documents with the class's inverse and compares.
%     ensureClassBlocks  - give a body exactly the class blocks its schema
%                          chain hosts.
%     isAlreadyTarget    - true when a body is already stamped did_v2 (a
%                          stamp check), so a re-run skips it.
%     schemaVersionRank  - where a schema version sits in the did_v1 ->
%                          V_eta line.
%     statementKind      - the direction class and value kind of a statement.
%     mintId             - the id of a document the migration mints, derived
%                          from its source id and role (deterministic).
%     fromV1Database     - end-to-end orchestrator: reads a v1 database
%                          (file -> sqliteV1, directory -> dumbJsonV1),
%                          runs v1_to_v2 with its default TargetVersion,
%                          writes the successes into a fresh
%                          did2.database.sqlitedb and the quarantine to
%                          <dst>.quarantine.json.
%
%   Shared helpers used by migrators
%     calcCommon, channelType, epochIndex, ethicsJurisdiction,
%     registeredTerm, reportNote, mintSessionDuring,
%     stimulusPresentationSpecs (the batch's presentation settings, loaded
%     by v1_to_v2)
%
%   Batch post-passes (run over a migrated batch, after v1_to_v2; each
%   carries a BATCH-PASS declaration read by tools/batch_pass_declarations.py)
%     epochMint, foldGenericFiles, resolveClockAlignment, resolveDatasetEntities,
%     resolveDeferredBaths, resolveEpochProbemap, resolveOpenmindsCitations,
%     resolveResponseParameters, resolveSessionAnchors, resolveValidIntervals
%     (census only)
%
%   Subpackages
%     +migrators_j     - the did_v1 -> V_eta per-document migrators, one file
%                        per v1 class.
%                        +migrators_j/+super holds the superclass migrators.
%                        Its Contents.m carries a GENERATED roster of every
%                        migrator (tools/check_migrator_roster.py).
%     +migrators       - the fallback for a class with no +migrators_j file
%                        (`identity` returns the body unchanged), and the
%                        helpers some +migrators_j files delegate to.
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
