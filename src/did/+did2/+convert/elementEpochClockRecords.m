function clocks = elementEpochClockRecords(body)
%ELEMENTEPOCHCLOCKRECORDS The clock records {name, t0, t1} of one element's
%   slice of an epoch, read from either shape a batch may hold.
%
%   CLOCKS = did2.convert.elementEpochClockRecords(BODY) returns a 1xN struct
%   array with fields name, t0, t1 (one per clock), or [] when BODY states none
%   that can be read:
%
%     v1 element_epoch     `element_epoch.epoch_clock` (comma-separated clock
%                          names) and `element_epoch.t0_t1` (one column per
%                          clock), read by did2.convert.v1read.elementEpochClocks,
%                          the reader +migrators_j/element_epoch.m used to
%                          write the records below
%     acquisition_epoch    `acquisition_epoch.clocks`, the records pass 1 wrote
%                          until [retired classes leave V2] (Decided by Jess
%                          Haley, 2026-10-25, step (1)) had it hand the v1
%                          document on unchanged (v1_to_v2 HAND_ON_CLASSES);
%                          read so a batch written before still dissolves
%
%   A v1 document whose clocks cannot be read was carried in pass 1 with its
%   note; read again here it yields [] and leaves no second note.
%
%   See also did2.convert.v1read.elementEpochClocks, did2.convert.epochMint,
%            did2.convert.resolveEpochProbemap.

clocks = [];
if ~isstruct(body) || ~isscalar(body)
    return;
end
if isfield(body, 'acquisition_epoch') && isstruct(body.acquisition_epoch) ...
        && isscalar(body.acquisition_epoch) && isfield(body.acquisition_epoch, 'clocks')
    c = body.acquisition_epoch.clocks;
    if isstruct(c)
        clocks = c;
    end
    return;
end
if ~isfield(body, 'element_epoch') || ~isstruct(body.element_epoch) ...
        || ~isscalar(body.element_epoch)
    return;
end
mark = did2.convert.reportNote('mark');
try
    read = did2.convert.v1read.elementEpochClocks(body);
catch
    read = body;
end
did2.convert.reportNote('truncate', mark);   % the pass-1 carry already noted it
if isequaln(read, body) || ~isfield(read, 'element_epoch') ...
        || ~isstruct(read.element_epoch) || ~isfield(read.element_epoch, 'clocks')
    return;
end
c = read.element_epoch.clocks;
if isstruct(c)
    clocks = c;
end
end
