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
        function gtfsOffsetPreservesProfileAndCycleBalance(testCase)
            c = sbahn2.defaultConfig;
            c.trackMode = "Reale Ringbahn S41";
            c.motionModel = "Beschleunigen und Bremsen";
            c.dwellMode = "GTFS-Stationshalte";
            c.cruiseSpeedKmh = 57.6;
            c.trainCount = 1;
            [base,~] = sbahn2.prepare(c);
            c.dwellOffsetSeconds = 6;
            [shifted,~] = sbahn2.prepare(c);
            testCase.verifyEqual(shifted.baseStationDwellSeconds,base.stationDwellSeconds);
            testCase.verifyEqual(shifted.stationDwellSeconds,base.stationDwellSeconds+6);
            testCase.verifyEqual(shifted.expectedLapSeconds-base.expectedLapSeconds,27*6);
        end
        function offsetIsAPlannedHold(testCase)
            c = sbahn2.defaultConfig;
            c.trackMode = "Reale Ringbahn S41";
            c.motionModel = "Beschleunigen und Bremsen";
            c.dwellMode = "GTFS-Stationshalte";
            c.dwellOffsetSeconds = 12;
            c.trainCount = 1;
            c.animate = false;
            c.durationMinutes = 10;
            [G,p,r] = sbahn2.simulate(c);
            events = p.state.stopLog;
            testCase.verifyEqual(events(:,4),p.stationDwellSeconds(events(:,3))');
            testCase.verifyEqual(G.extraWaitSteps,zeros(size(G.extraWaitSteps)));
            testCase.verifyEqual(r.assignedRandomSeconds+r.assignedTargetedSeconds,0);
            testCase.verifyTrue(r.checksPassed);
        end
        function safePhaseSearchPreservesTrainCountAndIsDeterministic(testCase)
            c = sbahn2.defaultConfig;
            c.trackMode = "Reale Ringbahn S41";
            c.motionModel = "Beschleunigen und Bremsen";
            c.dwellMode = "GTFS-Stationshalte";
            c.blockMode = "Gleichmäßige Blockabschnitte";
            c.cruiseSpeedKmh = 57.6;
            c.dwellOffsetSeconds = 6;
            c.trainCount = 36;
            testCase.verifyError(@() sbahn2.prepare(c),'SBahn:InitialBlockOverlap');
            c.initialPhaseSearch = true;
            [p,a] = sbahn2.prepare(c);
            [q,b] = sbahn2.prepare(c);
            testCase.verifyGreaterThan(p.initialPhaseShiftSeconds,0);
            testCase.verifyEqual(p.trainCount,36);
            testCase.verifyEqual(p.blocks.lengthMeters,q.blocks.lengthMeters);
            testCase.verifyEqual(a,b);
        end
    end
end
