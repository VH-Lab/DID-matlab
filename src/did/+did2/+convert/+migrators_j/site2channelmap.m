function bodies = site2channelmap(preBody)
%SITE2CHANNELMAP Brainstorm-J migrator: did_v1 site2channelmap -- DEFERRED to the
%   NDI second pass; the document is passed through UNCHANGED.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   ---------------------------------------------------------------------
%   WHY THIS IS NOT A MIGRATION
%   ---------------------------------------------------------------------
%   This migrator used to emit an inline count_observation of `num_sites` about
%   the probe-subject. `num_sites` DOES NOT EXIST. The real NDI class
%   (ndi_common/database_documents/probe/site2channelmap.json) has exactly one
%   property field:
%
%       site2channelmap: { map }        <- a column of channel indices
%       depends_on:      probe_id, probe_geometry_id
%
%   `map` was never read. Because `num_sites` never matched, the `numSites <= 0`
%   guard always fired and every document was already carried through unconverted
%   -- the right OUTCOME reached by accident, and indistinguishable from a
%   deliberate deferral, which is why the wrong model went unnoticed.
%
%   `map` is not migratable from this document alone, and not because of its
%   shape. Its i-th element is the channel wired to SITE i OF THE REFERENCED
%   probe_geometry, so the numbers mean nothing without that document's site
%   ordering. Re-expressing the wiring needs the join, which is the second pass's
%   to make. (numel(map) would incidentally give the site count the old
%   observation wanted, but a count of sites is a fact about the probe's geometry,
%   not about this wiring document -- probe_geometry is where it belongs, and
%   migrators_j.probe_geometry now carries the per-site arrays it comes from.)
%
%   The probe-subject itself is fine: probe_id resolves, because
%   migrators_j.element promotes probes to subjects WITH THEIR IDS PRESERVED
%   (device-as-subject, D2).
%
%   V_eta's tombstone declares the real shape so the passthrough validates -- see
%   build_v_eta.py.
%
%   THE GUARD. A body carrying `num_sites` or `site_to_channel` is REJECTED BY
%   NAME: those are DID-side inventions from the V_alpha snapshot, so their
%   presence means a fixture or a caller has been built against our schema
%   instead of the real document.
%
%   See V_eta_migrator_vocabulary_audit.md for the evidence.

arguments
    preBody (1,1) struct
end
blk = getBlock(preBody, 'site2channelmap');
if isfield(blk, 'num_sites') || isfield(blk, 'site_to_channel')
    error('did2:convert:site2ChannelMapInventedShape', ...
        ['site2channelmap body carries `num_sites`/`site_to_channel`, which no ' ...
         'did_v1 document has -- the class has exactly one property field, ' ...
         '`map`, whose meaning is defined by the probe_geometry it references. ' ...
         'This shape can only come from the V_alpha snapshot or a fixture built ' ...
         'against it.']);
end
bodies = {preBody};
end

% ===================== small helpers =======================================

function b = getBlock(bodyStruct, name)
b = struct();
if isfield(bodyStruct, name) && isstruct(bodyStruct.(name)); b = bodyStruct.(name); end
end
