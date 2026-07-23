function v2Body = element_epoch(preBody)
%ELEMENT_EPOCH Brainstorm-J migrator: element_epoch -> acquisition_epoch.
%
%   `element` is retired in V_eta (subjects replaced elements), so the epoch
%   document's name is stale: it is an epoch of a data ACQUISITION. The class and
%   its property block are renamed to `acquisition_epoch`. The clock-block
%   transform (v1 epoch_clock/t0_t1 -> the clocks array-of-records) is identical to
%   the base migrator, so this reuses it and then renames. The acquisition_epoch
%   superclass chain (base + epochid) and the empty axes/channels/storage blocks are
%   rebuilt by ensureClassBlocks against the V_eta schema.
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
