classdef UnifiedModelTest < matlab.unittest.TestCase
    properties (TestParameter)
        animationCase = struct( ...
            'ideal',struct('track',"Idealisierter Ring", ...
                'display',"Schematischer Ring"), ...
            'realGeo',struct('track',"Reale Ringbahn S41", ...
                'display',"Geografischer Streckenverlauf"));
    end
    methods (TestClassSetup)
        function projectPath(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
        end
    end
    methods (Test)
        function idealStandard(testCase)
            c = sbahn.defaultConfig;
            c.animate = false;
            [G,p,r] = sbahn.simulate(c);
            testCase.verifyTrue(r.checksPassed);
            testCase.verifySize(G.position,[7201 12]);
            testCase.verifyEqual(r.meanLapSeconds,3600);
            testCase.verifyEqual(r.minHeadwaySeconds,300);
            testCase.verifyEqual(r.maxHeadwaySeconds,300);
            testCase.verifyEqual(r.minDwellSeconds,30);
            testCase.verifyEqual(r.maxDwellSeconds,30);
            testCase.verifyEqual(r.meanSpeedKmh,37,'AbsTol',1e-10);
            testCase.verifyEqual(p.state.visitCount,2*ones(12,27));
        end
        function realStandard(testCase)
            c = sbahn.defaultConfig;
            c.animate = false;
            c.trackMode = "Reale Ringbahn S41";
            [~,p,r] = sbahn.simulate(c);
            testCase.verifyTrue(r.checksPassed);
            testCase.verifyEqual(p.route.lengthMeters,36971.599,'AbsTol',1e-6);
            testCase.verifyEqual(p.route.stationNames(1),"Beusselstraße");
            testCase.verifyEqual(r.meanLapSeconds,3600);
            testCase.verifyEqual(r.minHeadwaySeconds,300);
            testCase.verifyEqual(r.maxHeadwaySeconds,300);
            testCase.verifyEqual(r.minDwellSeconds,30);
            testCase.verifyEqual(r.maxDwellSeconds,30);
            testCase.verifyEqual(p.state.visitCount,2*ones(12,27));
            testCase.verifyLessThanOrEqual(r.maxStationRoundingMeters,p.dxMeters/2);
            testCase.verifyGreaterThan(max(diff(p.route.stationCells)),2*min(diff(p.route.stationCells)));
        end
        function displayIndependent(testCase)
            c = sbahn.defaultConfig;
            c.trackMode = "Reale Ringbahn S41";
            c.animate = false;
            c.durationMinutes = 2;
            [a,~,~] = sbahn.simulate(c);
            c.displayMode = "Geografischer Streckenverlauf";
            [b,~,~] = sbahn.simulate(c);
            testCase.verifyEqual(a,b);
        end
        function dwellChangesCycle(testCase)
            c = sbahn.defaultConfig;
            c.animate = false;
            c.stopSeconds = 60;
            [~,~,r] = sbahn.simulate(c);
            testCase.verifyEqual(r.meanLapSeconds,4410);
            testCase.verifyEqual(r.minDwellSeconds,60);
            testCase.verifyEqual(r.maxDwellSeconds,60);
        end
        function invalidGeography(testCase)
            c = sbahn.defaultConfig;
            c.displayMode = "Geografischer Streckenverlauf";
            testCase.verifyError(@() sbahn.simulate(c),'SBahn:Geography');
        end
        function fractionalDwell(testCase)
            c = sbahn.defaultConfig;
            c.stopSeconds = 30.5;
            testCase.verifyError(@() sbahn.simulate(c),'SBahn:TimeGrid');
        end
        function fractionalDuration(testCase)
            c = sbahn.defaultConfig;
            c.durationMinutes = 1.001;
            testCase.verifyError(@() sbahn.simulate(c),'SBahn:Duration');
        end
        function repeatable(testCase)
            c = sbahn.defaultConfig;
            c.animate = false;
            c.durationMinutes = 2;
            a = sbahn.simulate(c);
            b = sbahn.simulate(c);
            testCase.verifyEqual(a,b);
        end
        function animationIndependent(testCase,animationCase)
            c = sbahn.defaultConfig;
            c.trackMode = animationCase.track;
            c.displayMode = animationCase.display;
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
        function gtfsProfile(testCase)
            c = sbahn.defaultConfig;
            c.trackMode = "Reale Ringbahn S41";
            c.dwellMode = "GTFS-Stationshalte";
            c.animate = false;
            [~,p,r] = sbahn.simulate(c);
            testCase.verifyEqual(sum(p.stationDwellSeconds),912);
            testCase.verifyEqual(p.stationDwellSeconds([1 2 4 11]),[42 30 48 48]);
            testCase.verifyEqual(p.dwellSampleCounts(1),16);
            testCase.verifyGreaterThan(min(p.dwellSampleCounts),0);
            testCase.verifyEqual(r.meanLapSeconds,3702);
            testCase.verifyEqual(r.minDwellSeconds,30);
            testCase.verifyEqual(r.maxDwellSeconds,48);
            testCase.verifyEqual(r.blockedTrainSeconds,0);
            testCase.verifyEqual(p.driveSpeedKmh,36971.599/2790*3.6,'AbsTol',1e-10);
        end
        function gtfsIgnoresUniformSetting(testCase)
            c = sbahn.defaultConfig;
            c.trackMode = "Reale Ringbahn S41";
            c.dwellMode = "GTFS-Stationshalte";
            c.stopSeconds = 600;
            p = sbahn.prepare(c);
            testCase.verifyEqual(sum(p.stationDwellSeconds),912);
            testCase.verifyEqual(p.expectedLapSeconds,3702);
        end
        function gtfsNeedsRealTrack(testCase)
            c = sbahn.defaultConfig;
            c.dwellMode = "GTFS-Stationshalte";
            testCase.verifyError(@() sbahn.simulate(c),'SBahn:DwellTrack');
        end
        function impossibleTrainLengthsRejected(testCase)
            c = sbahn.defaultConfig;
            c.trainCount = 2790;
            c.stopSeconds = 0;
            c.durationMinutes = 1/60;
            c.animate = false;
            testCase.verifyError(@() sbahn.prepare(c),'SBahn:CellCount');
        end
    end
end
