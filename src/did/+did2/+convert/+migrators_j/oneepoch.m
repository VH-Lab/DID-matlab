function v2Body = oneepoch(preBody)
%ONEEPOCH Brainstorm-J migrator: keep the class, fold its inherited block.
%
%   `oneepoch` is NOT an epoch class. It is the record of a CONCATENATION:
%   `ndi.element.oneepoch` glues an element's N epochs into a single epoch, and
%   the document's one own field, `oneepoch.epoch_ids`, is the comma-joined list
%   of the sources that went in. Everything else it carries -- `element_id`,
%   `epoch_clock`, `t0_t1` and the `epoch_binary_data.vhsb` payload -- arrives by
%   INHERITANCE, because `element_epoch` is its only declared superclass
%   (ndi_common/database_documents/oneepoch.json).
%
%   THIS IS A PASSTHROUGH REPAIR, NOT THE MODEL. The team chose fork A1 for
%   `oneepoch` on 2026-08-10 (the concatenation becomes a typed observation whose
%   `derived_from_#` edges point at the N per-epoch observations, and NO `epoch`
%   entity is minted for the synthetic `whole_session_<ref>` id). That build is
%   gated on the raw-recording model being signed, so nothing here decides it.
%   All this does is stop the document being destroyed in the meantime.
%
%   WHY IT IS NEEDED AT ALL. V_eta renames `element_epoch` to
%   `acquisition_epoch`, so no V_eta class named `element_epoch` exists -- while
%   a migrated `oneepoch` body still carries an `element_epoch` property block.
%   The validator's top-level check is strict (`did2:validation:undeclaredBlock`:
%   every top-level key must be a contributing chain block), so that block has to
%   be folded into a block the V_eta chain does host. This migrator moves it onto
%   `oneepoch` and drops the empty shell.
%
%   THE SHAPE WAS MEASURED, NOT DERIVED (scratch probe 8, run 31423494433). The
%   pipeline's actual output for a v1 `oneepoch` body:
%
%       class_name       oneepoch                (no rename -- nothing renames it)
%       top-level keys   document_class, depends_on, base, epochid,
%                        element_epoch, oneepoch
%       chain            element_epoch, base, epochid   (unrebuilt: ensureClassBlocks
%                                                        no-ops on an unknown class)
%       element_epoch    { clocks }              <- ALREADY NORMALISED, see below
%       oneepoch         { epoch_ids }
%       with Validate=true:  quarantine, "No schema file for class "oneepoch""
%
%   Two things there are worth keeping. First, the block does NOT arrive holding
%   `epoch_clock`/`t0_t1`: the BASE superclass migrator
%   (did2.convert.migrators.element_epoch) runs first, via applySuperclassMigrators,
%   and has already collapsed them into the array-of-records `clocks`. So `clocks`
%   is what the tombstone must declare -- declaring the did_v1 names would reject
%   every real document. Second, the failure today is `missingClass`, not
%   `undeclaredBlock`: `oneepoch` has no V_eta schema at all, so validation stops
%   before it ever reaches the block checks. Giving it a schema is what exposes the
%   block problem this migrator solves.
%
%   The multi-clock case is REAL here and is already handled upstream:
%   `oneepoch.m:124` writes `strjoin(ecs, ',')` -- every clock the element had,
%   comma-joined -- where a plain `element_epoch` carries one. The base migrator
%   documents that 2-by-N convention and parses it, so this migrator must not
%   re-parse or reshape anything; it only moves the result.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.

arguments
    preBody (1,1) struct
end

v2Body = preBody;

% The concrete class is unchanged -- `oneepoch` persists as a source tombstone
% until fork A1's observation model is signed and built.
v2Body.document_class.class_name = 'oneepoch';

if ~isfield(v2Body, 'oneepoch') || ~isstruct(v2Body.oneepoch)
    v2Body.oneepoch = struct();
end

% Fold the inherited block onto the concrete one. Field-by-field rather than
% wholesale, so a v1 field this migrator has never seen lands somewhere the
% strict-fields check will REPORT it (`undeclaredField` on `oneepoch`) instead of
% being carried in a block nothing validates.
if isfield(v2Body, 'element_epoch')
    inherited = v2Body.element_epoch;
    if isstruct(inherited)
        fns = fieldnames(inherited);
        for k = 1:numel(fns)
            v2Body.oneepoch.(fns{k}) = inherited.(fns{k});
        end
    end
    v2Body = rmfield(v2Body, 'element_epoch');
end
end
