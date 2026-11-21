function names = acquisitionConfigurationNames()
%ACQUISITIONCONFIGURATIONNAMES The class names of a rig's configuration document.
%
%   NAMES = did2.convert.acquisitionConfigurationNames() returns
%   {'acquisition_configuration', 'acquisition_system'}: the current name
%   first, then the name documents written before the rename carry. Decided
%   by Jess Haley, 2026-11-19 [acquisition configuration renamed] (did-schema
%   docs/plans/did_v2_standing_wiring_plan.md): `acquisition_system` is
%   renamed `acquisition_configuration`, how a device's recordings are read
%   (reader, epoch file pattern, epoch parameter readers, software, device).
%   DID-matlab reads both names before did-schema renames the class (did-schema
%   CLAUDE.md section 3, "Changes the siblings must follow land in the
%   siblings first"). A document's property block is named after its class, so
%   a reader takes the block by the document's own class name.
%
%   See also did2.convert.isAcquisitionConfiguration.
names = {'acquisition_configuration', 'acquisition_system'};
end
