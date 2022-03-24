# DID Schema

Example structure:

```
classname: "classname"
superclasses: {
"","",""
}
structure "structurename1" {
| fieldname1 | type | default_value | size, range parameters | queryable |
| fieldname2 | type | default_value | size, range parameters | queryable |
}
| fieldname1 | type | default_value | size, range parameters | queryable |
| fieldname2 | type | default_value | size, range parameters | queryable |

```

`type` can be:

| type name | description | parameter string details |
| --- | --- | --- | 
| structure  | Begins a structure inside curly braces { } | (no parameter string)
| integer | Integer (single value) | should be MINVALUE, MAXVALUE, NANOKAY, where NANOKAY is 1 if NaN values are okay |
| double | Double precision value | MINVALUE, MAXVALUE, NANOKAY, where NANOKAY is 1 if NaN values are okay |
| matrix | Double precision matrix | ROWS, COLUMNS (the number of rows and the number of columns in the matrix |
| timestamp | A timestamp in UTC | no parameters |
| did_uid   | A DID UID | no parameters |

Functions needed:

```
DIDschema2JSON
DIDschema2Sqlinfo (Column names)
Struct2SqlInfo (input: struct, output: col_names, col_values)
```
