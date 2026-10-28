classdef TimetableComparisonTest < matlab.unittest.TestCase
    methods (TestClassSetup)
        function projectPath(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
        end
    end
    methods (Test)
        function completeFreeTripsHaveKnownError(testCase)
            c = sbahn.defaultConfig;
            c.trackMode = "Reale Ringbahn S41";
            c.motionModel = "Beschleunigen und Bremsen";
            c.dwellMode = "GTFS-Stationshalte";
            c.cruiseSpeedKmh = 57.6;
            c.trainCount = 1;
            c.durationMinutes = 130;
            c.animate = false;
            [~,p,~] = sbahn.simulate(c);
            r = sbahn.compareTimetable(p);
            testCase.verifyTrue(r.available);
            testCase.verifyGreaterThan(r.completedTripCount,0);
            testCase.verifyEqual(r.referenceSeconds,3558);
            testCase.verifyEqual(r.freeModelSeconds,3599);
            testCase.verifyEqual(r.measuredMeanSeconds,3599);
            testCase.verifyEqual(r.freeAbsoluteErrorSeconds,41);
            testCase.verifyEqual(r.measuredAbsoluteErrorSeconds,41);
        end
        function partialTripIsNotReportedAsMeasured(testCase)
            c = sbahn.defaultConfig;
            c.trackMode = "Reale Ringbahn S41";
            c.motionModel = "Beschleunigen und Bremsen";
            c.dwellMode = "GTFS-Stationshalte";
            c.trainCount = 1;
            c.durationMinutes = 2;
            c.animate = false;
            [~,p,~] = sbahn.simulate(c);
            r = sbahn.compareTimetable(p);
            testCase.verifyEqual(r.completedTripCount,0);
            testCase.verifyTrue(isnan(r.measuredMeanSeconds));
            testCase.verifyTrue(isnan(r.measuredAbsoluteErrorSeconds));
            testCase.verifyEqual(r.freeModelSeconds,3131);
            testCase.verifyEqual(r.freeAbsoluteErrorSeconds,427);
        end
        function idealRingHasNoMatchingGtfsReference(testCase)
            c = sbahn.defaultConfig;
            [p,state] = sbahn.prepare(c);
            p.state = state;
            r = sbahn.compareTimetable(p);
            testCase.verifyFalse(r.available);
            testCase.verifyTrue(isnan(r.referenceSeconds));
            testCase.verifyTrue(isnan(r.measuredAbsoluteErrorSeconds));
        end
    end
end
