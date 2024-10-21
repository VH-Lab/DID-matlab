function mustBeValidMachineFormat(value)
    arguments
        value (1,1) string
    end

    if ismissing(value); return; end

    VALID_MACHINE_FORMAT = ["n", "b", "l"];

    validFormatsAsString = strjoin( "  " + ["'n' (native)", "'b' (big-endian)", "'l' (little-endian)"], newline);

    assert(ismember(value, VALID_MACHINE_FORMAT), ...
        'Machine format must be one of:\n%s\n', validFormatsAsString)
end