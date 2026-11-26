function eic = epochInstrumentCensus(corpusName, result)
%EPOCHINSTRUMENTCENSUS Print did2.convert.roundtrip.epochInstrumentCensus of a
%   corpus run's final batch (RESULT.migrated) to the log, and return it.
%
%   Decided by Jess Haley, 2026-11-26 [instrument of an epoch interaction is
%   a link] (did-schema docs/plans/did_v2_go_forward_class_audit.md): before
%   it is built, the corpora are counted for interactions that name an
%   instrument_id and are not on an epoch. REPORT-ONLY and best-effort: a
%   throw is printed as NOT MEASURED and returned as `audit_failed`, never as
%   a zero.

try
    eic = did2.convert.roundtrip.epochInstrumentCensus(result.migrated);
    fprintf(['[%s] EPOCH INSTRUMENT CENSUS: %d final document(s); %d interaction(s); ' ...
        '%d name an instrument_id: on an epoch %d, NOT on an epoch %d\n'], corpusName, ...
        eic.documents_inspected, eic.interactions, eic.with_instrument, ...
        eic.on_epoch, eic.not_on_epoch);
    for k = 1:numel(eic.by_class)
        r = eic.by_class(k);
        fprintf('[%s]   instrument %s: %d (on an epoch %d, not %d)\n', corpusName, ...
            r.class_name, r.with_instrument, r.on_epoch, r.not_on_epoch);
    end
    for k = 1:numel(eic.not_on_epoch_why)
        fprintf('[%s]   not on an epoch, %s: %d\n', corpusName, ...
            eic.not_on_epoch_why(k).why, eic.not_on_epoch_why(k).count);
    end
    for k = 1:numel(eic.not_on_epoch_examples)
        x = eic.not_on_epoch_examples(k);
        fprintf('[%s]   example not on an epoch: %s %s instrument %s (%s)\n', corpusName, ...
            x.class_name, x.id, x.instrument_id, x.why);
    end
    fprintf(['[%s] EPOCH INSTRUMENT DEVICES: %d device entit(ies); linked before %d, ' ...
        'after %d (gained %d); element class asserted %d; unlinked after %d\n'], corpusName, ...
        eic.devices, eic.devices_linked_before, eic.devices_linked_after, ...
        numel(eic.devices_gained), eic.devices_element_class_asserted, eic.devices_unlinked_after);
    for k = 1:numel(eic.devices_gained)
        g = eic.devices_gained(k);
        fprintf('[%s]   device gained: %s "%s" by %s\n', corpusName, g.id, ...
            g.local_identifier, g.by);
    end
catch eicErr
    eic = struct('audit_failed', eicErr.message);
    fprintf('[%s] EPOCH INSTRUMENT CENSUS NOT MEASURED: %s\n', corpusName, eicErr.message);
end
end
