function bodies = spike_extraction_parameters_modification(preBody)
%SPIKE_EXTRACTION_PARAMETERS_MODIFICATION Brainstorm-J migrator: did_v1
%   spike_extraction_parameters_modification -> a SECOND `method_parameters`
%   document (+ the `software` entity its v1 `app` block names).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   NOT AN OVERLAY -- A SECOND PARAMETER SET. v1 stores the FULL fifteen-field
%   payload again, not a diff:
%
%     git show origin/main:src/ndi/ndi_common/database_documents/apps/\
%         spikeextractor/spike_extraction_parameters_modification.json
%        "spike_extraction_parameters_modification": {
%           center_range_time ... threshold_sign }     <- the identical 15 fields
%        "depends_on": [ extraction_parameters_id, element_id ]
%
%   so it folds exactly like its base class and simply carries two more edges.
%
%   THE THREE EDGES, and the one the TEMPLATE DOES NOT DECLARE:
%
%     extraction_parameters_id -> derived_from_id.  LINEAGE ONLY. It records
%        which named protocol this variant came from; it does NOT carry
%        precedence. Precedence comes from the SCOPE (subject_id + epoch_id) --
%        the app prefers a scoped variant over an unscoped protocol. That is why
%        the edge is not called `overrides_id`.
%
%     element_id -> subject_id.  D2: element.m promotes an element to a
%        `subject` with its id PRESERVED, so this resolves.
%
%     epoch scope.  THE WRITER WINS OVER THE TEMPLATE HERE, and this is the
%        third instance this family of a writer setting what no template
%        declares:
%
%          git show origin/main:src/ndi/+ndi/+app/spikeextractor.m | sed -n '309,313p'
%             doc = ndi.document('spike_extraction_parameters_modification',...
%                 'spike_extraction_parameters_modification',appdoc_struct,'epochid.epochid',epoch_string) + ...
%                 ndi_app_spikeextractor_obj.newdocument() + ndi.document('base','base.name',extraction_name);
%             doc = doc.set_dependency_value('extraction_parameters_id',extraction_doc.id());
%             doc = doc.set_dependency_value('element_id',ndi_timeseries_obj.id());
%
%          git show origin/main:src/ndi/ndi_common/database_documents/apps/\
%              spikeextractor/spike_extraction_parameters_modification.json
%             "superclasses": [ base, app ]          <- NO epochid superclass
%
%        The class is epoch-scoped IN PRACTICE, and a live three-way lookup
%        depends on it:
%
%          git show origin/main:src/ndi/+ndi/+app/spikeextractor.m | sed -n '388,391p'
%             ndi.query('epochid.epochid','exact_string',epoch_string,'') & ...
%             ndi.query('','depends_on','element_id',ndi_timeseries_obj.id()) & ...
%             ndi.query('','depends_on','extraction_parameters_id',extraction_parameters_doc{1}.id());
%
%        `epoch_id -> epoch` cannot be filled in pass 1 (jEpochDocId answers ''
%        by construction until the epoch pass mints the documents, #60), so
%        jMethodParameters parks the epoch STRING in `other.epochid` instead of
%        dropping it. Losing it would break that three-way lookup for good.
%
%   Field disposition is identical to spike_extraction_parameters; see that
%   migrator's header and jSpikeExtractionSettings.

arguments
    preBody (1,1) struct
end

blk = struct();
if isfield(preBody, 'spike_extraction_parameters_modification') ...
        && isstruct(preBody.spike_extraction_parameters_modification)
    blk = preBody.spike_extraction_parameters_modification;
end

[entries, other] = jSpikeExtractionSettings(blk);
bodies = jMethodParameters(preBody, entries, other, ...
    'DerivedFromSrc', 'extraction_parameters_id');
end
