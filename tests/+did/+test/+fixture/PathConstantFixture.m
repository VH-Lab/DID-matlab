classdef PathConstantFixture < matlab.unittest.fixtures.Fixture
    methods
        function setup(fixture)
            fixture.addTeardown( @rehashPathConstants )
            rehashPathConstants()
        end
    end
end

function rehashPathConstants()
    % Recreate path constant directories if they do not exist. In some
    % environments, i.e linux, the path constants might be assigned in the
    % current working directory. This fixture should be used after a
    % working folder fixture to ensure that directories in the
    % PathConstants are created in the temporary working directory and
    % that this happens again when the fixture is teardown.
    mc = ?did.common.PathConstants;
    for i = 1:numel(mc.PropertyList)
        if ~isempty( mc.PropertyList(i).Validation )
            if strcmp( func2str(mc.PropertyList(i).Validation.ValidatorFunctions{1}), 'mustBeWritable')
                folderPath = did.common.PathConstants.(mc.PropertyList(i).Name) ;
                if ~isfolder(folderPath)
                    mkdir( did.common.PathConstants.(mc.PropertyList(i).Name) )
                end
            end
        end
    end
end
