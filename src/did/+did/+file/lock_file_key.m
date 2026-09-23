function key = lock_file_key(filename)
    % LOCK_FILE_KEY - the key recorded in a lock file
    %
    % KEY = LOCK_FILE_KEY(FILENAME)
    %
    % Return the key on the second line of the lock file FILENAME, or ''
    % when the file is missing, unreadable, or does not have the two lines
    % CHECKOUT_LOCK_FILE writes. '' never equals a real key, so a caller
    % comparing against its own key treats an unreadable lock as one it does
    % not hold.
    %
    % CHECKOUT_LOCK_FILE uses this to confirm, after writing, that the key
    % that survived is its own.
    %
    % See also: CHECKOUT_LOCK_FILE, RELEASE_LOCK_FILE

    arguments
        filename {mustBeTextScalar}
    end

    key = '';
    if ~isfile(filename)
        return;
    end

    C = did.file.readlines(filename);
    if numel(C) < 2
        return;
    end
    key = strtrim(C{2});
end
