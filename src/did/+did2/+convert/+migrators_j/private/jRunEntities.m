function [docs, osId, interpreterId] = jRunEntities(preBody, execEnv)
%JRUNENTITIES The operating system and interpreter a calculation ran on, as
%   `software` entities (did-schema #88, #73 item 53: the run-environment
%   entity was split into two `software` edges on `calculation`,
%   `operating_system_id` and `interpreter_id`, BOTH OPTIONAL: Jess Haley,
%   2026-10-21 [calculation-os-optional], "required when the operating system
%   is known, absent when the source never recorded it").
%
%   [DOCS, OSID, INTERPRETERID] = jRunEntities(PREBODY, EXECENV). EXECENV is
%   the struct jSoftwareFromApp returns from the v1 `app` block (os,
%   os_version, interpreter, interpreter_version). Each present program is a
%   jSoftware entity (name, with its version as a text assertion). An absent
%   OS gives OSID '' -- the calculation omits the edge; nothing is invented.

docs = {};
osId = '';
interpreterId = '';
sid = jSid(preBody);
ts = jStamp(preBody);
if isfield(execEnv, 'os') && ~isempty(execEnv.os)
    ver = '';
    if isfield(execEnv, 'os_version'); ver = char(execEnv.os_version); end
    [d, osId] = jSoftware(char(execEnv.os), ver, '', sid, ts);
    docs = [docs, d];
end
if isfield(execEnv, 'interpreter') && ~isempty(execEnv.interpreter)
    ver = '';
    if isfield(execEnv, 'interpreter_version'); ver = char(execEnv.interpreter_version); end
    [d, interpreterId] = jSoftware(char(execEnv.interpreter), ver, '', sid, ts);
    docs = [docs, d];
end
end
