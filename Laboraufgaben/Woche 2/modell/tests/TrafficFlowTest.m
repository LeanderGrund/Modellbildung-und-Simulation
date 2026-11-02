classdef TrafficFlowTest < matlab.unittest.TestCase
    methods (TestClassSetup)
        function projectPath(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
        end
    end
    methods (Test)
        function zeroProbabilityPreservesOriginalMotion(testCase)
            c = TrafficFlowTest.config;
            c.randomBrakeEnabled = false;
            [original,~,~] = sbahn2.simulate(c);
            c.randomBrakeEnabled = true;
            c.randomBrakeProbability = 0;
            [actual,p,~] = sbahn2.simulate(c);
            testCase.verifyEqual(rmfield(actual,{'randomBrakeTarget','randomBrakeApplied'}),original);
            testCase.verifyGreaterThan(size(p.state.blockEntryLog,1),0);
            testCase.verifyEqual(nnz(p.state.blockEntryLog(:,6)),0);
        end
        function everyBlockEntryTriggersAtOne(testCase)
            c = TrafficFlowTest.config;
            c.randomBrakeProbability = 1;
            [G,p,r] = sbahn2.simulate(c);
            events = p.state.blockEntryLog;
            testCase.verifyGreaterThan(size(events,1),0);
            testCase.verifyTrue(all(events(:,6) == 1));
            testCase.verifyEqual(events(:,5),floor(events(:,4)/2));
            testCase.verifyLessThanOrEqual(max(abs(diff(G.velocity)),[],'all'),1);
            testCase.verifyTrue(r.checksPassed);
        end
        function brakingReachesHalfAndResumesAcceleration(testCase)
            c = TrafficFlowTest.config;
            c.blockLengthMeters = 2000;
            c.durationMinutes = 20;
            c.randomBrakeProbability = 1;
            [G,p,~] = sbahn2.simulate(c);
            targets = G.randomBrakeTarget(:,1);
            completed = find(isfinite(targets(1:end-1)) & isnan(targets(2:end)))+1;
            testCase.verifyNotEmpty(completed);
            % Mindestens ein abgeschlossenes Bremsereignis erlaubt bereits
            % im direkt folgenden Schritt erneute reguläre Beschleunigung.
            completed = completed(completed < numel(targets));
            resumed = G.velocity(completed+1,1) > G.velocity(completed,1);
            testCase.verifyTrue(any(resumed));
            events = p.state.blockEntryLog;
            event = find(events(:,4) >= 10,1);
            row = events(event,1)+1;
            testCase.verifyEqual(G.velocity(row+1,1),G.velocity(row,1)-1);
        end
        function randomStationHoldIncludesZeroAndIsAdditional(testCase)
            c = TrafficFlowTest.config;
            c.randomBrakeEnabled = false;
            c.randomStopEnabled = true;
            c.randomStopProbability = 1;
            c.randomStopMinSeconds = 0;
            c.randomStopMaxSeconds = 7;
            c.dwellOffsetSeconds = 6;
            c.durationMinutes = 40;
            [~,p,r] = sbahn2.simulate(c);
            events = p.state.stopLog;
            testCase.verifyTrue(all(events(:,6) >= 0 & events(:,6) <= 7));
            testCase.verifyTrue(all(events(:,6) == fix(events(:,6))));
            testCase.verifyEqual(events(:,4),repmat(36,size(events,1),1));
            testCase.verifyTrue(r.minimumDwellsSatisfied);
            c.randomStopMaxSeconds = 0;
            [~,~,r] = sbahn2.simulate(c);
            testCase.verifyEqual(r.assignedRandomSeconds,0);
        end
        function randomRunsAreReproducibleWithoutChangingGlobalRng(testCase)
            c = TrafficFlowTest.config;
            c.randomStopEnabled = true;
            c.randomStopMinSeconds = 0;
            before = rng;
            [a,pa,~] = sbahn2.simulate(c);
            [b,pb,~] = sbahn2.simulate(c);
            testCase.verifyEqual(a,b);
            testCase.verifyEqual(pa.state,pb.state);
            testCase.verifyEqual(rng,before);
        end
        function singleTrainHasNoAnticipationEffect(testCase)
            c = TrafficFlowTest.config;
            [a,~,~] = sbahn2.simulate(c);
            c.anticipationEnabled = true;
            [b,~,~] = sbahn2.simulate(c);
            testCase.verifyEqual(rmfield(b,'anticipationApplied'),a);
        end
        function smallBetaStillBrakesAndRespectsLeaderOrder(testCase)
            c = TrafficFlowTest.config;
            c.trainCount = 12;
            c.randomBrakeProbability = 0.2;
            c.durationMinutes = 15;
            c.anticipationEnabled = true;
            c.anticipationBeta = 0.05;
            [G,~,r] = sbahn2.simulate(c);
            [rows,trains] = find(G.anticipationApplied);
            testCase.verifyNotEmpty(rows);
            for k = 1:numel(rows)
                row = rows(k)-1; train = trains(k);
                [~,order] = sort(G.position(row,:));
                index = find(order == train);
                leader = order(mod(index,numel(order))+1);
                testCase.verifyLessThan(G.velocity(row,leader),G.velocity(row,train));
            end
            testCase.verifyTrue(r.checksPassed);
        end
    end
    methods (Static, Access=private)
        function c = config
            c = sbahn2.defaultConfig;
            c.motionModel = "Beschleunigen und Bremsen";
            c.blockMode = "Gleichmäßige Blockabschnitte";
            c.trainCount = 1;
            c.durationMinutes = 10;
            c.animate = false;
            c.randomBrakeEnabled = true;
            c.randomBrakeProbability = 0.15;
        end
    end
end
