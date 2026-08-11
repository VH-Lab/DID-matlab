function v2Body = element_epoch(preBody)
%ELEMENT_EPOCH Brainstorm-J migrator: element_epoch -> acquisition_epoch.
%
%   INTERIM. The signed model (#60) DISSOLVES this class; the dissolution is
%   blocked, so the rename below is what still ships. Read the two blocks after
%   the mechanics before changing anything here.
%
%   MECHANICS (unchanged). `element` is retired in V_eta (subjects replaced
%   elements), so the class and its property block are renamed to
%   `acquisition_epoch`. The clock-block transform (v1 epoch_clock/t0_t1 -> the
%   clocks array-of-records) is identical to the base migrator, so this reuses it
%   and then renames. The acquisition_epoch superclass chain (base + epochid) and
%   the empty axes/channels/storage blocks are rebuilt by ensureClassBlocks
%   against the V_eta schema.
%
%   ---------------------------------------------------------------------------
%   CORRECTION -- THIS CLASS IS NOT "THE EPOCH", AND THIS HEADER SAID IT WAS
%   ---------------------------------------------------------------------------
%   The paragraph above used to end *"it is an epoch of a data ACQUISITION"*.
%   That is false, and it is the exact error V_eta_epoch_plan.md's same-day
%   revision exists to correct: `element_epoch` is ONE ELEMENT'S SLICE of an
%   epoch, not the epoch. From the writer, +ndi/element.m:367-378:
%
%       epochdoc = E.newdocument('element_epoch', ...
%           'element_epoch.epoch_clock', epochclockstr, ...
%           'element_epoch.t0_t1', t0_t1_input, ...
%           'epochid.epochid', epochid);
%       epochdoc = epochdoc.set_dependency_value('element_id', elementdoc.id());
%
%   One document per ELEMENT per EPOCH -- its own clock, its own extent, its own
%   `.vhsb` payload -- and MANY share one `epochid.epochid`. Measured on corpus
%   B: 1,239 element_epoch documents over 149 distinct epoch-id strings (12,917
%   documents read, 0 unreadable). The name `acquisition_epoch` reads as "the
%   epoch itself" and that reading, propagated from this header, is what produced
%   a decision about the wrong object.
%
%   The real epoch is a NEW entity, `epoch`, MINTED one per (session, epoch id) --
%   a whole-corpus grouping, so the NDI second pass, not here. Nothing in this
%   migrator may be read as already representing it.
%
%   ---------------------------------------------------------------------------
%   WHY THE DISSOLUTION IS NOT BUILT (#60 migrator half, deferred)
%   ---------------------------------------------------------------------------
%   Under the signed model this class dissolves into pieces that do not exist yet:
%
%       t0_t1 / epoch_clock     -> relative_reference documents  (time model)
%       epoch_binary_data.vhsb  -> sampled_body                  (2.D data_body,
%                                                                 #45, UNSIGNED)
%       element_id              -> the observation's subject/instrument per T7
%                                  (raw-recording model, #30, UNSIGNED)
%       + an epoch_id edge      -> the minted `epoch`            (second pass)
%
%   Three of those four targets are unsigned or unbuilt, so dissolving now would
%   strand the payload rather than move it. `acquisition_epoch` therefore SURVIVES
%   as the carrier and this migrator keeps renaming into it. Two consequences the
%   next person should not re-derive:
%
%     * `ensemble.element_epoch_id` points at THIS document (the payload-bearing
%       per-element record), NOT at the new `epoch` entity -- confirmed as the
%       only holder of that edge (+ndi/+element/ensemble.m:273 writes it,
%       +ndi/+fun/+ensemble/allElement.m:98 reads it, and its cleanup calls the
%       referent "the element_epoch doc and its binary"). When this dissolves the
%       edge retargets to whatever absorbs the payload.
%     * `oneepoch` inherits its whole shape from `element_epoch` and is handled by
%       its own migrator as a fold-into-tombstone; fork A1 for it is chosen but
%       NOT SIGNED, and is gated on #30 besides.
%
%   ALSO STILL TRUE, and repairs rather than decisions:
%   `acquisition_epoch.axes` / `.channels` / `.storage` appear in NO NDI template
%   -- `element_epoch` declares `{epoch_clock, t0_t1}` and a `.vhsb` file and
%   nothing else -- and `acquisition_epoch` declares `files: []` while the real
%   documents carry the payload (corpus B: every element_epoch body has
%   `files.file_list = {'epoch_binary_data.vhsb'}` with an ndicloud location).
%
%   THE FILE HALF IS NOW FIXED -- corrected 2026-08-11. `acquisition_epoch`
%   declares `epoch_binary_data.vhsb`, landed in `3a542b8` ("#60 epoch family:
%   the two pieces that were not blocked"):
%
%       $ python3 -c "...load('schemas/V_eta/stable/acquisition_epoch.json')"
%         file: [{'name': 'epoch_binary_data.vhsb', ...}]
%
%   Only the `axes` / `channels` / `storage` half still rides with #45/#30.
%   The heading "ALSO STILL TRUE" is what let this survive: it asserts currency
%   for the whole block, so a repair to one clause leaves the other clause
%   vouching for it. Same shape as resolveSessionAnchors' header claiming it was
%   unwired after it was wired -- the harmless direction, which is exactly why
%   nobody catches it.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.

arguments
    preBody (1,1) struct
end

% Reuse the base clocks-block transform (parses epoch_clock / t0_t1).
v2Body = did2.convert.migrators.element_epoch(preBody);

% Rename the class and its property block: element_epoch -> acquisition_epoch.
v2Body.document_class.class_name = 'acquisition_epoch';
if isfield(v2Body, 'element_epoch')
    v2Body.acquisition_epoch = v2Body.element_epoch;
    v2Body = rmfield(v2Body, 'element_epoch');
end
end
