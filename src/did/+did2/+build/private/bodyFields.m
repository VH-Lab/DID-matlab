function s = bodyFields(s)
%BODYFIELDS Drop the options a body builder was not given.
names = fieldnames(s);
for k = 1:numel(names)
    if isAbsent(s.(names{k}))
        s = rmfield(s, names{k});
    end
end
end
