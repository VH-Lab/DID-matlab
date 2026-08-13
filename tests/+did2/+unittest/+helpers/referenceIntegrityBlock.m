function block = referenceIntegrityBlock(refRep, errMsg)
%REFERENCEINTEGRITYBLOCK The persistable form of did2.validate.references.
%   The second half of the "0 quarantine + 0 orphans" gate, shaped so it can be
%   written into <corpus>-summary.json and rendered by tools/census_digest.py.
%
%   MOVED OUT OF runCorpusDiscovery.m 2026-08-13, UNCHANGED, because a SECOND
%   caller arrived. `testCorpusPRED` gates on zero quarantine and had no orphan
%   check of any kind -- it never called did2.validate.references -- so the
%   corpus this project treats as its hard gate was covering exactly half of
%   the stated gate. Copying this function there would have put two
%   implementations of "how an orphan sweep is recorded" in the tree, and the
%   corpus_proven tooling already states the rule for that case in its own
%   words: two implementations that disagree is worse than one that is missing.
%
%   `audit` NAMES THE INSTRUMENT INSIDE THE BLOCK. The digest finds this block
%   BY SHAPE rather than by key name -- guessing a key name and then reporting
%   ABSENT when the guess missed is the demo_ndi failure (a query against a
%   string the input never contained, reported as a fact about the input). A
%   self-describing block means the FAILED case is findable by shape too, and
%   not only the successful one.
%
%   TWO DENOMINATORS, BOTH CARRIED, because one of them is the whole reason a
%   zero here is readable. `orphan_count == 0` with `edges_examined == 0` means
%   the sweep looked at nothing; `orphan_count == 0` with `edges_examined` in
%   the hundreds of thousands means every edge resolved. Those are opposite
%   findings and they print the same digit.
%
%   THE `orphans` ARRAY IS A CAPPED SAMPLE AND THE CAP ANNOUNCES ITSELF, the
%   same rule v1_to_v2's quarantine sample follows: a silent truncation is how
%   a report starts lying. JH alone carries >900k edges, so an unbounded array
%   would put a multi-hundred-megabyte artifact in the failure case -- exactly
%   the run whose report you need. `orphan_rows` is the COMPLETE aggregate
%   (bounded by the number of distinct class.edge pairs, not by the number of
%   orphans), so no count is lost to the cap: the sample shows what one looked
%   like, the rows say how many there were.
%
%   STATUS: NOT VERIFIED BY EXECUTION in the authoring environment (no MATLAB).

arguments
    refRep
    errMsg (1,:) char = ''
end

sampleCap = 200;
if isempty(refRep)
    % NOT a zero. The sweep did not produce a report, and the reason travels
    % with the block so "the audit failed" and "this corpus never swept" are
    % different output rather than one shared silence.
    %
    % THE PARENTHESIS HERE USED TO READ "(testCorpusPRED calls
    % did2.validate.references at no point)" AND THAT IS NO LONGER TRUE -- it
    % calls it as of 2026-08-13 and persists this block like every other
    % corpus. The DISTINCTION the sentence exists to protect is unchanged and
    % still load-bearing: a corpus that never sweeps persists no block at all,
    % and `tools/coverage.py` reads that absence as BLIND -- never a fault,
    % never a pass. What changed is only that PRED is no longer an example of
    % it.
    if isempty(errMsg)
        errMsg = 'did2.validate.references returned no report';
    end
    block = struct('audit', 'did2.validate.references', ...
        'audit_failed', errMsg);
    return;
end
[names, counts] = did2.unittest.helpers.aggregateOrphans(refRep.orphans);
rows = struct('key', {}, 'count', {});
for k = 1:numel(names)
    rows(end+1) = struct('key', names{k}, 'count', counts(k)); %#ok<AGROW>
end
shown = min(sampleCap, numel(refRep.orphans));
% BUILT FIELD BY FIELD RATHER THAN WITH struct(...). struct() EXPANDS a cell
% value into a struct ARRAY, and `orphan_rows` / `orphans` are arrays here;
% one of them arriving as a cell would silently turn this single block into an
% N-element struct array and the digest would then see a shape no test covers.
block = struct();
block.audit = 'did2.validate.references';
block.total_docs = refRep.total_docs;
block.edges_examined = refRep.edges_examined;
block.orphan_count = refRep.orphan_count;
block.orphan_rows = rows;
block.orphans_shown = shown;
block.orphan_sample_cap = sampleCap;
block.orphans = refRep.orphans(1:shown);
end
