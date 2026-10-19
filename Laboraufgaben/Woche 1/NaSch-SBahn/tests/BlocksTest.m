classdef BlocksTest < matlab.unittest.TestCase
    properties (TestParameter)
        mode = struct('none',"Ohne Blocksteuerung",'uniform',"Gleichmäßige Blockabschnitte",'osm',"OSM-Signalabschnitte");
        target = struct('short',100,'medium',500,'long',1000);
    end
    methods (TestClassSetup)
        function projectPath(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
        end
    end
    methods (Test)
        function realRingAllModes(testCase,mode)
            c = BlocksTest.configuration;
            c.blockMode = mode;
            c.durationMinutes = 120;
            [G,p,r] = sbahn.simulate(c);
            testCase.verifyTrue(r.checksPassed);
            testCase.verifyEqual(p.trainCells,148);
            testCase.verifyEqual(p.effectiveTrainLengthMeters,148);
            testCase.verifyTrue(r.allStationsVisited);
            testCase.verifyLessThanOrEqual(max(abs(diff(G.velocity)),[],'all'),1);
            testCase.verifyTrue(any(diff(G.position) < 0,'all'));
            testCase.verifyEqual(G.signalBlocked(1,:),false(1,c.trainCount));
        end
        function uniformRasterClosesRing(testCase,target)
            c = BlocksTest.configuration;
            c.blockMode = "Gleichmäßige Blockabschnitte";
            c.blockLengthMeters = target;
            p = sbahn.prepare(c);
            testCase.verifyEqual(numel(p.blocks.startCells),ceil(p.route.lengthMeters/target));
            testCase.verifyEqual(sum(p.blocks.lengthMeters),p.route.lengthMeters);
            testCase.verifyLessThanOrEqual(range(p.blocks.lengthMeters),1);
            testCase.verifyGreaterThanOrEqual(min(p.blocks.cellBlock),1);
            testCase.verifyEqual(p.blocks.startCells(1),1);
        end
        function shortBlocksAndRearAtRingSeam(testCase)
            c = BlocksTest.configuration;
            c.blockMode = "Gleichmäßige Blockabschnitte";
            c.blockLengthMeters = 100;
            [~,p,r] = sbahn.simulate(c);
            testCase.verifyTrue(r.checksPassed);
            testCase.verifyLessThan(max(p.blocks.lengthMeters),p.trainLengthMeters);
            testCase.verifyEqual(p.blocks.cellBlock(1),1);
            testCase.verifyEqual(p.blocks.cellBlock(end),numel(p.blocks.startCells));
            testCase.verifyGreaterThan(numel(unique(p.blocks.cellBlock([1 end-146:end]))),1);
        end
        function osmProvenanceAndDistances(testCase)
            c = BlocksTest.configuration;
            c.blockMode = "OSM-Signalabschnitte";
            p = sbahn.prepare(c);
            testCase.verifyEqual(numel(p.blocks.startCells),117);
            testCase.verifyEqual(p.blocks.startCells(1),32);
            testCase.verifyEqual(sum(p.blocks.lengthMeters),p.route.lengthMeters);
            testCase.verifyLessThanOrEqual(max(abs(p.blocks.roundingMeters)),0.5);
            testCase.verifyTrue(contains(p.blocks.source,"unbestätigt"));
        end
        function noArtificialBoundaryAtOsmRingSeam(testCase)
            c = BlocksTest.configuration;
            c.blockMode = "OSM-Signalabschnitte";
            p = sbahn.prepare(c);
            testCase.verifyEqual(p.blocks.cellBlock(1),p.blocks.cellBlock(end));
            testCase.verifyNotEqual(p.blocks.cellBlock(1),p.blocks.cellBlock(32));
        end
        function displayAndRepeatability(testCase,mode)
            c = BlocksTest.configuration;
            c.blockMode = mode;
            a = sbahn.simulate(c);
            c.displayMode = "Geografischer Streckenverlauf";
            b = sbahn.simulate(c);
            testCase.verifyEqual(a,b);
        end
        function animationHasNoEffect(testCase)
            c = BlocksTest.configuration;
            c.blockMode = "OSM-Signalabschnitte";
            c.durationMinutes = 1;
            a = sbahn.simulate(c);
            previousFigures = findall(groot,'Type','figure');
            c.animate = true;
            c.framePauseSeconds = 0;
            c.displayEvery = 30;
            b = sbahn.simulate(c);
            testCase.addTeardown(@delete,setdiff(findall(groot,'Type','figure'),previousFigures));
            testCase.verifyEqual(a,b);
        end
        function blockControlCreatesQueues(testCase)
            c = BlocksTest.configuration;
            c.trainCount = 20;
            c.durationMinutes = 20;
            [~,~,freeReport] = sbahn.simulate(c);
            c.blockMode = "Gleichmäßige Blockabschnitte";
            c.blockLengthMeters = 1000;
            [G,~,r] = sbahn.simulate(c);
            testCase.verifyEqual(freeReport.signalBlockedTrainSeconds,0);
            testCase.verifyGreaterThan(r.signalBlockedTrainSeconds,0);
            testCase.verifyTrue(any(G.signalBlocked,'all'));
            testCase.verifyLessThanOrEqual(max(abs(diff(G.velocity)),[],'all'),1);
            testCase.verifyTrue(r.checksPassed);
        end
        function denseOsmTrafficEventuallyClearsBlocks(testCase)
            c = BlocksTest.configuration;
            c.trainCount = 30;
            c.durationMinutes = 120;
            c.blockMode = "OSM-Signalabschnitte";
            [~,~,r] = sbahn.simulate(c);
            testCase.verifyTrue(r.allStationsVisited);
            testCase.verifyGreaterThan(r.signalBlockedTrainSeconds,0);
            testCase.verifyTrue(r.checksPassed);
        end
        function coarseOnOffAlsoUsesBodiesAndBlocks(testCase)
            c = BlocksTest.configuration;
            c.motionModel = "On/Off";
            c.blockMode = "OSM-Signalabschnitte";
            [~,p,r] = sbahn.simulate(c);
            testCase.verifyEqual(p.trainCells,ceil(148/p.dxMeters));
            testCase.verifyGreaterThanOrEqual(p.effectiveTrainLengthMeters,148);
            testCase.verifyLessThan(p.effectiveTrainLengthMeters,148+p.dxMeters);
            testCase.verifyTrue(r.checksPassed);
        end
        function osmNeedsRealTrack(testCase)
            c = BlocksTest.configuration;
            c.blockMode = "OSM-Signalabschnitte";
            c.trackMode = "Idealisierter Ring";
            c.dwellMode = "Einheitlich";
            testCase.verifyError(@() sbahn.prepare(c),'SBahn:BlockTrack');
        end
        function initialSharedBlockRejected(testCase)
            c = BlocksTest.configuration;
            c.blockMode = "Gleichmäßige Blockabschnitte";
            c.blockLengthMeters = 37000;
            testCase.verifyError(@() sbahn.prepare(c),'SBahn:InitialBlockOverlap');
        end
        function subcellBlocksRejected(testCase)
            c = BlocksTest.configuration;
            c.blockMode = "Gleichmäßige Blockabschnitte";
            c.blockLengthMeters = 0.5;
            testCase.verifyError(@() sbahn.prepare(c),'SBahn:BlockGrid');
        end
        function oneTrainMaySpanWholeRingBlock(testCase)
            c = BlocksTest.configuration;
            c.blockMode = "Gleichmäßige Blockabschnitte";
            c.blockLengthMeters = 37000;
            c.trainCount = 1;
            [~,p,r] = sbahn.simulate(c);
            testCase.verifyEqual(numel(p.blocks.startCells),1);
            testCase.verifyEqual(r.blockedTrainSeconds,0);
        end
    end
    methods (Static, Access=private)
        function c = configuration
            c = sbahn.defaultConfig;
            c.trackMode = "Reale Ringbahn S41";
            c.motionModel = "Beschleunigen und Bremsen";
            c.dwellMode = "GTFS-Stationshalte";
            c.durationMinutes = 10;
            c.animate = false;
        end
    end
end
