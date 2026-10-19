classdef DisturbancesTest < matlab.unittest.TestCase
    properties (TestParameter)
        motion = struct('onOff',"On/Off",'dynamic',"Beschleunigen und Bremsen");
    end
    methods (TestClassSetup)
        function projectPath(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
        end
    end
    methods (Test)
        function targetedStopOccursExactlyOnce(testCase,motion)
            c = DisturbancesTest.config;
            c.motionModel = motion;
            c.durationMinutes = 120;
            c.targetStopEnabled = true;
            [~,p,r] = sbahn.simulate(c);
            testCase.verifyEqual(r.targetedStopCount,1);
            testCase.verifyEqual(r.assignedTargetedSeconds,60);
            testCase.verifyEqual(r.maxDwellSeconds,90);
            testCase.verifyEqual(p.state.stopLog(p.state.stopLog(:,5) > 0,2:3),[1 2]);
            testCase.verifyTrue(r.checksPassed);
        end
        function targetWaitsForEligibleArrival(testCase)
            c = DisturbancesTest.config;
            c.durationMinutes = 120;
            c.targetStopEnabled = true;
            c.targetStopAfterSeconds = 2000;
            [~,p,r] = sbahn.simulate(c);
            actual = p.state.stopLog(p.state.stopLog(:,5) > 0,1);
            eligible = p.state.stopLog(p.state.stopLog(:,3) == 2 & p.state.stopLog(:,1) >= 2000,1);
            testCase.verifyEqual(actual,min(eligible));
            testCase.verifyEqual(r.targetedStopCount,1);
        end
        function randomDurationBounds(testCase)
            c = DisturbancesTest.config;
            c.randomStopEnabled = true;
            c.randomStopProbability = 1;
            [~,p,r] = sbahn.simulate(c);
            testCase.verifyEqual(r.randomStopCount,size(p.state.arrivalLog,1));
            testCase.verifyGreaterThanOrEqual(min(p.state.stopLog(:,6)),30);
            testCase.verifyLessThanOrEqual(max(p.state.stopLog(:,6)),120);
            testCase.verifyTrue(r.checksPassed);
        end
        function zeroProbabilityHasNoEffect(testCase)
            c = DisturbancesTest.config;
            a = sbahn.simulate(c);
            c.randomStopEnabled = true;
            c.randomStopProbability = 0;
            b = sbahn.simulate(c);
            testCase.verifyEqual(a,b);
        end
        function seedRepeatableAndDifferentSeedsDiffer(testCase)
            c = DisturbancesTest.config;
            c.randomStopEnabled = true;
            c.randomStopProbability = 1;
            a = sbahn.simulate(c);
            b = sbahn.simulate(c);
            c.randomSeed = 43;
            d = sbahn.simulate(c);
            testCase.verifyEqual(a,b);
            testCase.verifyNotEqual(a,d);
        end
        function globalRandomStateUnaffected(testCase)
            c = DisturbancesTest.config;
            c.randomStopEnabled = true;
            before = rng;
            sbahn.simulate(c);
            testCase.verifyEqual(rng,before);
        end
        function referenceRemainsUndisturbed(testCase)
            c = DisturbancesTest.config;
            a = sbahn.prepare(c);
            c.randomStopEnabled = true;
            c.targetStopEnabled = true;
            c.closureEnabled = true;
            c.closureStartSeconds = 0;
            [b,state] = sbahn.prepare(c);
            testCase.verifyEqual(a.expectedLapSeconds,b.expectedLapSeconds);
            testCase.verifyFalse(state.targetStopApplied);
            testCase.verifyEmpty(state.stopLog);
            testCase.verifyFalse(state.closureActivated);
        end
        function combinedStopAddsDurations(testCase)
            c = DisturbancesTest.config;
            c.targetStopEnabled = true;
            c.randomStopEnabled = true;
            c.randomStopProbability = 1;
            c.randomStopMinSeconds = 10;
            c.randomStopMaxSeconds = 10;
            [~,p,r] = sbahn.simulate(c);
            row = p.state.stopLog(p.state.stopLog(:,5) > 0,:);
            testCase.verifyEqual(row(4:6),[30 60 10]);
            testCase.verifyEqual(r.maxDwellSeconds,100);
        end
        function unfinishedExtraHoldReportedSeparately(testCase)
            c = DisturbancesTest.config;
            c.durationMinutes = 4;
            c.targetStopEnabled = true;
            c.targetStopSeconds = 300;
            [~,p,r] = sbahn.simulate(c);
            testCase.verifyEqual(r.assignedTargetedSeconds,300);
            testCase.verifyGreaterThan(r.observedExtraHoldTrainSeconds,0);
            testCase.verifyLessThan(r.observedExtraHoldTrainSeconds,300);
            testCase.verifyGreaterThan(p.state.extraWaitSteps,0);
        end
        function closureStopsAndReleases(testCase,motion)
            c = DisturbancesTest.config;
            c.motionModel = motion;
            c.closureEnabled = true;
            c.closureStartSeconds = 0;
            c.closureDurationSeconds = 600;
            c.durationMinutes = 20;
            [G,p,r] = sbahn.simulate(c);
            entry = p.blocks.startCells(2);
            testCase.verifyGreaterThan(r.closureBlockedTrainSeconds,0);
            testCase.verifyLessThan(max(G.position(G.timeSeconds <= 600,1)),entry);
            testCase.verifyTrue(any(G.position(G.timeSeconds > 600,1) >= entry));
            testCase.verifyEqual(r.closureGraceCount,0);
        end
        function unavoidableEntryGrantedOnce(testCase)
            c = DisturbancesTest.config;
            c.closureEnabled = true;
            c.closureStartSeconds = 53;
            c.closureDurationSeconds = 5000;
            c.durationMinutes = 120;
            [G,p,r] = sbahn.simulate(c);
            testCase.verifyEqual(r.closureGraceCount,1);
            testCase.verifyEqual(p.state.closureGraceLog,[53 1 2]);
            testCase.verifyTrue(G.closurePermission(54,1));
            testCase.verifyFalse(G.closurePermission(find(G.position(:,1) >= p.blocks.startCells(2),1),1));
            testCase.verifyGreaterThan(r.closureBlockedTrainSeconds,1000);
            testCase.verifyLessThanOrEqual(max(abs(diff(G.velocity)),[],'all'),1);
        end
        function wholeRingBlockCanBeClosedAtNextEntry(testCase)
            c = DisturbancesTest.config;
            c.blockLengthMeters = 37000;
            c.closureEnabled = true;
            c.closureBlock = 1;
            c.closureStartSeconds = 0;
            c.closureDurationSeconds = 5000;
            c.durationMinutes = 120;
            [~,~,r] = sbahn.simulate(c);
            testCase.verifyGreaterThan(r.closureBlockedTrainSeconds,0);
            testCase.verifyTrue(r.checksPassed);
        end
        function displayAndAnimationIndependent(testCase)
            c = DisturbancesTest.config;
            c.trackMode = "Reale Ringbahn S41";
            c.randomStopEnabled = true;
            c.targetStopEnabled = true;
            c.closureEnabled = true;
            c.closureStartSeconds = 0;
            a = sbahn.simulate(c);
            oldFigures = findall(groot,'Type','figure');
            c.displayMode = "Geografischer Streckenverlauf";
            c.animate = true;
            c.displayEvery = 300;
            c.framePauseSeconds = 0;
            b = sbahn.simulate(c);
            testCase.addTeardown(@delete,setdiff(findall(groot,'Type','figure'),oldFigures));
            testCase.verifyEqual(a,b);
        end
        function denseCombinedTrafficRemainsSafe(testCase)
            c = DisturbancesTest.config;
            c.trackMode = "Reale Ringbahn S41";
            c.dwellMode = "GTFS-Stationshalte";
            c.blockMode = "OSM-Signalabschnitte";
            c.trainCount = 30;
            c.durationMinutes = 120;
            c.randomStopEnabled = true;
            c.targetStopEnabled = true;
            c.closureEnabled = true;
            [G,~,r] = sbahn.simulate(c);
            testCase.verifyTrue(r.checksPassed);
            testCase.verifyGreaterThan(r.randomStopCount,0);
            testCase.verifyEqual(r.targetedStopCount,1);
            testCase.verifyEqual(r.signalBlockedTrainSeconds, ...
                r.closureBlockedTrainSeconds+r.occupiedBlockTrainSeconds);
            testCase.verifyLessThanOrEqual(max(abs(diff(G.velocity)),[],'all'),1);
        end
        function closureRequiresBlocks(testCase)
            c = DisturbancesTest.config;
            c.blockMode = "Ohne Blocksteuerung";
            c.closureEnabled = true;
            testCase.verifyError(@() sbahn.prepare(c),'SBahn:ClosureBlock');
        end
        function targetRequiresValidTrain(testCase)
            c = DisturbancesTest.config;
            c.targetStopEnabled = true;
            c.targetStopTrain = 2;
            testCase.verifyError(@() sbahn.prepare(c),'SBahn:TargetStop');
        end
        function randomRangeRejected(testCase)
            c = DisturbancesTest.config;
            c.randomStopMinSeconds = 121;
            testCase.verifyError(@() sbahn.prepare(c),'SBahn:RandomStopRange');
        end
    end
    methods (Static, Access=private)
        function c = config
            c = sbahn.defaultConfig;
            c.motionModel = "Beschleunigen und Bremsen";
            c.trainCount = 1;
            c.animate = false;
            c.durationMinutes = 10;
            c.blockMode = "Gleichmäßige Blockabschnitte";
            c.targetStopStation = 2;
            c.targetStopAfterSeconds = 0;
            c.targetStopSeconds = 60;
            c.closureBlock = 2;
        end
    end
end
