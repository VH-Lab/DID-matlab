classdef validate
    % Validate a did.document to ensure that the type of its properties 
    % match with the expected type according to its schema. Most of the logic
    % behind is implemented by Java using everit-org's json-schema library: 
    % https://github.com/everit-org/json-schema, a JSON Schema Validator 
    % for Java, based on org.json API. It implements the DRAFT 7 version
    % of the JSON Schema: https://json-schema.org/

    % did.validate objects takes an did.document and the database as input
    % need to check that all the input type match with the expected type
    % correctly. If there is a depends-on fields, we also need to search
    % through the database to ensure this actually exists
    
    properties(SetAccess = protected, GetAccess = public)
        validators;          % Java validator object
        reports;             % report of the error messages
        is_valid             % is the ndi_document valid or not
        errormsg;
    end
    
    properties(SetAccess = private, GetAccess = public)
        errormsg_this;       % display any type mismatch of the current object's field
        errormsg_super;      % display any type mismatch of the super class object's field
        errormsg_depends_on; % display any depends_on objects that cannot be found in the database
    end
    
    methods
        function did_validate_obj = validate(document_obj,database_obj)
            if nargin == 0
                error("You must pass in an instance of document_obj and an instance of database as arguments");
            end
            
            % Initialization
            ndiValidatorJarFilepath = fullfile(did.common.PathConstants.javapath, ...
                'ndi-validator-java', 'jar', 'ndi-validator-java.jar');
            if ~any( strcmp(javaclasspath, ndiValidatorJarFilepath) )
                javaaddpath(ndiValidatorJarFilepath, 'end');
            end

            import com.ndi.*;
            import org.json.*;
            import org.everit.*;
            has_dependencies = 0;
            did_validate_obj.validators = struct();
            did_validate_obj.reports = struct();
            did_validate_obj.errormsg_this = "no error found" + newline;
            did_validate_obj.errormsg_super = "no error found" + newline;
            did_validate_obj.errormsg_depends_on = "no error found" + newline;
            did_validate_obj.errormsg = '';
            did_validate_obj.is_valid = true;
            %persistent format_validators_list;
            %if isempty(format_validators_list)
                %try
                    %format_validators_list = did.validate.load_format_validator();
                %catch e
                    %warning("Format validators aren't initialized properly: Here are the error messages" + newline + e.message);
                %end
            %end
            % Allow users to pass in only one argument if ndi_document_obj
            % does not have depends-on fields (since we don't really need
            % the ndi_session_obj)
            if nargin == 1
                database_obj = 0;
            end
            
            % Check if the user has passed in a valid ndi_document_obj
            if ~isa(document_obj, 'did.document')
                error('You must pass in an instance of did.document as your first argument');
            end
            
            % Only check if the user passed in a valid instance of
            % ndi_session if ndi_document_obj has dependency
            if isfield(document_obj.document_properties, 'depends_on')
                has_dependencies = 1;
                if ~isa(database_obj, 'did.database')
                    error('You must pass in an instnce of database as your second argument to check for dependency')
                end
            end 
            
            % ndi_document has a property called 'document_properties' that has all of the 
            % data of the document. For example, all documents have 
            % ndi_document_obj.document_properties.ndi_document with fields 'id', 'session_id', etc.
            schema = did.validate.extract_schema(document_obj);
            doc_class = document_obj.document_properties.document_class;
            %property_list = getfield(ndi_document_obj.document_properties, doc_class.property_list_name);
            property_list = eval( strcat('document_obj.document_properties.', doc_class.property_list_name));
            if has_dependencies == 1 
                % pass depends_on here
                property_list.depends_on = document_obj.document_properties.depends_on;
            end
            
            try
                format_validators_list = did.validate.get_format_validator(jsondecode(schema));
            catch e
                error("Format validators aren't initialized properly: Here are the error messages" + newline + e.message);
            end
            
            % validate all non-super class properties
            try
                did_validate_obj.validators.this = com.ndi.Validator( jsonencode(property_list), schema );
                if ~isempty(format_validators_list)
                    did_validate_obj.validators.this = did_validate_obj.validators.this.addValidators(format_validators_list);
                end
            catch e
                error("Fail to verify the ndi_document. This is likely caused by json-schema not formatted correctly"...
                        + "Here is the detail Java exception error: " + e.message)
            end
            did_validate_obj.reports.this = '';
            if did_validate_obj.validators.this.getReport().size() > 0
                did_validate_obj.is_valid = false;
                did_validate_obj.reports.this = did_validate_obj.validators.this.getReport();
                did_validate_obj.errormsg_this = string(doc_class.property_list_name) +  ":" ...
                +string(newline) + did.validate.readHashMap(did_validate_obj.reports.this) + string(newline);
            end
                               
            % validate all of the document's superclass if it exists 
            numofsuperclasses = numel(doc_class.superclasses);
            if numofsuperclasses > 0
                emptystruct(1,numofsuperclasses) = struct;
                did_validate_obj.validators.super = emptystruct;
                did_validate_obj.reports.super = emptystruct;
            end
            for i=1:numel(numofsuperclasses)
                % Step 1: read in the definition of the superclass at
                %   doc_class.superclasses(i).definition
                % Step 2: find the validator json in the superclass, call it validator_superclass
                % Step 3: convert the portion of the document that corresponds to this superclass to JSON
                superclass_name = doc_class.superclasses(i).definition;
                schema = did.validate.extract_schema(superclass_name);
                superclassname_without_extension = did.validate.extractnamefromdefinition(superclass_name);

                properties = struct( eval( strcat('document_obj.document_properties.', superclassname_without_extension) ) );
                % pass depends_on here 
                if has_dependencies == 1
                  properties.depends_on = document_obj.document_properties.depends_on;
                end
                validator = 0;
                try
                    validator = com.ndi.Validator( jsonencode(properties), schema );
                    if ~isempty(format_validators_list)
                        did_validate_obj.validators.this = did_validate_obj.validators.this.addValidators(format_validators_list);
                    end
                catch e
                    error("Fail to verify the ndi_document. This is likely caused by json-schema not formatted correctly"...
                            + "Here is the detail Java exception error: " + e.message)
                end
                report = validator.getReport();
                if report.size() > 0
                    did_validate_obj.is_valid = false;
                    did_validate_obj.validators.super(i).(superclassname_without_extension) = validator; 
                    did_validate_obj.reports.super(i).(superclassname_without_extension) = report; 
                    did_validate_obj.errormsg_super = string(superclassname_without_extension) +  ":"... 
                    + newline + did.validate.readHashMap(report) + string(newline);
                end
            end
            
            % check if there is depends-on field, if it exsists we need to
            % search through the ndi_session database to check 
            has_dependencies_error = 0;
            if has_dependencies == 1
                numofdependencies = numel(document_obj.document_properties.depends_on);
                %emptystruct(1,numofdependencies) = struct;
                did_validate_obj.reports.dependencies = struct();
                % NOTE: this does not verify that 'depends-on' documents have the right class membership
                % might want to add this in the future
                errormsgdependencies = "We cannot find the following necessary dependency from the database:" + newline;
                for i = 1:numofdependencies
                    searchquery = {'base.id', document_obj.document_properties.depends_on(i).value};
                    if numel(database_obj.search(searchquery)) < 1

                        did_validate_obj.reports.dependencies.(document_obj.document_properties.depends_on(i).name) = 'fail';
                        errormsgdependencies = errormsgdependencies + document_obj.document_properties.depends_on(i).name + newline;
                        did_validate_obj.is_valid = false;
                        has_dependencies_error = 1;
                    else
                        did_validate_obj.reports.dependencies(i).(document_obj.document_properties.depends_on(i).name) = "success";
                    end
                end
                if has_dependencies_error == 1
                    did_validate_obj.errormsg_depends_on = errormsgdependencies;
                end
            end
            % preparing for the overall report 
            if ~did_validate_obj.is_valid
                msg = "Validation has failed. Here is a detailed report of the source of failure:"...
                    + newline...
                    + "Here are the errors for the this instance of ndi_document class:" + newline...
                    + "------------------------------------------------------------------------------" + newline... 
                    + did_validate_obj.errormsg_this + newline...
                    + "------------------------------------------------------------------------------" + newline... 
                    + "Here are the errors for its super class(es)" + newline...
                    + "------------------------------------------------------------------------------" + newline... 
                    + did_validate_obj.errormsg_super + newline...
                    + "------------------------------------------------------------------------------" + newline ...
                    + "Here are the errors relating to its dependencies" + newline...
                    + "------------------------------------------------------------------------------" + newline ...
                    + did_validate_obj.errormsg_depends_on + newline...
                    + "------------------------------------------------------------------------------" + newline...
                    + "To get this detailed report as a struct. Please access its instance field report";
                did_validate_obj.errormsg = msg;
            else
                did_validate_obj.errormsg = 'This ndi_document contains no type error';
            end
        end

        function throw_error(did_validate_obj)
            if ~(did_validate_obj.is_valid)
                error(did_validate_obj.errormsg) 
            end
        end
        
    end

    methods(Static, Access = private)
        function format_validators = get_format_validator(schema)
            %   GET_FORMAT_VALIDATOR - get the necessary format validators
            %                          needed to validate a json document
            %                          that contains a costume format tag
            %
            %   SCHEMA - a struct representing the json document's
            %            corresponding schema
            %
            %   FORMAT_VALIDATORS = GET_FORMAT_VALIDATOR(SCHEMA)
            %

            didCache = did.common.getCache();

            if ~any(strcmp(javaclasspath,[did.common.PathConstants.javapath filesep 'ndi-validator-java' filesep 'jar' filesep 'ndi-validator-java.jar']))

                eval("javaaddpath([did.common.PathConstants.javapath filesep 'ndi-validator-java' filesep 'jar' filesep 'ndi-validator-java.jar'], 'end')");
            end
            import com.ndi.*;
            import org.json.*;
            import org.everit.*;
            
            format_validators = java.util.ArrayList();
           
            fields = fieldnames(schema.properties);
            for i = 1 : numel(fields)
                if isfield(schema.properties.(fields{i}), 'format') && isfield(schema.properties.(fields{i}), 'location')
                    format_validator = didCache.lookup(schema.properties.(fields{i}).location, schema.properties.(fields{i}).format);
                    if numel(format_validator) == 0
                        disp(['Loading data from controlled vocabulary for ', schema.properties.(fields{i}).format, '. This might take a while:'])
                        json_object = JSONObject(fileread(did.common.utility.replace_didpath(schema.properties.(fields{i}).location)));
                        %for now assume that the definition file json is
                        %formatted correctly
                        filepath = did.common.utility.replace_didpath( string(json_object.getString("filePath")) );
                        json_object = json_object.put("filePath", filepath);
                        if json_object.has("loadTableIntoMemory") == false
                            json_object.put("loadTableIntoMemory", true);
                        end
                        format_validator = EnumFormatValidator.buildFromSingleJSON(json_object);
                        didCache.add(schema.properties.(fields{i}).location, schema.properties.(fields{i}).format, format_validator);
                    else
                        format_validator = format_validator.data;
                    end
                    format_validators.add(format_validator);
                end
            end
        end
        
        function schema_json = extract_schema(document_obj)
            %   EXTRACT_SCHEMA - Extract the content of the ndi_document's
            %                    corresponding schema
            %
            %   SCHEMA_JSON = EXTRACT_SCHEMA(NDI_DOCUMENT_OBJ)
            %
            schema_json = "";
            if isa(document_obj, 'did.document')
                schema_path = document_obj.document_properties.document_class.validation;
                schema_path = did.common.utility.replace_didpath(schema_path);
                try
                    schema_json = fileread(schema_path);
                catch
                    error("the schema path does not exsist");
                end
            end
            if isa(document_obj, 'char') || isa(document_obj, 'string')
                schema_json = did.validate.extract_schema( did.document(did.common.utility.replace_didpath(document_obj)) );
            end
        end
        
        function name = extractnamefromdefinition(str)
            %   STR - File name contains ".json" extension
            %   Remove the file extension
            %
            %   NAME = EXTRACTNAME(STR)
            %
            file_name = split(str, filesep);
            name = split(file_name(numel(file_name)), ".");
            name = string(name(1));
        end
        
        function str = readHashMap(java_hashmap)
            %   turn an instance of java.util.hashmap into string useful
            %   for displaying the error messages
            %
            %   java_hashmap - an instance of java.util.HashMAP
            %   
            %   STR = READHASHMAP(JAVA_HASHMAP)
            %
            if (~isa(java_hashmap, 'java.util.HashMap'))
                error("Must pass in an instance of java.util.HashMap");
            end
            str = '[';
            keys = java_hashmap.keySet().toArray();
            len = size(java_hashmap.keySet());
            if len == 0
                str = '[]';
                return;
            end
            for i = 1:len
                str = strcat(str, keys(i), " : ", java_hashmap.get(keys(i)), "]");
                str = str + newline + "[";
            end
            str = strcat(extractBetween(str, 1, strlength(str)-3), ']');
        end
        
    end
end
