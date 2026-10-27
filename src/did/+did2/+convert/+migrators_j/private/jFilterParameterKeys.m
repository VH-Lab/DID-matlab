function [keys, allKeys] = jFilterParameterKeys()
%JFILTERPARAMETERKEYS The `filter.parameters` keys private/jFrequencyFilter reads.
%
%   [KEYS, ALLKEYS] = jFilterParameterKeys(). KEYS is a struct, one field per
%   parameter jFrequencyFilter reads, holding the spellings it reads it under
%   (the writer's camelCase first, then the snake_case a renamed body carries,
%   then the template documentation's spelling where the writer differs: see
%   jFrequencyFilter's header). ALLKEYS is every spelling, one cellstr.
%
%   THE ONE LIST. jFrequencyFilter reads each parameter through these
%   spellings, and +migrators_j/pyraview carries a document whose
%   `filter.parameters` holds a key outside ALLKEYS whole as v1, carry-100 (Decided
%   by Jess Haley, 2026-10-27 [unknown filter parameter is malformed], did-schema
%   V_eta_go_forward_class_audit.md: `filter.parameters` is open in the
%   template, and the migrator reads only these five). So "a key the migrator
%   does not read" is decided by the same list the migrator reads with.
keys = struct( ...
    'sampleFrequency',      {{'sampleFrequency', 'sample_frequency'}}, ...
    'filterFrequency',      {{'filterFrequency', 'filter_frequency'}}, ...
    'order',                {{'order'}}, ...
    'passBandRipple',       {{'passBandRipple', 'pass_band_ripple', ...
                              'passbandRipple', 'passband_ripple'}}, ...
    'stopbandAttentuation', {{'stopbandAttentuation', 'stopband_attentuation', ...
                              'stopbandAttenuation', 'stopband_attenuation'}});
allKeys = struct2cell(keys);
allKeys = [allKeys{:}];
end
