function [v1, spec] = virus_injection(bodies)
%VIRUS_INJECTION Rebuild a v1 `virus_injection` from what
%   did2.convert.migrators_j.virus_injection emitted when it CONVERTED it: an
%   immersion (bath) or a dose (an UBERON site), the virus (and diluent) as
%   chemicals of one formulation, the anchor and, for a dose, the site
%   observation.
%
%   [V1, SPEC] = did2.convert.roundtrip.virus_injection(BODIES). V1 is the
%   virus_injection in NDI's v1 shape (treatment/virus_injection.json +
%   base.json at the locked NDI-matlab `main`, 3cb19a8; written by
%   +NDIMaker/treatmentMaker create_virus_injection_doc):
%
%     base.id, session_id, datestamp   the manipulation (rebuildBase)
%     depends_on(1) subject_id         the manipulation's `entity_id`
%     virus_OntologyName, virus_name   the first chemical's substance
%     dilution                         the first ingredient's concentration
%                                      source_value; 0 when it states none
%                                      (SPEC)
%     diluent_OntologyName, diluent_name
%                                      the second chemical's substance
%     virusLocation_OntologyName, virusLocation_name
%                                      a dose: the site observation's term;
%                                      an immersion: the bath (SPEC)
%     virus_AdministrationDate         the absolute anchor's source text
%     virus_AdministrationPND          the age observation's (NCIT:C25150,
%                                      on the manipulation's time reference)
%                                      source_value, in days ([age at
%                                      injection is an observation]); 0 when
%                                      the observation has no value and the
%                                      migration report lists `time.value`
%                                      ([postnatal day 0 not stated])
%
%   SPEC.equivalents: `dilution` 0 when the ingredient states no amount (named
%   as a gap, [canonical absent only as needs info], [formulation amount
%   needs info]) -- "A dilution of 0 is treated as not recorded (NaN), not as
%   a measured 0" (Jess Haley, 2026-10-21 [virus-location]); 0 is also the
%   template's value.
%
%   The template's `files` block is empty as the writer leaves it, and so not
%   set. (`virus_AdministrationPND` was not rebuilt before 2026-10-30.)
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.virus_injection.

arguments
    bodies cell
end

spec = emptySpec();
v1 = struct();
p = treatmentParts(bodies);
spec.unplaced = p.unplaced;
if isempty(p.manip)
    return;
end
[base, ~] = rebuildBase(p.manip);
rows = treatmentRows(p);

block = struct();
if ~isempty(rows)
    block.virus_OntologyName = rows(1).node;
    block.virus_name = rows(1).name;
    % [term names compare by node] (Jess Haley, 2026-10-29, did-schema
    % V_eta_go_forward_class_audit.md), here and for the diluent and the site
    spec = nameByNode(spec, 'virus_injection.virus_name', rows(1).node);
    if ~isempty(rows(1).value)
        block.dilution = rows(1).value;
    else
        spec.equivalents(end+1) = struct('path', 'virus_injection.dilution', ...
            'values', {{0}}, 'why', ['a dilution of 0 is not recorded: no amount ' ...
            '([virus-location]); 0 is the template value']);
    end
end
if numel(rows) >= 2
    block.diluent_OntologyName = rows(2).node;
    block.diluent_name = rows(2).name;
    spec = nameByNode(spec, 'virus_injection.diluent_name', rows(2).node);
end
if numel(rows) > 2
    spec.unplaced{end+1} = sprintf(['the formulation names %d ingredients; a ' ...
        'virus_injection states a virus and one diluent'], numel(rows));
end
if ~isempty(p.site)
    [block.virusLocation_OntologyName, block.virusLocation_name] = ...
        termParts(getIn(p.site, 'term', 'value'));
    spec = nameByNode(spec, 'virus_injection.virusLocation_name', ...
        block.virusLocation_OntologyName);
elseif strcmp(p.kind, 'formulation')
    spec = bathEquivalents(spec, 'virus_injection.virusLocation_OntologyName', ...
        'virus_injection.virusLocation_name');
end
onset = anchorOnset(p.anchor);
if ~isempty(onset)
    block.virus_AdministrationDate = onset;
end
if ~isempty(p.age)
    days = numberOf(getIn(p.age, 'time', 'value', 'source_value'));
    if isempty(days) && any(strcmp('time.value', did2.schema.reportedGaps(p.age)))
        % [postnatal day 0 not stated] (Jess Haley, 2026-11-01): the migrator
        % names the age as a gap only for v1's 0, the template default
        block.virus_AdministrationPND = 0;
    elseif isempty(days)
        spec.unplaced{end+1} = 'the age observation states no number of days';
    else
        block.virus_AdministrationPND = days;
    end
end

v1.document_class = struct('class_name', 'virus_injection');
ids = edgeIds(p.manip, 'entity_id');
if isempty(ids); ids = {''}; end
v1.depends_on = struct('name', 'subject_id', 'value', ids{1});
v1.base = struct('id', base.id, 'session_id', base.session_id, ...
    'datestamp', base.datestamp);
v1.virus_injection = block;

for f = {'virus_OntologyName', 'diluent_OntologyName', 'virusLocation_OntologyName'}
    spec.same(end+1) = struct('path', ['virus_injection.' f{1}], ...
        'fn', @(a, b) sameCurie(a, b), 'why', ['a node in the registry''s ' ...
        'spelling ([spelling is notation]; V_eta_prefix_spelling_plan.md)']);
end
end
