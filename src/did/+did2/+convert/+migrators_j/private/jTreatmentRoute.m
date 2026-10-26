function route = jTreatmentRoute(locationTerm)
%JTREATMENTROUTE How a v1 treatment reached its subject, read from its
%   recorded location.
%
%   ROUTE = jTreatmentRoute(LOCATIONTERM), LOCATIONTERM a {node, name} term:
%
%     'immersion'  the location is the bath: the subject sat in the
%                  formulation, so the treatment is a `manipulation` valued by
%                  the formulation through `value_id`, not a dose;
%     'dose'       any other location (intraperitoneal, a brain area, ...): a
%                  body site, so the subject was given an amount -- a dose;
%     'needs_mapping'  the location is an environmental medium -- agar plate
%                  medium (MICRO:0000480) or ambient air (XCO:0000918): the
%                  subject sat on or in it, so it is no body site and a dose
%                  would be a wrong reading, while which manipulation it is
%                  (an exposure, ...) is the dataset's meaning. The caller
%                  carries the document whole as v1;
%     'unknown'    no location at all: the caller carries the document as v1
%                  ([one-reading quick answers] (Q1), Jess Haley, 2026-10-26).
%
%   Decided by Jess Haley, 2026-10-21 (did-schema
%   V_eta_go_forward_class_audit.md): "The v1 treatment migrators decide by
%   the recorded location: a bath location makes the treatment an immersion
%   (a manipulation valued by its formulation through value_id); a body site
%   (intraperitoneal, a brain area, ...) makes it a dose, with the source's
%   amount when it has one and otherwise NaN in the quantity; virus_injection
%   is always a dose (an injection), its volume NaN when unrecorded, its
%   dilution staying on the formulation; a generic treatment with no location
%   stays a dose with NaN and is listed in the migration report as route
%   unknown."
%
%   SUPERSEDED IN PART by Jess Haley, 2026-10-21 [virus-location]:
%   "virus_injection follows the same location rule as the other treatments:
%   a bath location makes it an immersion (a manipulation of the subject
%   valued by the virus formulation through value_id, no location
%   observation); a body site makes it a dose. A dilution of 0 is treated as
%   not recorded (NaN), not as a measured 0." So virus_injection is routed here
%   too; "always a dose" no longer holds.
%
%   THE MEDIA ARE CARRIED, NOT ROUTED. [babu-media] (Jess Haley, 2026-10-21)
%   routed these as exposures; superseded for the generic stage by Decided by
%   Jess Haley, 2026-10-26 [dataset audit batch 1 and 2] (2): "the Babu
%   media/air/heat routing ... leaves; those rows carry as v1 with a
%   `needs_mapping` row naming exposure / temperature manipulation"
%   ([one correct reading]: "e.g. a medium the worms live on written as a dose"
%   is never written). The medium test is by node (CURIE key) or by the
%   writer's label ("agar plate medium", "ambient air"); the heat row is carried
%   in treatment_drug.m, before routing.
%
%   THE BATH TEST. The term is the bath when its node is NCIm:C0179246 (the
%   node NDI's writers use: +birren/TreatmentCreator.m, createSayaTreatments.m,
%   +babu/treatments.json `bath`), compared as a CURIE key so prefix case does
%   not matter; or its name is "bath"; or the term registry resolves it to a
%   term labelled "bath" (did2.convert.registeredTerm -- the registry holds no
%   such term today, so this catches a synonym only once one is registered).

node = '';
name = '';
if isstruct(locationTerm) && ~isempty(locationTerm)
    if isfield(locationTerm, 'node'); node = strtrim(char(locationTerm.node)); end
    if isfield(locationTerm, 'name'); name = strtrim(char(locationTerm.name)); end
end
if isempty(node) && isempty(name)
    route = 'unknown';
    return;
end
isBath = strcmpi(name, 'bath');
if ~isBath && ~isempty(node)
    isBath = strcmpi(curieKeyOf(node), curieKeyOf('NCIm:C0179246'));
end
if ~isBath
    r = did2.convert.registeredTerm(node, name);
    isBath = strcmpi(strtrim(r.name), 'bath');
end
if isBath
    route = 'immersion';
elseif isMedium(node, name)
    route = 'needs_mapping';
else
    route = 'dose';
end
end

function tf = isMedium(node, name)
% An environmental medium, not a site on the subject (the two NDI writers use:
% +babu/treatments.json `agar`, `air`). Recognised only so the row is CARRIED.
media = {'MICRO:0000480', 'agar plate medium'; 'XCO:0000918', 'ambient air'};
tf = false;
for k = 1:size(media, 1)
    if (~isempty(node) && strcmpi(curieKeyOf(node), curieKeyOf(media{k, 1}))) ...
            || strcmpi(name, media{k, 2})
        tf = true;
        return;
    end
end
end

function k = curieKeyOf(node)
try
    k = char(did2.schema.curieKey(node));
catch
    k = lower(node);
end
end
