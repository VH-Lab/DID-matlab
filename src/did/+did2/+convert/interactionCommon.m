classdef interactionCommon
%INTERACTIONCOMMON Shared helpers for subject_interaction-family migrators.
%
%   The V_epsilon subject_interaction redesign moves the legacy
%   treatment / treatment_drug / treatment_transfer / virus_injection /
%   subject_group / stimulus_bath classes into the observation /
%   manipulation / annotation families. Those migrations share a few
%   chores that this class collects as static helpers:
%
%     - carrying the legacy document identity (base.id / base.datestamp)
%       onto the primary migrated document so references survive;
%     - reading a depends_on document_id by role name from the
%       (already universally-renamed) legacy body;
%     - building the target depends_on array;
%     - minting companion time_reference documents (subject_interaction
%       requires >=1 time_reference) and wiring them in;
%     - building ontology_term / concentration / volume composites.
%
%   Timing policy. A subject_interaction requires a time_reference, but
%   the did2 validator enforces field/block shape, not depends_on
%   cardinality. So:
%     - When a timestamp is recoverable from the legacy body (an ISO
%       string, a date, a datenum), mint a utc_reference and wire it as
%       time_reference_1.
%     - When no timing is recoverable, omit the time_reference
%       dependency rather than invent a sentinel timestamp. The document
%       is valid; the missing timing is a documented curator-backfill
%       point (see the conversions/from_did_v1/*.md for each family).
%
%   Ontology backfill policy. Where the legacy body carries a name but
%   no resolvable ontology node, the helper emits {node:'', name:<name>}
%   — a valid ontology_term whose blank node flags it for curator
%   backfill, exactly the draft-tier soak strategy the family proposals
%   prescribe. Nothing legacy is dropped silently.
%
%   See also: did2.convert.v1_to_v2 (fan-out dispatch),
%   did2.convert.migrators.treatment / treatment_drug / virus_injection
%   / treatment_transfer / subject_group / stimulus_bath.

    methods (Static)
        function id = mintId()
            %MINTID Fresh DID unique id for a newly minted document.
            id = did.ido.unique_id();
        end

        function ts = nowUTC()
            %NOWUTC Current UTC timestamp in the did2 datestamp format.
            dt = datetime('now', 'TimeZone', 'UTC');
            dt.Format = 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z''';
            ts = char(string(dt));
        end

        function base = carryBase(legacyBody)
            %CARRYBASE Base block carried from the legacy body.
            %   Preserves base.id, base.session_id and base.datestamp
            %   when present so the migrated primary keeps the legacy
            %   document identity and stays in its session; mints id /
            %   datestamp otherwise. base requires id, session_id and
            %   datestamp (all non-empty), so session_id must come from
            %   the source. Strict-field validation later rejects any
            %   non-base keys, so only these are carried.
            ic = did2.convert.interactionCommon;
            base = struct('id', ic.mintId(), ...
                'session_id', '', ...
                'datestamp', ic.nowUTC());
            if isfield(legacyBody, 'base') && isstruct(legacyBody.base) ...
                    && isscalar(legacyBody.base)
                lb = legacyBody.base;
                if isfield(lb, 'id') && ~isempty(lb.id)
                    base.id = char(lb.id);
                end
                if isfield(lb, 'session_id') && ~isempty(lb.session_id)
                    base.session_id = char(lb.session_id);
                end
                if isfield(lb, 'datestamp') && ~isempty(lb.datestamp)
                    base.datestamp = char(lb.datestamp);
                end
            end
        end

        function sid = sessionIdOf(legacyBody)
            %SESSIONIDOF The source document's session_id (or '').
            %   Companion documents minted during a fan-out belong to the
            %   same session as the source, so they stamp this value.
            sid = '';
            if isfield(legacyBody, 'base') && isstruct(legacyBody.base) ...
                    && isscalar(legacyBody.base) ...
                    && isfield(legacyBody.base, 'session_id') ...
                    && ~isempty(legacyBody.base.session_id)
                sid = char(legacyBody.base.session_id);
            end
        end

        function base = newBase(sessionId)
            %NEWBASE Fresh base block for a minted companion document.
            ic = did2.convert.interactionCommon;
            base = struct('id', ic.mintId(), ...
                'session_id', charOrEmpty(sessionId), ...
                'datestamp', ic.nowUTC());
        end

        function docId = depDocId(legacyBody, name)
            %DEPDOCID document_id of a depends_on entry by role name.
            %   Returns '' when the role is absent. The legacy body has
            %   already passed universalRenames, so entries carry
            %   {name, document_id}.
            docId = '';
            if ~isfield(legacyBody, 'depends_on') ...
                    || ~isstruct(legacyBody.depends_on) ...
                    || isempty(legacyBody.depends_on)
                return;
            end
            dep = legacyBody.depends_on;
            for k = 1:numel(dep)
                if isfield(dep(k), 'name') && strcmp(char(dep(k).name), name)
                    if isfield(dep(k), 'document_id')
                        docId = char(dep(k).document_id);
                    end
                    return;
                end
            end
        end

        function dep = dependsOn(pairs)
            %DEPENDSON Build a depends_on struct array from name/id pairs.
            %   PAIRS is an N-by-2 cell array {name, document_id}; rows
            %   whose document_id is empty are dropped (an absent role is
            %   simply not asserted). Returns the canonical
            %   {name, document_id} struct array (0x0 when none remain).
            dep = struct('name', {}, 'document_id', {});
            for k = 1:size(pairs, 1)
                docId = pairs{k, 2};
                if isempty(docId)
                    continue;
                end
                dep(end+1) = struct('name', pairs{k, 1}, ...
                    'document_id', char(docId)); %#ok<AGROW>
            end
        end

        function term = ontologyTerm(node, name)
            %ONTOLOGYTERM {node, name} composite (blank node => backfill).
            term = struct('node', charOrEmpty(node), 'name', charOrEmpty(name));
        end

        function arr = ontologyTermArray(terms)
            %ONTOLOGYTERMARRAY Array-of-ontology_term from a cell of {node,name}.
            %   TERMS is a cell array of 1x2 {node,name} cells. Returns a
            %   struct array (0x0 when empty) suitable for an
            %   array-of-ontology_term field (target_structure).
            arr = struct('node', {}, 'name', {});
            for k = 1:numel(terms)
                arr(end+1) = did2.convert.interactionCommon.ontologyTerm( ...
                    terms{k}{1}, terms{k}{2}); %#ok<AGROW>
            end
        end

        function c = concentration(sourceUnit, sourceValue)
            %CONCENTRATION concentration composite from a source unit/value.
            %   Always preserves source_unit / source_value, and
            %   populates one canonical sub-field (molar, grams_per_liter,
            %   mass_fraction or volume_fraction) when the source unit is
            %   recognised. Unknown units stay source-only (no canonical),
            %   so consumers can backfill once conventions firm up.
            unit = charOrEmpty(sourceUnit);
            value = toScalarNumber(sourceValue);
            c = struct('approximate', false, ...
                'source_unit', unit, ...
                'source_value', value);
            if isnan(value)
                return;
            end
            molarScale = molarScaleFor(unit);
            if ~isnan(molarScale)
                c.molar = value * molarScale;
                return;
            end
            gplScale = gramsPerLiterScaleFor(unit);
            if ~isnan(gplScale)
                c.grams_per_liter = value * gplScale;
                return;
            end
            if isMassFractionUnit(unit)
                c.mass_fraction = value;
                return;
            end
            if isVolumeFractionUnit(unit)
                c.volume_fraction = value;
            end
        end

        function v = volume(sourceUnit, sourceValue)
            %VOLUME Minimal volume composite (source-only).
            v = struct('approximate', false, ...
                'source_unit', charOrEmpty(sourceUnit), ...
                'source_value', toScalarNumber(sourceValue));
        end

        function [trBody, trId] = utcReferenceBody(startISO, sessionId, endISO, approximate)
            %UTCREFERENCEBODY Mint a utc_reference document body.
            %   Returns the body and its minted id. START is required
            %   non-empty by the schema; callers must only mint a
            %   utc_reference when they have a real start timestamp.
            %   SESSIONID stamps base.session_id (same session as the
            %   source interaction).
            arguments
                startISO (1,:) char
                sessionId (1,:) char = ''
                endISO (1,:) char = ''
                approximate (1,1) logical = false
            end
            ic = did2.convert.interactionCommon;
            trBody = struct();
            trBody.document_class = struct('class_name', 'utc_reference');
            trBody.base = ic.newBase(sessionId);
            trId = trBody.base.id;
            trBody.time_reference = struct('is_approximate', approximate);
            ref = struct('start', startISO);
            if ~isempty(endISO)
                ref.end = endISO;
            end
            trBody.utc_reference = ref;
        end

        function mix = mixtureFromTable(rawTable)
            %MIXTUREFROMTABLE Parse a legacy CSV mixture_table to records.
            %   The did_v1 mixture_table is
            %       "ontologyName,name,value,ontologyUnit,unitName\n
            %        <chem_curie>,<name>,<value>,<unit_curie>,<unit_name>..."
            %   Returns an array of {chemical:ontology_term,
            %   amount:concentration} records (0x0 when empty). Shared by
            %   the injection (treatment_drug) and bath (stimulus_bath)
            %   migrations, whose pharmacological_manipulation.mixture
            %   field has the identical shape.
            mix = struct('chemical', {}, 'amount', {});
            if isempty(rawTable)
                return;
            end
            if isstring(rawTable) && isscalar(rawTable)
                rawTable = char(rawTable);
            end
            if ~ischar(rawTable)
                return;
            end
            lines = strsplit(rawTable, newline);
            lines = lines(~cellfun('isempty', lines));
            if isempty(lines)
                return;
            end
            startIdx = 1;
            firstCells = strsplit(lines{1}, ',');
            if ~isempty(firstCells) ...
                    && strcmpi(strtrim(firstCells{1}), 'ontologyName')
                startIdx = 2;
            end
            ic = did2.convert.interactionCommon;
            for k = startIdx:numel(lines)
                cells = strsplit(lines{k}, ',');
                cells = cellfun(@strtrim, cells, 'UniformOutput', false);
                if numel(cells) < 5
                    continue;
                end
                mix(end+1) = struct( ...
                    'chemical', ic.ontologyTerm(cells{1}, cells{2}), ...
                    'amount',   ic.concentration(cells{5}, cells{3})); %#ok<AGROW>
            end
        end
    end
end

function s = charOrEmpty(v)
if isempty(v)
    s = '';
elseif ischar(v)
    s = v;
elseif isstring(v) && isscalar(v)
    s = char(v);
else
    s = '';
end
end

function x = toScalarNumber(v)
if isempty(v)
    x = 0;
    return;
end
if ischar(v) || (isstring(v) && isscalar(v))
    x = str2double(v);
    if isnan(x); x = 0; end
    return;
end
if isnumeric(v) && isscalar(v)
    x = v;
else
    x = 0;
end
end

function s = molarScaleFor(u)
% Scalar that converts a source unit to mol/L. Unknown -> NaN.
u = lower(char(u));
switch u
    case {'molar', 'm', 'mol/l', 'mol l-1'}
        s = 1;
    case {'millimolar', 'mm', 'mmol/l'}
        s = 1e-3;
    case {'micromolar', 'um', 'mumolar', 'umol/l'}
        s = 1e-6;
    case {'nanomolar', 'nm', 'nmol/l'}
        s = 1e-9;
    case {'picomolar', 'pm', 'pmol/l'}
        s = 1e-12;
    otherwise
        s = NaN;
end
end

function s = gramsPerLiterScaleFor(u)
u = lower(char(u));
switch u
    case {'g/l', 'g l-1', 'grams per liter', 'grams per litre', 'mg/ml', 'mg ml-1'}
        s = 1;
    case {'mg/l', 'mg l-1'}
        s = 1e-3;
    case {'ug/ml', 'ug ml-1', 'mug/ml'}
        s = 1e-3;
    case {'ug/l', 'ug l-1'}
        s = 1e-6;
    otherwise
        s = NaN;
end
end

function tf = isMassFractionUnit(u)
tf = any(strcmpi(char(u), {'w/w', '%w/w', '%(w/w)'}));
end

function tf = isVolumeFractionUnit(u)
tf = any(strcmpi(char(u), {'v/v', '%v/v', '%(v/v)'}));
end
