function spec = bathEquivalents(spec, nodePath, namePath)
%BATHEQUIVALENTS An immersion's v1 location, which V2 does not write: an
%   immersion IS a treatment at the bath, so its v1 location can only have
%   been the bath, NCIm:C0179246 "bath", the node and name NDI's writers use
%   (+birren/TreatmentCreator.m, createSayaTreatments.m, +babu/treatments.json)
%   and the only location jTreatmentRoute routes to an immersion (Jess Haley,
%   2026-10-21 [treatment-location], [virus-location]: "a bath location makes
%   it an immersion ... no location observation"). Any other spelling is
%   reported lost. NODEPATH or NAMEPATH '' adds nothing for it.
why = ['an immersion is a treatment at the bath, NCIm:C0179246 "bath" ' ...
    '([treatment-location], [virus-location]; jTreatmentRoute)'];
if ~isempty(nodePath)
    spec.equivalents(end+1) = struct('path', nodePath, ...
        'values', {{'NCIm:C0179246'}}, 'why', why);
end
if ~isempty(namePath)
    spec.equivalents(end+1) = struct('path', namePath, ...
        'values', {{'bath'}}, 'why', why);
end
end
