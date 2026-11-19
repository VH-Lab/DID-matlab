function [sys, devId, k, kDev] = rigSystem(id, bodies, ctx)
%RIGSYSTEM The acquisition_system a rig is named by, from either shape.
%
%   [SYS, DEVID, K, KDEV] = rigSystem(ID, BODIES, CTX). ID is what a wiring
%   relation's `parent_id`, a rig's time reference's `referent_id` or a clock
%   alignment configuration's `input_id` / `output_id` names. Since Jess
%   Haley's 2026-11-19 decisions [acquisition system is a device entity] and
%   [a rig's clock belongs to its device] (did-schema
%   docs/plans/did_v2_standing_wiring_plan.md) migration names the rig's
%   DEVICE entity there, and the `acquisition_system` configuration points at
%   that device by `device_id`; before them it named the `acquisition_system`
%   itself. Both are read, so a batch migrated either way round-trips:
%
%     ID an acquisition_system  SYS that document, DEVID its device_id ('' when none)
%     ID an entity of type device  SYS the acquisition_system whose `device_id`
%                               is ID (exactly one), DEVID = ID
%
%   It is looked for in BODIES first, then in CTX (the batch index
%   did2.convert.roundtrip.wholeBatch passes). K is SYS's position in BODIES
%   and KDEV the device's (0 when not in BODIES or not named). SYS is [] when ID names neither, or a device no single
%   acquisition_system points at.
%
%   See also did2.convert.roundtrip.daqsystem, did2.convert.migrators_j.daqsystem.
sys = [];
devId = '';
k = 0;
kDev = 0;
if isempty(id)
    return;
end
id = char(id);
d = [];
for j = 1:numel(bodies)
    if strcmp(char(getIn(bodies{j}, 'base', 'id')), id)
        d = bodies{j};
        k = j;
        break;
    end
end
if isempty(d)
    d = ctxDoc(ctx, id);
    k = 0;
end
if isempty(d)
    return;
end
if strcmp(classNameOf(d), 'acquisition_system')
    sys = d;
    dv = edgeIds(d, 'device_id');
    if ~isempty(dv); devId = dv{1}; end
    return;
end
if ~isEntityOfType(d, 'device')
    k = 0;
    return;
end
devId = id;
kDev = k;
k = 0;
found = {};
at = [];
for j = 1:numel(bodies)
    if strcmp(classNameOf(bodies{j}), 'acquisition_system') ...
            && any(strcmp(edgeIds(bodies{j}, 'device_id'), id))
        found{end+1} = bodies{j}; %#ok<AGROW>
        at(end+1) = j; %#ok<AGROW>
    end
end
if isempty(found)
    for j = ctxReferrers(ctx, id)
        b = ctx.docs{j};
        if strcmp(classNameOf(b), 'acquisition_system') && any(strcmp(edgeIds(b, 'device_id'), id))
            found{end+1} = b; %#ok<AGROW>
            at(end+1) = 0; %#ok<AGROW>
        end
    end
end
if isscalar(found)
    sys = found{1};
    k = at(1);
else
    k = 0;
end
end
