classdef SpeedLimitTest < matlab.unittest.TestCase
    methods (TestClassSetup)
        function projectPath(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
        end
    end
    methods (Test)
        function enteredLimitControlsActualSpeed(testCase)
            c = sbahn.defaultConfig;
            c.motionModel = "Beschleunigen und Bremsen";
            c.cruiseSpeedKmh = 57.6;
            c.animate = false;
            c.durationMinutes = 10;
            [G,p,r] = sbahn.simulate(c);
            testCase.verifyEqual(p.config.cruiseSpeedKmh,57.6);
            testCase.verifyEqual(p.vmax,16);
            testCase.verifyEqual(max(G.velocity,[],'all'),16);
            testCase.verifyLessThanOrEqual(r.maxObservedSpeedKmh,c.cruiseSpeedKmh);
            testCase.verifyTrue(r.checksPassed);
        end
        function physicalLimitRoundsDown(testCase)
            c = sbahn.defaultConfig;
            c.motionModel = "Beschleunigen und Bremsen";
            c.trainCount = 1;
            c.cruiseSpeedKmh = 60;
            [p,~] = sbahn.prepare(c);
            testCase.verifyEqual(p.config.cruiseSpeedKmh,60);
            testCase.verifyEqual(p.driveSpeedKmh,57.6,'AbsTol',1e-10);
        end
        function valuesOutsideRangeAreRejected(testCase)
            c = sbahn.defaultConfig;
            c.cruiseSpeedKmh = 81;
            testCase.verifyError(@() sbahn.prepare(c),'MATLAB:notLessEqual');
            c.cruiseSpeedKmh = 0;
            testCase.verifyError(@() sbahn.prepare(c),'MATLAB:notGreaterEqual');
        end
    end
end
