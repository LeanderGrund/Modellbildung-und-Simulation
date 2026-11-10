function h = plotSnapshot(p)
%PLOTSNAPSHOT Geografischen Endzustand auch ohne Animation darstellen.
handles = drawState(p.state,p,[]);
h = handles.fig;
end
