function name = acquisitionConfigurationClass(cache)
%ACQUISITIONCONFIGURATIONCLASS The class a rig's configuration is written as.
%
%   NAME = did2.convert.acquisitionConfigurationClass() is
%   'acquisition_configuration' when the loaded schema declares that class,
%   else 'acquisition_system'. NAME = ...(CACHE) asks the did2.schema.cache
%   CACHE instead of the shared one.
%
%   Decided by Jess Haley, 2026-11-19 [acquisition configuration renamed]
%   (did-schema docs/plans/did_v2_standing_wiring_plan.md): `acquisition_system`
%   is renamed `acquisition_configuration`, how a device's recordings are
%   read. The siblings write the new name before did-schema renames the class
%   (did-schema CLAUDE.md section 3), and DID-matlab CI reads did-schema
%   `main`, so a writer asks the schema in use which name it holds, as
%   +migrators_j/syncrule.m asks for its edge names. Readers take either name
%   (did2.convert.acquisitionConfigurationNames).
%
%   See also did2.convert.acquisitionConfigurationNames,
%            did2.convert.isAcquisitionConfiguration.
if nargin < 1 || isempty(cache)
    cache = did2.schema.cache.shared();
end
name = 'acquisition_system';
if cache.hasClass('acquisition_configuration')
    name = 'acquisition_configuration';
end
end
