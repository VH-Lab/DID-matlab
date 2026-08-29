function t = lock_expiration_time(str)
    % LOCK_EXPIRATION_TIME - parse a lock file's expiration line
    %
    % T = LOCK_EXPIRATION_TIME(STR)
    %
    % Parse the first line of a lock file, in either the ISO 8601 form this
    % package now writes ('2026-08-29T14:35:12.123456') or the older
    % char(datetime(...)) form ('29-Aug-2026 14:35:12') that it used to.
    %
    % T is a datetime in UTC, or Inf if STR is in neither form -- the
    % sentinel CHECKOUT_LOCK_FILE uses for "no expiry could be read", which
    % makes it wait rather than steal the lock.
    %
    % DID-python's did.file.parse_lock_expiration reads the same two forms.
    % Both languages lock the same files in a shared file cache, and a
    % reader that understands only its own format cannot tell an expired
    % lock from an unreadable one -- so a process that died holding the lock
    % would wedge the other language out permanently, which is exactly the
    % crash the expiry exists to recover from.
    %
    % See also: CHECKOUT_LOCK_FILE, RELEASE_LOCK_FILE

    arguments
        str {mustBeTextScalar}
    end

    t = Inf;
    str = strtrim(char(str));
    if isempty(str)
        return;
    end

    % ISO 8601, with or without fractional seconds. Listed first because it
    % is what both languages write now.
    formats = { ...
        'uuuu-MM-dd''T''HH:mm:ss.SSSSSS', ...
        'uuuu-MM-dd''T''HH:mm:ss.SSS', ...
        'uuuu-MM-dd''T''HH:mm:ss', ...
        'uuuu-MM-dd''T''HH:mm:ss.SSSSSS''Z''', ...  % a UTCLeapSeconds writer
        'uuuu-MM-dd''T''HH:mm:ss''Z''', ...
        'dd-MMM-uuuu HH:mm:ss', ...   % char(datetime(...)), the older form
        'dd-MMM-uuuu HH:mm:ss.SSS'};

    for i = 1:numel(formats)
        try
            % 'en_US' rather than the ambient locale: the month in the old
            % form is an English abbreviation wherever it was written, so
            % parsing it must not depend on the reader's locale.
            % 'UTC', not 'UTCLeapSeconds': the latter accepts only a
            % Z-suffixed Format, which would reject most of the forms above
            % outright. The leap-second difference is nothing against a
            % one-hour expiry.
            t = datetime(str, 'InputFormat', formats{i}, ...
                'TimeZone', 'UTC', 'Locale', 'en_US');
            return;
        catch
            % try the next format
        end
    end
end
