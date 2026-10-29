function id = jCarryId(body)
%JCARRYID The v1 document's base.id for a `carried_as_v1` note ('' when it
%   states none), read with did2.convert.v1read.readBase (a legacy
%   `ndi_document` identity too).
%
%   ID = jCarryId(BODY).
%
%   See also did2.convert.reportNote, did2.convert.v1read.readBase.

b = did2.convert.v1read.readBase(body);
id = b.id;
if ~ischar(id)
    id = '';
end
end
