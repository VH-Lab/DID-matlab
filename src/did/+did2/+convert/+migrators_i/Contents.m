% +migrators_i  did_v1 -> V_zeta (Brainstorm I) split/fold migrators.
%
%   Routed by did2.convert.v1_to_v2 ONLY when TargetVersion == 'V_zeta'.
%   The dispatcher applies the universal renames first, then -- for a class
%   that has a file here -- runs this migrator instead of the default
%   +migrators/<class> one. A migrator may return a single body OR a cell /
%   struct array of several bodies, so one source document can fan out to N
%   destination documents (1 -> N).
%
%   Brainstorm I (did-schema/schemas/V_zeta) carries identity OFF the class:
%   every timed record is a `subject_interaction` whose spine block holds
%   `method` (verb, optional), `variable` (the queryable "what"), and
%   `target_structure` (locus). Family blocks carry only typed DATA; `notes`
%   prose lives on the `manipulation` base. Observation leaves are named by
%   DATA-TYPE (scalar_mass_observation, ...), not by property, with a single
%   concrete categorical_observation. The pure-identity procedural_ /
%   environmental_manipulation classes do not exist -- they fold into
%   generic_manipulation, the act named by `variable`.
%
%   Registered migrators (see the matching conversion specs under
%   did-schema/schemas/V_zeta/conversions/from_did_v1/):
%
%     treatment          - 1 -> 2. Dispatch by the structure the data needs:
%                          injection / bath (substance), temperature_manipulation
%                          (typed value), generic_manipulation (a payload-free
%                          procedure OR environmental regime). Not-a-manipulation
%                          rows (date of birth, ...) quarantine with a reason.
%                          Plus the shared session_relative_reference anchor.
%     ontology_table_row - 1 -> N. Each column -> its own observation, class
%                          chosen by the value's DIMENSION (scalar_<dim>_observation
%                          / categorical_observation / generic_scalar_observation),
%                          property on the spine `variable`. Plus one shared anchor.
%     treatment_drug     - 1 -> 2. -> injection (kind: drug); mixture from the
%                          legacy mixture_table; primary drug -> spine `variable`.
%     virus_injection    - 1 -> 2. -> injection (kind: virus); virus -> mixture +
%                          spine `variable`; dilution -> concentration.
%     treatment_transfer - 1 -> 2. -> biological_transfer; material -> spine
%                          `variable`; recipient -> subject_id; donor -> donor_id.
%     subject_group      - 1 -> 1. -> subject flagged is_group (membership
%                          becomes group_assignment events in the NDI layer).
%     stimulus_bath      - DEFERS (errors): the bath's subject + epoch anchor
%                          need the stimulator element graph; assembled in
%                          ndi.migrate.local (NDI-matlab), not per-document.
%     image_stack        - 1 -> 6. Retires the standalone image doc onto NDI's
%                          imaging stack: imageseries_observation (discoverable
%                          handle) + daqreader_image_epochdata_ingested (the
%                          DIGITAL ingested frames.bin + YXCZT header) +
%                          ndi.element.image + element_epoch + daqreader + the
%                          shared anchor. Drops the legacy document_id orphan.
%
%   Any non-'V_delta' target stamps document_class.schema_version with the
%   target name ('V_zeta' here).
%
%   Running a corpus through the V_zeta conversion (transform + validation):
%
%       setenv('DID_SCHEMA_PATH', ...
%           fullfile(did.toolboxdir(), '..','..','..', ...
%                    'did-schema','schemas','V_zeta','stable'));
%       did2.schema.cache.resetSingleton();
%       result = did2.convert.v1_to_v2(bodies, 'TargetVersion', 'V_zeta', ...
%                                      'Validate', true, 'Verbose', true);
%       % result.migrated / result.quarantine / result.summary.by_class
%
%   The transform-level tests (Validate=false, no schema path needed) live in
%   tests/+did2/+unittest/testMigratorsI.m.
%
%   See also: did2.convert.v1_to_v2, did2.convert.migrators,
%   did2.convert.migrators_e.
