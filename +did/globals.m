% GLOBALS - define global variables for DID
%
% DID.GLOBALS
%  
% Script that defines some global variables for the DID package
%
% The following variables are defined:
% 
% Name:                          | Description
% -------------------------------------------------------------------------
% did_globals.path.path          | The path of the DID distribution on this machine.
%                                |   (Initialized by did_Init.m)
% did_globals.path. ...          | A cell array with path words that begin with a '$'
%    definition_names            |   that will be substituted with the paths in
%                                |   'definition_locations'
%                                |   (Initialized by did_Init.m)
% did_globals.path. ...          | A cell array with file paths or urls that will be
%    definition_locations        |   substituted for each corresponding path word
%                                |   in the document definitions and schemas.
%                                |   (Initialized by did_Init.m)
% did_globals.path. ...          | The path of the NDI document validation schema
%    documentschemapath          |   (Initialized by did_Init.m)
% did_globals.path.preferences   | A path to a directory of preferences files
% did_globals.path.filecachepath | A path where files may be cached (not deleted every time)
% did_globals.path.temppath      | The path to a directory that may be used for
%                                |   temporary files (Initialized by did_Init.m)
% ndi_globals.path.testpath      | A path to a safe place to run test code
% ndi.debug                      | A structure with preferences for debugging
%

global did_globals

