function ts = migrationTime(action)
%MIGRATIONTIME The time the migration ran, as a V2 creation timestamp.
%
%   TS = did2.convert.migrationTime() returns the timestamp a migrated document
%   carries when its v1 source states no creation time of its own, formatted
%   'yyyy-MM-ddTHH:mm:ss.SSSZ' (UTC). It is the pinned run time when one is
%   pinned, else the current time.
%
%   did2.convert.migrationTime('pin') pins the current time and returns it, so
%   every document of one run carries the same time. A run that is already
%   pinned keeps its time. did2.convert.migrationTime('unpin') clears it.
%   did2.convert.v1_to_v2 pins for its own call when nothing is pinned; a caller
%   running the whole pipeline (NDI's ndi.migrate.local) pins once around it.
%
%   Decided by Jess Haley, 2026-10-25, did-schema
%   V_eta_go_forward_class_audit.md [no invented values]: a creation timestamp
%   is the v1 source document's own datestamp, else the time the migration
%   ran. This replaces the invented '2024-01-01T00:00:00.000Z' every site used
%   before. Callers read the source datestamp first and call this only when the
%   source has none.
%
%   See also: did2.convert.v1_to_v2.

arguments
    action (1,:) char {mustBeMember(action, {'', 'get', 'pin', 'unpin'})} = ''
end

persistent pinned
switch action
    case 'pin'
        if isempty(pinned); pinned = nowStamp(); end
        ts = pinned;
    case 'unpin'
        pinned = '';
        ts = '';
    case 'get'
        ts = char(pinned);
    otherwise
        if isempty(pinned)
            ts = nowStamp();
        else
            ts = pinned;
        end
end
end

function ts = nowStamp()
ts = char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z'''));
end
