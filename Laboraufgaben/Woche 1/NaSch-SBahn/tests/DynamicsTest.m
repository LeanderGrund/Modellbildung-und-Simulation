classdef DynamicsTest < matlab.unittest.TestCase
    methods (TestClassSetup)
        function projectPath(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
        end
    end
    methods (Test)
        function idealCycleAndBounds(testCase)
            c = sbahn.defaultConfig;
            c.motionModel = "Beschleunigen und Bremsen";
            c.animate = false;
            [G,p,r] = sbahn.simulate(c);
            testCase.verifyTrue(r.checksPassed);
            testCase.verifyEqual(p.dxMeters,1);
            testCase.verifyEqual(p.stepSeconds,1);
            testCase.verifyEqual(p.vmax,22);
            testCase.verifyEqual(r.maxObservedSpeedKmh,79.2,'AbsTol',1e-10);
            testCase.verifyLessThanOrEqual(max(abs(diff(G.velocity)),[],'all'),1);
            testCase.verifyTrue(r.allStationsVisited);
            testCase.verifyEqual(r.meanLapSeconds,p.expectedLapSeconds);
            testCase.verifyEqual(r.minDwellSeconds,30);
            testCase.verifyEqual(r.maxDwellSeconds,30);
            testCase.verifyEqual(r.blockedTrainSeconds,0);
            testCase.verifyTrue(any(diff(G.position) < 0,'all'));
        end
        function discreteBrakingAndRestart(testCase)
            c = sbahn.defaultConfig;
            c.motionModel = "Beschleunigen und Bremsen";
            c.trainCount = 1;
            c.durationMinutes = 5;
            c.animate = false;
            [G,p,~] = sbahn.simulate(c);
            t = p.state.arrivalLog(1,1);
            departure = p.state.departureLog(find(p.state.departureLog(:,1) >= t,1),1);
            testCase.verifyEqual(G.velocity(t-2:t+2,1),[4;3;2;1;0]);
            testCase.verifyEqual(G.position(t+1,1),p.route.stationCells(2));
            testCase.verifyEqual(G.position(t+1:t+31,1),repmat(p.route.stationCells(2),31,1));
            testCase.verifyEqual(departure-t,30);
            testCase.verifyEqual(G.velocity(departure+2:departure+5,1),[1;2;3;4]);
        end
        function realGtfsCycle(testCase)
            c = sbahn.defaultConfig;
            c.motionModel = "Beschleunigen und Bremsen";
            c.trackMode = "Reale Ringbahn S41";
            c.dwellMode = "GTFS-Stationshalte";
            c.animate = false;
            [~,p,r] = sbahn.simulate(c);
            testCase.verifyEqual(p.route.lengthMeters,36972);
            testCase.verifyEqual(p.route.sourceLengthMeters,36971.599,'AbsTol',1e-6);
            testCase.verifyLessThanOrEqual(r.maxStationRoundingMeters,0.5);
            testCase.verifyEqual(sum(p.stationDwellSeconds),912);
            testCase.verifyTrue(r.allStationsVisited);
            testCase.verifyEqual(r.meanLapSeconds,p.expectedLapSeconds);
            testCase.verifyEqual(r.minDwellSeconds,30);
            testCase.verifyEqual(r.maxDwellSeconds,48);
        end
        function repeatableAndDisplayIndependent(testCase)
            c = sbahn.defaultConfig;
            c.motionModel = "Beschleunigen und Bremsen";
            c.trackMode = "Reale Ringbahn S41";
            c.durationMinutes = 2;
            c.animate = false;
            a = sbahn.simulate(c);
            c.displayMode = "Geografischer Streckenverlauf";
            b = sbahn.simulate(c);
            testCase.verifyEqual(a,b);
        end
        function animationIndependent(testCase)
            c = sbahn.defaultConfig;
            c.motionModel = "Beschleunigen und Bremsen";
            c.trackMode = "Reale Ringbahn S41";
            c.displayMode = "Geografischer Streckenverlauf";
            c.durationMinutes = 1;
            c.animate = false;
            a = sbahn.simulate(c);
            previousFigures = findall(groot,'Type','figure');
            c.animate = true;
            c.framePauseSeconds = 0;
            c.displayEvery = 15;
            b = sbahn.simulate(c);
            newFigures = setdiff(findall(groot,'Type','figure'),previousFigures);
            testCase.addTeardown(@delete,newFigures);
            testCase.verifyEqual(a,b);
        end
        function minimumOneSecondHalt(testCase)
            c = sbahn.defaultConfig;
            c.motionModel = "Beschleunigen und Bremsen";
            c.stopSeconds = 1;
            c.trainCount = 1;
            c.animate = false;
            [~,~,r] = sbahn.simulate(c);
            testCase.verifyEqual(r.minDwellSeconds,1);
            testCase.verifyEqual(r.maxDwellSeconds,1);
        end
        function zeroDwellExplained(testCase)
            c = sbahn.defaultConfig;
            c.motionModel = "Beschleunigen und Bremsen";
            c.stopSeconds = 0;
            testCase.verifyError(@() sbahn.prepare(c),'SBahn:DynamicsDwell');
        end
        function unknownModelRejected(testCase)
            c = sbahn.defaultConfig;
            c.motionModel = "Unbekannt";
            testCase.verifyError(@() sbahn.prepare(c),'SBahn:MotionModel');
        end
        function unsafeInitialDensityRejected(testCase)
            c = sbahn.defaultConfig;
            c.motionModel = "Beschleunigen und Bremsen";
            c.trainCount = 150;
            c.stopSeconds = 1;
            testCase.verifyError(@() sbahn.prepare(c),'SBahn:TrainOverlap');
        end
        function denseTrafficBrakesRegularly(testCase)
            c = sbahn.defaultConfig;
            c.motionModel = "Beschleunigen und Bremsen";
            c.trainCount = 30;
            c.durationMinutes = 10;
            c.animate = false;
            [G,~,r] = sbahn.simulate(c);
            testCase.verifyTrue(r.checksPassed);
            testCase.verifyLessThanOrEqual(max(abs(diff(G.velocity)),[],'all'),1);
            testCase.verifyGreaterThanOrEqual(min(diff(sort(G.position,2),1,2),[],'all'),148);
        end
        function finalStateMatchesTrajectory(testCase)
            c = sbahn.defaultConfig;
            c.motionModel = "Beschleunigen und Bremsen";
            c.durationMinutes = 2;
            c.animate = false;
            [G,p,~] = sbahn.simulate(c);
            testCase.verifyEqual(p.state.position,G.position(end,:));
            testCase.verifyEqual(p.state.velocity,G.velocity(end,:));
            testCase.verifyEqual(p.state.waitSteps,G.waitSteps(end,:));
            testCase.verifyEqual(p.state.movedCells,sum(G.velocity(2:end,:),1));
        end
        function shortPartialConfiguration(testCase)
            c = struct('motionModel',"Beschleunigen und Bremsen", ...
                'trainCount',1,'durationMinutes',1/60,'animate',false);
            [G,p,r] = sbahn.simulate(c);
            testCase.verifySize(G.position,[2 1]);
            testCase.verifyEqual(p.state.timeSeconds,1);
            testCase.verifyTrue(r.checksPassed);
            testCase.verifyTrue(isnan(r.meanLapSeconds));
            testCase.verifyFalse(r.allStationsVisited);
        end
    end
end
