function bodies = speed_tuning_calc(preBody)
%SPEED_TUNING_CALC Brainstorm-J migrator -> speed_tuning_calculation (did-schema #88).
%   Brainstorm-J migrator: the ndi.calc.vis.speed calculator
%   OUTPUT document -> the CONCRETE V_eta leaf `speedtuning_calc`
%   (⊂ [tuning_curve_calculation, speed_tuning]) + a session anchor + minted
%   `software` and `runtime_environment` entities.
%
%   V_eta emits `speedtuning_calc` (no interior underscore) per Lepsky et al.
%   2026. speed_tuning has TWO independent variables (temporal + spatial
%   frequency), first-class via independent_variables[] cardinality.
%
%   Fold is 1 -> 1 with base.id + depends_on preserved. See
%   did2.convert.migrators_j.private.jCalculation.
%
%   READS RAW v1 (did2.convert.rawV1Classes; Decided by Jess Haley, 2026-10-26
%   [migrators read raw v1]). NDIcalc-vis-matlab's ndi.calc.vis.speed_tuning
%   writes the class as `speedtuning_calc` (its template calc/speedtuning_calc.json
%   and its stored self-test output mock/speed_tuning/mock.N.json);
%   rawV1Classes' one table maps that spelling to this migrator. The renamed
%   path never did (universalRenames maps only the contrast spellings), so
%   before the switch a writer's document passed through unconverted. The
%   document is read exactly as v1 wrote it: identity through jRawBody, the
%   `app` block in either spelling (did2.convert.v1read.readApp), and every
%   other field accounted for (jCalculation 'AccountForEveryField': a field the
%   fold reads nowhere carries the document whole as v1: carry-100 outside the
%   NDI template, carry-056 for a template field with no home). A carry is
%   the untouched v1 source. did2.convert.roundtrip.speedtuning_calc rebuilds
%   the v1 document; testRawV1RoundTripSpike compares the two on the writer's
%   output.
%   The fold is private/jSpeedTuning, shared with +migrators_j/speed_tuning.m
%   (the same `speed_tuning` block written alone).
arguments
    preBody (1,1) struct
end
bodies = jSpeedTuning(preBody, 'speed_tuning_calc');   % private/jSpeedTuning
end
