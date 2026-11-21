function tf = isAcquisitionConfiguration(className)
%ISACQUISITIONCONFIGURATION True when CLASSNAME names a rig's configuration document.
%
%   TF = did2.convert.isAcquisitionConfiguration(CLASSNAME) is true for
%   `acquisition_configuration` and for `acquisition_system`, its name before
%   [acquisition configuration renamed] (Jess Haley, 2026-11-19; see
%   did2.convert.acquisitionConfigurationNames).
%
%   See also did2.convert.acquisitionConfigurationNames.
tf = (ischar(className) || (isstring(className) && isscalar(className))) ...
    && any(strcmp(char(className), did2.convert.acquisitionConfigurationNames()));
end
