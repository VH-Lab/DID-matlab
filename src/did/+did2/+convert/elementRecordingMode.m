function t = elementRecordingMode(elementType)
%ELEMENTRECORDINGMODE The decided recording or imaging mode of a v1 probe type.
%
%   T = did2.convert.elementRecordingMode(ELEMENTTYPE) is the mode term (a
%   {node, name} struct) that did2.convert.resolveEpochProbemap writes as the
%   `method.term` of a recording observation of a probe-map row of type
%   ELEMENTTYPE, or [] when no mode term is decided for the type. Types are
%   compared exactly, edge blanks aside, as NDI's probestruct2probe matches
%   its keys. The ONE table of modes: did2.convert.elementTypeOfKindAndMode
%   reads it back.
%
%   [element type is a device kind term] (Decided by Jess Haley, 2026-10-27,
%   did-schema did_v2_go_forward_class_audit.md): "recording mode suffixes
%   (-Vm, -I, -Im, -attached) go on the recording observation";
%   [imaging mode is a method term] (2026-10-29): the imaging mode is "a
%   method term on the recording observation". The decided terms:
%     patch-attached       OBI:0002179 "cell-attached patch clamp assay"
%                          ([element types batch 1], [cell-attached is OBI])
%     brightfield-imaging  EMPTY:0000300 "brightfield imaging"
%                          ([element types batch 2])
%     patch-Vm, sharp-Vm   OBI:0002185 "current clamp assay"
%     patch-I, sharp-I,    OBI:0002182 "voltage clamp assay"
%     sharp-Im             ([recording mode terms], Jess Haley, 2026-11-01:
%                          "OBI:0002185 'current clamp assay' (v1 `-Vm`) and
%                          OBI:0002182 'voltage clamp assay' (v1 `-I`, `-Im`)")
%     wide-field-imaging   OBI:0002437 "widefield microscopy assay"
%     two-photon-imaging   FBbi:00000254 "two-photon laser scanning microscopy"
%     one-photon-imaging   NCIT:C16856 "Fluorescence Microscopy"
%                          ([imaging mode terms], Jess Haley, 2026-11-01;
%                          term amended by [one-photon is NCIT fluorescence
%                          microscopy], Jess Haley, 2026-11-03)
%   A bare `patch` or `sharp` names no mode: [] for it.
%
%   (Moved out of resolveEpochProbemap's private recordingModeMethod, which
%   now calls it, so the round trip reads the same table.)
%
%   See also did2.convert.elementTypeOfKindAndMode,
%   did2.convert.resolveEpochProbemap.

arguments
    elementType = ''
end

t = [];
switch strtrim(char(elementType))
    case 'patch-attached'
        t = did2.convert.registeredTerm('OBI:0002179', 'cell-attached patch clamp assay');
    case 'brightfield-imaging'
        t = did2.convert.registeredTerm('EMPTY:0000300', 'brightfield imaging');
    case {'patch-Vm', 'sharp-Vm'}
        t = did2.convert.registeredTerm('OBI:0002185', 'current clamp assay');
    case {'patch-I', 'sharp-I', 'sharp-Im'}
        t = did2.convert.registeredTerm('OBI:0002182', 'voltage clamp assay');
    case 'wide-field-imaging'
        t = did2.convert.registeredTerm('OBI:0002437', 'widefield microscopy assay');
    case 'two-photon-imaging'
        t = did2.convert.registeredTerm('FBbi:00000254', 'two-photon laser scanning microscopy');
    case 'one-photon-imaging'
        t = did2.convert.registeredTerm('NCIT:C16856', 'Fluorescence Microscopy');
end
end
