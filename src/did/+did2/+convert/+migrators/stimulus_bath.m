function v2Body = stimulus_bath(preBody)
%STIMULUS_BATH Migrate a did_v1 stimulus_bath body to V_delta.
%
%   v1 stimulus_bath stores an ontology-typed bath location plus an
%   inline CSV `mixture_table` listing chemicals:
%
%       stimulus_bath.location       - {ontologyNode, name}
%       stimulus_bath.mixture_table  - "ontologyName,name,value,ontologyUnit,unitName\n
%                                       <chemical_curie>,<name>,<value>,
%                                       <unit_curie>,<unit_name>\n
%                                       ..."
%
%   V_delta keeps `location` as an ontology_term composite (just
%   renames `ontologyNode` -> `node`) and parses the mixture CSV
%   into an array-of-records `mixture` field. Each chemical row
%   becomes a record with the chemical identity as an ontology_term
%   and the concentration as a `concentration` composite.
%
%   The `concentration` composite carries source_unit / source_value
%   verbatim plus optional canonical sub-fields populated whenever
%   the source unit is computable into them:
%
%       molar           (canonical for source_unit in {Molar, M,
%                        Millimolar, mM, Micromolar, uM, μM,
%                        Nanomolar, nM, Picomolar, pM})
%       grams_per_liter (canonical for {g/L, g/l, grams per liter,
%                        mg/mL, mg/ml, mg/L, mg/l, ug/mL, ug/L,
%                        μg/mL, μg/L})
%       mass_fraction   (canonical for {w/w, %w/w})
%       volume_fraction (canonical for {v/v, %v/v})
%
%   Unknown source units leave every canonical sub-field absent but
%   still preserve source_unit / source_value -- consumers retain
%   the raw value and can compute canonicals later when conventions
%   firm up.

arguments
    preBody (1,1) struct
end

v2Body = preBody;
if ~isfield(v2Body, 'stimulus_bath') ...
        || ~isstruct(v2Body.stimulus_bath)
    error('did2:convert:missingBlock', ...
        'stimulus_bath body is missing the stimulus_bath property block.');
end

block = v2Body.stimulus_bath;

newBlock = struct();
newBlock.location = locationToOntologyTerm(block);
newBlock.mixture = parseMixtureTable(block);
v2Body.stimulus_bath = newBlock;
end

function term = locationToOntologyTerm(block)
% v1 location is a sub-struct {ontologyNode, name}. After
% universalRenames the inner field stays `ontologyNode` (the
% snake_case pass only renames top-level block fields, not nested
% struct fields). We rename here.
term = struct('node', '', 'name', '');
if ~isfield(block, 'location')
    return;
end
loc = block.location;
if ~isstruct(loc) || ~isscalar(loc)
    return;
end
if isfield(loc, 'node')
    term.node = char(loc.node);
elseif isfield(loc, 'ontologyNode')
    term.node = char(loc.ontologyNode);
elseif isfield(loc, 'ontology_node')
    term.node = char(loc.ontology_node);
end
if isfield(loc, 'name')
    term.name = char(loc.name);
end
end

function mix = parseMixtureTable(block)
% Parse the v1 CSV mixture_table into an array-of-records. Empty
% or missing -> 0-element struct array (schema marks the field
% optional).
mix = struct('chemical', {}, 'amount', {});
if ~isfield(block, 'mixture_table')
    return;
end
raw = block.mixture_table;
if isempty(raw); return; end
if isstring(raw) && isscalar(raw); raw = char(raw); end
if ~ischar(raw); return; end

lines = strsplit(raw, newline);
lines = lines(~cellfun('isempty', lines));
if isempty(lines); return; end

% Detect header row -- if its first cell is the literal
% 'ontologyName' we skip it.
startIdx = 1;
firstCells = strsplit(lines{1}, ',');
if ~isempty(firstCells) && strcmpi(strtrim(firstCells{1}), 'ontologyName')
    startIdx = 2;
end

for k = startIdx:numel(lines)
    cells = strsplit(lines{k}, ',');
    cells = cellfun(@strtrim, cells, 'UniformOutput', false);
    if numel(cells) < 5; continue; end
    chemicalNode = cells{1};
    chemicalName = cells{2};
    valueStr     = cells{3};
    unitNode     = cells{4};
    unitName     = cells{5};
    valueNum = parseDouble(valueStr);
    mix(end+1) = struct( ...
        'chemical', struct('node', chemicalNode, 'name', chemicalName), ...
        'amount',   buildConcentration(valueNum, unitName, unitNode)); %#ok<AGROW>
end
end

function x = parseDouble(s)
x = NaN;
if isempty(s); return; end
try
    x = str2double(s);
catch
    x = NaN;
end
if ~isnumeric(x); x = NaN; end
end

function c = buildConcentration(value, unitName, ~)
% Build a `concentration` composite. Always populates
% source_unit / source_value; optionally populates one or more
% canonical sub-fields if unit_name is recognised.
c = struct( ...
    'approximate',  false, ...
    'source_unit',  char(unitName), ...
    'source_value', value);
if isnan(value); return; end

molarScale = molarScaleFor(unitName);
if ~isnan(molarScale)
    c.molar = value * molarScale;
    return;
end
gplScale = gramsPerLiterScaleFor(unitName);
if ~isnan(gplScale)
    c.grams_per_liter = value * gplScale;
    return;
end
if isMassFractionUnit(unitName)
    c.mass_fraction = value;
    return;
end
if isVolumeFractionUnit(unitName)
    c.volume_fraction = value;
    return;
end
% Unknown unit: leave canonicals absent; source-only.
end

function s = molarScaleFor(u)
% Unit-table lookup for source units that convert to mol/L by a
% pure scalar. Greek mu spellings are normalised to 'u' at the
% caller. Unknown unit -> NaN.
u = lower(char(u));
switch u
    case {'molar', 'm', 'mol/l', 'mol l-1'}
        s = 1;
    case {'millimolar', 'mm', 'mmol/l'}
        s = 1e-3;
    case {'micromolar', 'um', 'mumolar', 'umol/l'}
        s = 1e-6;
    case {'nanomolar', 'nm', 'nmol/l'}
        s = 1e-9;
    case {'picomolar', 'pm', 'pmol/l'}
        s = 1e-12;
    otherwise
        s = NaN;
end
end

function s = gramsPerLiterScaleFor(u)
u = lower(char(u));
switch u
    case {'g/l', 'g l-1', 'grams per liter', 'grams per litre', 'mg/ml', 'mg ml-1'}
        s = 1;
    case {'mg/l', 'mg l-1'}
        s = 1e-3;
    case {'ug/ml', 'ug ml-1', 'mug/ml'}
        s = 1e-3;
    case {'ug/l', 'ug l-1'}
        s = 1e-6;
    otherwise
        s = NaN;
end
end

function tf = isMassFractionUnit(u)
u = char(u);
tf = any(strcmpi(u, {'w/w', '%w/w', '%(w/w)'}));
end

function tf = isVolumeFractionUnit(u)
u = char(u);
tf = any(strcmpi(u, {'v/v', '%v/v', '%(v/v)'}));
end
