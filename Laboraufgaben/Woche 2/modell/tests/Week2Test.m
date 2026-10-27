classdef Week2Test < matlab.unittest.TestCase
    methods (TestClassSetup)
        function projectPath(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
        end
    end
    methods (Test)
        function configuredCruisingSpeed(testCase)
            c = sbahn2.defaultConfig;
            c.motionModel = "Beschleunigen und Bremsen";
            c.cruiseSpeedKmh = 57.6;
            c.animate = false;
            c.durationMinutes = 10;
            [G,p,r] = sbahn2.simulate(c);
            testCase.verifyEqual(p.vmax,16);
            testCase.verifyEqual(max(G.velocity,[],'all'),16);
            testCase.verifyEqual(r.maxObservedSpeedKmh,57.6,'AbsTol',1e-10);
            testCase.verifyTrue(r.checksPassed);
        end
        function excessiveCruisingSpeedRejected(testCase)
            c = sbahn2.defaultConfig;
            c.cruiseSpeedKmh = 81;
            testCase.verifyError(@() sbahn2.prepare(c),'MATLAB:notLessEqual');
        end
        function originalDynamicsUnchanged(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            original = fullfile(root,'..','Woche 1','NaSch-SBahn');
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(original));
            for mode = ["On/Off","Beschleunigen und Bremsen"]
                c = sbahn.defaultConfig;
                c.motionModel = mode;
                c.animate = false;
                c.durationMinutes = 10;
                [a,pa,ra] = sbahn.simulate(c);
                [b,pb,rb] = sbahn2.simulate(c);
                testCase.verifyEqual(a,b);
                testCase.verifyEqual(pa.state,pb.state);
                testCase.verifyEqual(ra,rb);
            end
        end
    end
end
