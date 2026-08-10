%SCRATCH Ad-hoc MATLAB probe, run by .github/workflows/matlab-scratch.yml.
%
%   IDLE. Nothing to run right now -- this file stays in the repo between uses
%   so the next person finds the workflow instead of rediscovering that these
%   containers have no MATLAB.
%
%   TO USE IT: replace the body below with whatever you need to SEE, then push.
%   A push touching this file runs it and prints to the workflow log; it gates
%   nothing and exits 0 even on a throw, so an error reports its identifier,
%   message and stack rather than a bare red X.
%
%   IT KEEPS PAYING FOR ITSELF.
%     probe 2/3  #63's family counter was reverted once as "undiagnosable" on
%                the strength of a pass/fail result. Probe 2 showed the
%                detection logic was RIGHT; probe 3 showed the counts were
%                computed and then never assigned to the report.
%     probe 5    printed MATLAB's empty shapes instead of guessing at them:
%                unique([]) is 0-by-1, so `for n = unique([])` iterates ONCE.
%     probe 6    checked the testCorpusPRED census wiring in 2 minutes instead
%                of assuming it across a 70-minute corpus run.
%     probe 8    settled the `oneepoch` chain before its tombstone was written,
%                and volunteered the thing nobody asked: the inherited block
%                arrives holding `clocks`, NOT the did_v1 `epoch_clock`/`t0_t1`,
%                because the base superclass migrator has already collapsed the
%                pair. A tombstone written from the NDI template -- which is what
%                the ground-truth rule normally demands -- would have matched no
%                real document.
%     probe 9    named the failing assertion in one run, and it was not the one
%                the evidence pointed at. See below.
%
%   PROBE 7 UNDER-DELIVERED, and that is worth recording. It correctly isolated
%   WHICH two tests failed, but its diagnostic extraction printed nothing -- the
%   DiagnosticRecord walk was written blind and never verified. A probe whose
%   output you cannot check is a probe that can mislead you. The cause was found
%   by reading `runJ` instead: v1_to_v2 returns did2.document OBJECTS read with
%   .get('dotted.path'), NOT structs, and the new tests used struct access
%   carried over from the fitcurve tests (which call a migrator directly and do
%   get structs back). NEXT TIME: have the probe print a shape first --
%   class(out.migrated{1}) -- before trying to format a failure.
%
%   PROBE 9 IS THE SEQUEL TO THAT LESSON, AND IT EARNED ITS KEEP TWICE.
%   One of four new `oneepoch` tests failed. The one visible difference in its
%   fixture was that it was the SINGLE-clock case where the passing two were
%   multi-clock -- a clean, plausible, WRONG lead. Probe 9 printed shapes before
%   comparing and the real cause fell out immediately:
%
%       doc.get('depends_on')       entries carry `value`
%       doc.toStruct().depends_on   entries carry `document_id`
%
%   universalRenames normalises v1's {name, value} to {name, document_id}
%   (universalRenames.m:372-380); toStruct exposes the normalised form while
%   get() still hands back `value`. The test read the edge through a helper
%   written for RAW migrator output, where the rename has not happened yet.
%   Nothing was wrong with the migrator or the schema. Clocks had nothing to do
%   with it.
%
%   THE PROBE ALSO THREW, on that same field, and that is the point rather than
%   an embarrassment: it threw on line 76 printing the value, AFTER it had
%   already printed `fieldnames: name, document_id`. The answer was in the output
%   before the crash, because the shape was printed before it was used.

fprintf('scratch.m is idle -- nothing to run.\n');
