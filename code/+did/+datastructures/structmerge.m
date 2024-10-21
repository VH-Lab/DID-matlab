function s_out = structmerge(s1, s2, options)
    % STRUCTMERGE - Merge struct variables into a common struct
    %
    %  S_OUT = STRUCTMERGE(S1, S2, ...)
    %
    %  Merges the structures S1 and S2 into a common structure S_OUT
    %  such that S_OUT has all of the fields of S1 and S2. When
    %  S1 and S2 share the same fieldname, the value of S2 is taken.
    %  The fieldnames will be re-ordered to be in alphabetical order.
    %
    %  The behavior of the function can be altered by passing additional
    %  arguments as name/value pairs.
    %
    %  Parameter (default)     | Description
    %  ------------------------------------------------------------
    %  ErrorIfNewField (0)     | (0/1) Is it an error if S2 contains a
    %                          |  field that is not present in S1?
    %  DoAlphabetical (1)      | (0/1) Alphabetize the field names in the result
    %
    %  See also: STRUCT

    % Updated Oct 15, 2024

    arguments
        s1 struct
        s2 struct
        options.ErrorIfNewField (1,1) logical = false
        options.DoAlphabetical (1,1) logical = true
    end

    fieldNames1 = fieldnames(s1);
    fieldNames2 = fieldnames(s2);

    if options.ErrorIfNewField,
        missingFieldNames = setdiff(fieldNames2, fieldNames1);
        if ~isempty(missingFieldNames),
            missingFieldNames = join( compose("  ""%s""", string(missingFieldNames)), newline);
            error('DID:StructMerge:MissingField', ...
                'Some fields of the second structure are not in the first:\n%s', missingFieldNames);
        end;
    end;

    s_out_ = s1;

    for i = 1:length(fieldNames2),
        iFieldName = fieldNames2{i};
        iFieldValue = s2.(iFieldName);
        if isempty(s_out_),
            s_out_(1).(iFieldName) = iFieldValue;
        else,
            s_out_.(iFieldName) = iFieldValue;
        end;
    end;

    if options.DoAlphabetical,
        fn = sort(fieldnames(s_out_));
        s_out = did.datastructures.emptystruct(fn{:});
        for i = 1:length(fn),
            iFieldName = fn{i};
            iFieldValue = s_out_.(fn{i});
            if isempty(s_out),
                s_out(1).(iFieldName) = iFieldValue;
            else,
                s_out.(iFieldName) = iFieldValue;
            end;
        end;
    else,
        s_out = s_out_;
    end;
end
