function v2Body = oneepoch(preBody)
%ONEEPOCH Brainstorm-J migrator: carry a v1 oneepoch whole as v1. 1 -> 1.
%
%   EVERY oneepoch IS CARRIED WHOLE AS v1 (the untouched v1 source, with a
%   `carried_as_v1` note): one stitched on device-local time under carry-126,
%   one on a global clock with its output element (the element's own carry
%   row), see THE 2026-10-27 / 2026-10-29 / 2026-10-30 DECISIONS below. The
%   class is no longer kept and its inherited block is no longer folded;
%   the sections up to READS RAW v1 are the record of what that fold did.
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
%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-27; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it (oneepoch.json over element_epoch.json + epochid.json
%   + base.json at the locked NDI-matlab `main`, 3cb19a8, as ndi.element
%   addepoch writes it with EPOCHIDS: element_epoch.epoch_clock, .t0_t1 (a
%   column for one clock), epochid.epochid, oneepoch.epoch_ids, element_id),
%   with no superclass migrator run on it. So this migrator calls the one the
%   renamed path ran, did2.convert.migrators.element_epoch (the clocks
%   records, or its carry-009 / carry-038 carry), on the raw block itself, as
%   +migrators_j/element_epoch.m does, and writes its edges as {name,
%   document_id}, as the renamed path did, so the switch changes no emitted
%   document. Every v1 field is accounted for (jRawAccount on the templates);
%   one outside them carries the document whole as v1 ([fields outside the
%   template are malformed], carry-100), where the strict-fields check refused
%   it before. What universalRenames would have discarded (a depends_on
%   version, an ndi_document beside base) carries it, carry-049, as before. A
%   carry is the untouched v1 source. did2.convert.roundtrip.oneepoch rebuilds
%   the v1 document; testRawV1RoundTripOneEpoch compares the two.
%
%   THE 2026-10-27 / 2026-10-29 / 2026-10-30 DECISIONS (Jess Haley, did-schema
%   V_eta_go_forward_class_audit.md):
%     [oneepoch is a redundant calculation]  a v1 `oneepoch` placed on a
%         global clock becomes a `calculation` with `input_id` links to the
%         per-epoch recordings, `redundant: true`; one stitched on
%         device-local time is carried `needs_mapping`;
%     [oneepoch method is data combination]  that calculation's
%         `method.term` is OBI:0200125 "data combination"; its value is the
%         stitched series as a `sampled_body` with `redundant: true`; a
%         `oneepoch` NDI stitched on device-local time (NDI-matlab main
%         +element/oneepoch.m: "as though the recordings occurred one
%         immediately after the other") is carried whole as v1
%         `needs_mapping`.
%     [reshaped retire classes carried]  (Jess Haley, 2026-10-29, "B")
%         v1 `distance_metadata` and `oneepoch` are carried whole as v1 for
%         now, not reshaped into their retire classes; the reshape waits for
%         their V2 homes (`oneepoch`: docs/V2_PLAN.md G44).
%   BUILT HERE: both carries. ndi.element.oneepoch picks the first GLOBAL
%   clock of the input's epoch table (ndi.time.clocktype.isGlobal: utc,
%   approx_utc, exp_global_time, approx_exp_global_time, dev_global_time,
%   approx_dev_global_time) and stitches on dev_local_time only when there is
%   none; it writes EVERY clock of the element, comma-joined, as
%   element_epoch.epoch_clock. So a oneepoch none of whose clocks is global
%   was stitched on device-local time, and is carried whole as v1,
%   needs_mapping (isStitchedOnLocalTime), citing register row carry-126
%   (did-schema 64ad58b8). One with a global clock, which until 2026-10-29
%   kept the class `oneepoch` with its element_epoch block folded onto it, is
%   carried whole as v1 with its output element (below).
%     [global-clock oneepoch carried with its element]  (Jess Haley,
%         2026-10-30, "Q5 a") in the generic stage a global-clock
%         `oneepoch` is carried with its output element, whose own carry
%         (the element register rows, which already carry every such
%         element) it cites; the awaiting_home row it cited until then is
%         dropped as redundant. The data-combination calculation is built in
%         each dataset's import, not here.
%   BUILT HERE: this migrator hands a global-clock oneepoch back unchanged
%   with a `carried_with_element` note naming its element_id; v1_to_v2
%   carries it (stamped did_v1, never converted) and, once every source of
%   the batch is migrated, writes its `carried_as_v1` note citing the rows
%   its element's carry cites (v1_to_v2 carryOneEpochsWithElement). A
%   per-document migrator cannot see how its element was carried, which is
%   why the note is written there. One whose element is not carried in the
%   batch (absent, or converted) is still carried, and its note says so and
%   cites no row.
%
%   did2.convert.roundtrip.oneepoch, the inverse of the kept class, is reached
%   by no migrator output while every oneepoch is carried; a carry's round
%   trip is the carry itself (did2.convert.roundtrip.check).

arguments
    preBody (1,1) struct
end

src = preBody;
if ~(isfield(preBody, 'element_epoch') && isstruct(preBody.element_epoch) ...
        && isfield(preBody.element_epoch, 'clocks'))
    % THE RAW READ (see READS RAW v1 above): a body the renamed path's
    % superclass migrator has not already reshaped
    [preBody, collision, unplaced] = jRawAccount(src, struct( ...
        'oneepoch', {{'epoch_ids'}}, 'element_epoch', {{'epoch_clock', 't0_t1'}}, ...
        'epochid', {{'epochid'}}, 'files', {{'file_list', 'file_info'}}), {'^element_id$'});
    if jRawCarry('oneepoch', src, collision, unplaced, 'carry-100')
        v2Body = {src};
        return;
    end
    if isfield(preBody, 'depends_on') && ~isempty(preBody.depends_on)
        deps = did2.convert.v1read.readDependsOn(preBody);
        preBody.depends_on = struct('name', {deps.name}, 'document_id', {deps.document_id});
    end
    stamp = did2.convert.v1read.readStamp(preBody);
    preBody.document_class.superclasses = struct('class_name', stamp.superclasses);
    reshaped = did2.convert.migrators.element_epoch(preBody);
    if isequaln(reshaped, preBody)
        v2Body = {src};   % its carry (noted there): the untouched v1 source
        return;
    end
    preBody = reshaped;
end

v2Body = preBody;

% The element_epoch superclass migrator ran first; a block it did not convert
% to `clocks` is one whose t0_t1 does not match its clocks, which it noted
% `carried_as_v1` ([small unread settings] (4), Jess Haley, 2026-10-26). The
% document is carried whole as v1.
if isfield(v2Body, 'element_epoch') && isstruct(v2Body.element_epoch) ...
        && ~isfield(v2Body.element_epoch, 'clocks')
    return;
end

% [oneepoch is a redundant calculation] (Jess Haley, 2026-10-27) with
% [oneepoch method is data combination] (Jess Haley, 2026-10-29), did-schema
% V_eta_go_forward_class_audit.md: a oneepoch NDI stitched on device-local time
% (none of its clocks global) is carried whole as v1, needs_mapping. Its
% times exist in no input.
id = '';
if isfield(src, 'base') && isstruct(src.base) && isfield(src.base, 'id')
    id = char(src.base.id);
end
if isStitchedOnLocalTime(v2Body.element_epoch.clocks)
    % carry-register: carry-126
    did2.convert.reportNote('carried_as_v1', 'oneepoch', id, ...
        ['[carry-126] needs_mapping: a oneepoch stitched on ' ...
        'device-local time, its times in no input ([oneepoch method is data ' ...
        'combination])']);
    v2Body = {src};
    return;
end

% [global-clock oneepoch carried with its element] (Jess Haley, 2026-10-30,
% did-schema V_eta_go_forward_class_audit.md): a oneepoch on a global clock is
% carried whole as v1 with its output element. Handed back unchanged; v1_to_v2
% carries it and writes its carry note citing the element's carry rows once
% the element is migrated (carryOneEpochsWithElement).
did2.convert.reportNote('carried_with_element', 'oneepoch', id, elementIdOf(src));
v2Body = {src};
end

function e = elementIdOf(src)
%ELEMENTIDOF The oneepoch's element_id edge ('' when it has none).
e = '';
try
    deps = did2.convert.v1read.readDependsOn(src, 'Name', '^element_id$');
catch
    return;
end
if ~isempty(deps) && ~isempty(deps(1).document_id)
    e = char(deps(1).document_id);
end
end

function tf = isStitchedOnLocalTime(clocks)
%ISSTITCHEDONLOCALTIME True when no clock of a oneepoch is global: NDI-matlab
%   main +element/oneepoch.m stitched it on dev_local_time ("If a global
%   clock cannot be found, the epoch will be given a 'dev_local_time' with
%   the concatenation of all the local times"). The global types are
%   ndi.time.clocktype.isGlobal's list at the locked NDI-matlab `main`.
GLOBAL = {'utc', 'approx_utc', 'exp_global_time', 'approx_exp_global_time', ...
    'dev_global_time', 'approx_dev_global_time'};
if isstruct(clocks)
    clocks = num2cell(reshape(clocks, 1, []));
end
tf = true;
for k = 1:numel(clocks)
    c = clocks{k};
    if isstruct(c) && isfield(c, 'name') && any(strcmp(strtrim(char(c.name)), GLOBAL))
        tf = false;
        return;
    end
end
end
