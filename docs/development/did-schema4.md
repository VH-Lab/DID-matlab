# DID Schema

## Schema outline

```json
{
	"classname": "classname",
	"superclasses": [ "class1", "class2", "class3" ],
	"depends_on": [
		{ "name": "name1", "mustbenotempty", 1},
		{ "name": "name2", "mustbenotempty", 1}
	],
	"file": [
		{ "name": "name1.ext", "mustbenotempty", 1},
		{ "name": "name2.ext", "mustbenotempty", 1}
	],
	"field": [
		{
			"name":	"",
			"type":		"",
			"default_value":	"",
			"parameters":		"",
			"queryable":		1,
			"documentation":	""
		},
		{
			"name":	"",
			"type":		"",
			"default_value":	"",
			"parameters":		"",
			"queryable":		1,
			"documentation":	""
		},
		{
			"subfield": {
				"name":		"subfield1",
				"field": [ {
					"name":			"",
					"type":			"",
					"default_value":	"",
					"parameters":		"",
					"queryable":		1,
					"documentation":	""
				} ]
			}
		}
	]
}
	
```

## Rules

fieldnames and structure names can be any alphanumeric character but can only have a at most two '__' characters in a row. It may not begin with a number but must begin with a letter.

`type` can be:

| type name | description | parameter string details |
| --- | --- | --- | 
| integer | Integer (single value) | should be MINVALUE, MAXVALUE, NANOKAY, where NANOKAY is 1 if NaN values are okay |
| double | Double precision value | MINVALUE, MAXVALUE, NANOKAY,EMPTYOK where NANOKAY is 1 if NaN values are okay and EMPTYOK is 1 if empty values are okay |
| matrix | Double precision matrix | ROWS, COLUMNS (the number of rows and the number of columns in the matrix. NaN can be used to specify that the size of a particular dimension is flexible. Example: [2,1] says the matrix must be 2 rows by 1 column. [NaN, 1] says the matrix must be a vector with any number of rows allowed and exactly 1 column. |
| stringarray | Array of strings | [MIN_NUMBER, MAX_NUMBER]. The MINIMUM and MAXIMUM number of string arrays allowed. Use NaN to ignore the limit. For example: [1, 2] means the string array can have 1 or 2 entries. [Nan, 2] means the string array can have at most 2 entries with no minimum. |
| timestamp | A timestamp in UTC | no parameters |
| char | A character array | maximum length |
| did_uid   | A DID UID | no parameters |

In the future, there will be more types, including a type that must match an entry in a table or a type that must match a node in an ontology.

`superclasses` lists the superclasses.

`depends_on` lists the database documents that this document depends on; if any of the documents that this document depends on
are deleted, then this document is deleted, too. In the validation schema, the necessary names are listed, as well as whether or not that
field is allowed to be empty (`mustbenotempty`). In the actual document, the UID associated with the name, if it is not empty, must refer to
a document in the database.

`file` is a list of file names (alphanumeric characters and '_' only) that are associated with the document. If the `mustbenotempty`
field is 1, then a file must be provided or the document is an error.

