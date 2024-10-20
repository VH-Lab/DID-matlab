function s = number_to_alpha_label(n)
% NUMBER_TO_ALPHA_LABEL - return an alphabetic label for a number; 1 is a, 2 is b, 27 is aa, etc.
%
% S = NUMBER_TO_ALPHA_LABEL(N)
%
% Generate an alphabetic label for a number. When the number is greater than 26, then additional 
% characters will be used to specify the number.
% For example, 1 is 'a', 2 is 'b', 27 is 'aa', etc.
%
% Examples:
%  s1 = did.test.helper.utility.number_to_alpha_label(1)
%  s2 = did.test.helper.utility.number_to_alpha_label(2)
%  s27 = did.test.helper.utility.number_to_alpha_label(27)
%  s1001 = did.test.helper.utility.number_to_alpha_label(1001)
%

base_26 = dec2base(n,26);

for i=1:numel(base_26),
	base_26(i) = char(48+int8(base_26(i)));
end;

s = base_26;

