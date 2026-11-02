from types import SimpleNamespace

import numpy as np
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap

from .Road import Road
from .helpers import parula, isNotebook, show
from . import node
from .editor import randomGraph, graphToMapData, loadMapData


class Map:
    """MAP Nagel-Schreckenberg road network.

    Roads are connected by Source, Sink, Connector, Diverge, and Merge
    nodes inferred from node1 and node2. One call to update advances the
    complete network by exactly one model step.

    Node and road indices are 0-based.
    """

    def __init__(self, file=None, struct=None, node1=None, node2=None,
                 nodex=None, nodey=None, times=None, density=None,
                 vmax=None, brake=None, plot=None, colormap=None):
        """MAP Construct, load, or randomly generate a road network.

        map = nasch.Map()
        map = nasch.Map(file='network.npz')
        map = nasch.Map(struct=data)
        map = nasch.Map(node1=node1, node2=node2, nodex=x, nodey=y)

        Explicit keyword arguments override values loaded from file
        or struct.
        """

        data = dict(node1=None, node2=None, nodex=None, nodey=None,
                    times=None, density=0.2, vmax=8, brake=0.05, plot=1,
                    colormap=None)

        if file:
            loaded = loadMapData(file)
        elif struct:
            loaded = struct
        else:
            loaded = {}

        data.update(loaded)

        explicit = dict(node1=node1, node2=node2, nodex=nodex, nodey=nodey,
                        times=times, density=density, vmax=vmax,
                        brake=brake, plot=plot, colormap=colormap)
        for name, value in explicit.items():
            if value is not None and np.size(value) > 0:
                data[name] = value

        if data['node1'] is None or np.size(data['node1']) == 0:
            G = randomGraph()
            generated = graphToMapData(G, data['vmax'], data['density'],
                                       data['brake'])
            for name in ('node1', 'node2', 'nodex', 'nodey', 'times'):
                data[name] = generated[name]

        node1 = np.atleast_1d(np.asarray(data['node1'])).astype(int)
        node2 = np.atleast_1d(np.asarray(data['node2'])).astype(int)
        nodex = np.atleast_1d(np.asarray(data['nodex'], dtype=float))
        nodey = np.atleast_1d(np.asarray(data['nodey'], dtype=float))
        nroad = node1.size
        nnode = nodex.size

        if node2.size != nroad or nodey.size != nnode:
            raise ValueError('Inconsistent network dimensions.')

        used = np.unique(np.concatenate([node1, node2]))
        if not np.array_equal(used, np.arange(nnode)):
            raise ValueError('Node indices must be consecutive integers '
                             'from 0 to len(nodex)-1.')

        if data['times'] is None or np.size(data['times']) == 0:
            data['times'] = np.zeros(nroad)
        elif np.size(data['times']) != nroad:
            raise ValueError('times must contain one value for every road.')

        self.node1 = node1
        self.node2 = node2
        self.nodex = nodex
        self.nodey = nodey
        self.times = np.atleast_1d(np.asarray(data['times'])).astype(int)
        self.plot = int(data['plot'])
        self.t = 1
        self.leave = 0

        self.roads = []
        nextID = 1

        for k in range(nroad):
            a = node1[k]
            b = node2[k]
            len_ = max(1, int(round(np.hypot(nodex[b] - nodex[a],
                                              nodey[b] - nodey[a]))))
            road = Road(n=len_, density=data['density'], vmax=data['vmax'],
                        brake=data['brake'], plot=data['plot'],
                        colormap=data['colormap'],
                        x=[nodex[a], nodex[b]], y=[nodey[a], nodey[b]])

            # replace the local vehicle IDs by global ones
            pos = np.flatnonzero(~np.isnan(road.u))
            m = pos.size
            road.u[pos] = road.u[pos].real + 1j * np.arange(nextID, nextID + m)
            nextID = nextID + m
            road.save()
            self.roads.append(road)

        self.nextID = nextID

        if self.plot == 2 and (data['colormap'] is None
                               or len(data['colormap']) == 0):
            col = parula(max(1, nextID - 1))
            for road in self.roads:
                road.colormap = col

        # infer the node type from the number of incoming and outgoing roads
        self.nodes = [None] * nnode

        for k in range(nnode):
            inIndex = np.flatnonzero(node2 == k)
            outIndex = np.flatnonzero(node1 == k)
            inp = [self.roads[i] for i in inIndex]
            out = [self.roads[i] for i in outIndex]

            if len(inp) == 0 and len(out) == 1:
                self.nodes[k] = node.Source(out[0], self.times[outIndex[0]])
            elif len(inp) == 1 and len(out) == 0:
                self.nodes[k] = node.Sink(inp[0], self.times[inIndex[0]])
            elif len(inp) == 1 and len(out) == 1:
                self.nodes[k] = node.Connector(inp[0], out[0])
            elif len(inp) == 1:
                self.nodes[k] = node.Diverge(inp[0], out)
            elif len(out) == 1:
                self.nodes[k] = node.Merge(inp, out[0])
            else:
                raise ValueError(f'Node {k} has unsupported MIMO topology.')

        # graphics objects, created by the first call of draw
        self._h = None

    # --------------------------------------------------------------------
    def update(self):
        """UPDATE Advance the complete network by exactly one model step.

        The phases are executed sequentially for the whole network:
        prepare nodes, update roads, transfer vehicles, save states.
        """

        self.t = self.t + 1

        for n in self.nodes:
            n.prepare(self)

        for road in self.roads:
            road.update()

        for n in self.nodes:
            n.transfer(self)

        for road in self.roads:
            road.save()

    # --------------------------------------------------------------------
    def draw(self, ax=None):
        """DRAW Draw or update the road network.

        The graphics objects are created on the first call. Later calls
        update only vehicle positions, colors, and the time label.
        """

        if not self.plot:
            return

        if ax is None:
            ax = plt.gca()

        initialized = (self._h is not None and self._h.ax is ax
                       and plt.fignum_exists(ax.figure.number))

        if not initialized:
            ax.cla()

            xroad = np.array([road.x[0] for road in self.roads])
            yroad = np.array([road.y[0] for road in self.roads])
            dx = np.array([np.diff(road.x)[0] for road in self.roads])
            dy = np.array([np.diff(road.y)[0] for road in self.roads])

            self._h = SimpleNamespace()
            self._h.ax = ax
            self._h.notebook = isNotebook()
            self._h.display = None
            if not self._h.notebook:
                plt.ion()  # do not block the caller of draw

            self._h.street = ax.quiver(xroad, yroad, dx, dy, angles='xy',
                                       scale_units='xy', scale=1,
                                       color='C0', width=0.002, minlength=0)
            self._h.colormap = self.roads[0].colormap
            ncol = max(2, self._h.colormap.shape[0])
            self._h.cars = ax.scatter(np.empty(0), np.empty(0),
                                      c=np.empty(0),
                                      cmap=ListedColormap(self._h.colormap),
                                      vmin=0.5, vmax=ncol + 0.5, zorder=3)
            self._h.title = ax.set_title('')

            # quiver only registers its base points, so add the road ends
            ax.update_datalim(np.column_stack([
                np.append(xroad, xroad + dx), np.append(yroad, yroad + dy)]))
            ax.autoscale_view()
            ax.set_aspect('equal')
            ax.set_axis_off()

        x = []
        y = []
        c = []

        for road in self.roads:
            pos = np.flatnonzero(~np.isnan(road.u))

            if pos.size == 0:
                continue

            alpha = (pos + 1) / road.u.size
            x.append(road.x[0] + alpha * np.diff(road.x))
            y.append(road.y[0] + alpha * np.diff(road.y))

            if self.plot == 1:
                c.append(road.u[pos].real + 1)
            else:
                c.append(road.u[pos].imag)

        x = np.concatenate(x) if x else np.empty(0)
        y = np.concatenate(y) if y else np.empty(0)
        c = np.concatenate(c) if c else np.empty(0)

        # new vehicles from sources need additional ID colors
        if self.plot == 2 and self.nextID - 1 > self._h.colormap.shape[0]:
            ncol = max(1, self.nextID - 1)
            self._h.colormap = parula(ncol)
            for road in self.roads:
                road.colormap = self._h.colormap
            self._h.cars.set_cmap(ListedColormap(self._h.colormap))
            self._h.cars.set_clim(0.5, ncol + 0.5)

        self._h.cars.set_offsets(np.column_stack([x, y]))
        self._h.cars.set_array(c)
        self._h.title.set_text(f'road network at timestep = {self.t}')

        show(self._h)
