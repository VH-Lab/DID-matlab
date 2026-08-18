function leaf = jQuantityLeaf(hay, wordBoundary)
%JQUANTITYLEAF Resolve a measurement label to a V_eta quantity leaf stem.
%   LEAF = jQuantityLeaf(HAY) returns one of 'mass' | 'temperature' | 'length' |
%   'time', or '' when the label names no quantity this migration can type
%   honestly. HAY is a lowercased haystack built from whatever the source class
%   offers as the name of the thing measured (an ontology CURIE plus its label
%   for `measurement`; the free-text `measurement` string for
%   `subjectmeasurement`).
%
%   THE KEYWORD TABLE IS `measurement.m`'s, MOVED HERE UNCHANGED so the two
%   sibling classes share ONE implementation rather than drifting apart. V_eta's
%   observation leaves are quantity-typed (T3: leaf = direction x data_type), so
%   a number whose dimension is unknown has no honest leaf and the caller must
%   pass the document through. Inventing one is the class of error the
%   ground-truth repair track exists to undo.
%
%   ---------------------------------------------------------------------
%   WHY THIS IS NOT THE D9 REGISTRY LOOKUP THE SIGN-OFF ASKS FOR
%   ---------------------------------------------------------------------
%   The `subjectmeasurement` sign-off (V_eta_go_forward_class_audit.md) is
%   explicit that the typed leaf "must be chosen through the D9 registry rather
%   than from the template". THE REGISTRY CANNOT ANSWER THAT QUESTION TODAY.
%   `schemas/V_eta/stable/binding_registry_meta.json` ships FIVE
%   `subject_statement_bindings` rows -- species, instrument type, cell type,
%   material type, developmental stage -- and every one of them binds to
%   `term_assertion`. NOT ONE names a dimensional leaf. The only dimensional row
%   in the file ("body mass" -> mass_observation) sits under `binding_examples`,
%   which is illustrative, not a registry.
%
%   So a strict registry lookup resolves NOTHING for `age`, `weight` or
%   `temperature`, and this fold would be a no-op on the only real documents we
%   have seen. This keyword table is the pass-1 stand-in, kept deliberately
%   narrow: four dimensions, and everything else passes through visibly in
%   `summary.unconverted_by_class`. When the registry gains dimensional rows,
%   THIS FUNCTION is the single place that has to change.
%
%   ---------------------------------------------------------------------
%   THE SUBSTRING HAZARD, AND WHY THE DEFAULT KEEPS IT
%   ---------------------------------------------------------------------
%   The table matches with `contains`, so 'age' matches INSIDE 'voltage',
%   'average', 'percentage' and 'image'; 'length' matches inside 'wavelength'.
%   On `measurement` the haystack is a resolved CURIE plus its ontology label,
%   which makes a collision less likely but not impossible -- and changing that
%   class's behaviour is not this change's business, so the DEFAULT IS THE
%   EXISTING SUBSTRING BEHAVIOUR, bit-for-bit.
%
%   `subjectmeasurement` passes WORDBOUNDARY = true, because its `measurement`
%   field is FREE TEXT with no ontology term behind it (see the class tombstone:
%   "FREE TEXT -- unbound, with no ontology term, unlike measurement.ontology_name
%   which is always a resolved CURIE"). Typing a free-text 'voltage' as a
%   TIME because it contains the letters 'age' is guessing a leaf, which the
%   guard-and-pass-through rule forbids. Word-boundary matching only ever
%   NARROWS: it can turn a typed leaf into a passthrough, never the reverse.
%
%   hay           lowercased haystack (label, or CURIE + label).
%   wordBoundary  true to require whole-word matches (default false).
%
%   Shared helper for the Brainstorm-J (+migrators_j) split migrators.

if nargin < 2 || isempty(wordBoundary)
    wordBoundary = false;
end

% COLUMN 1 IS THE V_eta LEAF STEM, COLUMN 2 IS did_v1 SOURCE TEXT, and the two
% moved independently: `time` replaced `duration` as the shape mixin's name
% under TEAM-SIGN-OFF [time dtype] (DID-schema V_eta_tenet_audit.md,
% 2026-08-17), while the words a source label is matched against are unchanged
% -- a column still says "age" or "duration". Renaming the needles to match the
% stem would silently stop matching real data.
table = { ...
    'mass',        {'weight', 'mass'}; ...
    'temperature', {'temperature'}; ...
    'length',      {'length', 'height', 'width', 'diameter'}; ...
    'time',        {'age', 'duration', 'elapsed'}};

leaf = '';
hay = lower(char(hay));
if isempty(hay)
    return;
end
for k = 1:size(table, 1)
    if matchesAny(hay, table{k, 2}, wordBoundary)
        leaf = table{k, 1};
        return;
    end
end
end

function tf = matchesAny(hay, needles, wordBoundary)
tf = false;
for k = 1:numel(needles)
    if wordBoundary
        % \< \> are MATLAB regexp word-boundary anchors. The needles are plain
        % lowercase letters, so no escaping is required.
        hit = ~isempty(regexp(hay, ['\<' needles{k} '\>'], 'once'));
    else
        hit = contains(hay, needles{k});
    end
    if hit
        tf = true;
        return;
    end
end
end
