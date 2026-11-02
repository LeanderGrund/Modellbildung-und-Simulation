import os
import sys
from types import SimpleNamespace

import numpy as np
import matplotlib.pyplot as plt
from matplotlib.widgets import Button

# started directly as a script: make the nasch package importable, so the
# relative imports below work like inside the package
if not __package__:
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
    __package__ = 'nasch.editor'

from .randomGraph import randomGraph
from .graphToMapData import graphToMapData
from .mapFile import loadMapData, saveMapData


class MapEditor:
    """MAPEDITOR Interactive editor for roundabout road networks.

    The editable network is stored as a graph with node coordinates x and
    y and directed edges (see randomGraph). Roads may be directed or
    bidirectional. Saving also creates the flat constructor data used by
    nasch.Map.

    In a script, call plt.show() after creating the editor to keep the
    window open.
    """

    def __init__(self, G=None):
        """MAPEDITOR Open the editor, optionally with an existing graph."""

        if G is None:
            G = SimpleNamespace(x=np.empty(0), y=np.empty(0),
                                edges=np.empty((0, 2), dtype=int))

        self.G = G
        self.mode = 'addNode'
        self.vmax = 8
        self.density = 0.2
        self.brake = 0.05

        self._h = SimpleNamespace()
        self._selected = None
        self._dragging = None

        self._ensureXY()
        self._createGUI()
        self.draw()

    # --------------------------------------------------------------------
    def addNode(self, x, y):
        """ADDNODE Add one roundabout center."""

        self.G.x = np.append(self.G.x, x)
        self.G.y = np.append(self.G.y, y)
        i = self.G.x.size - 1
        self.draw()

        return i

    # --------------------------------------------------------------------
    def removeNode(self, i):
        """REMOVENODE Remove a node and all incident roads."""

        E = self.G.edges
        E = E[(E[:, 0] != i) & (E[:, 1] != i)]
        E = E - (E > i)  # renumber the remaining nodes like rmnode

        self.G.x = np.delete(self.G.x, i)
        self.G.y = np.delete(self.G.y, i)
        self.G.edges = E
        self._selected = None
        self.draw()

    # --------------------------------------------------------------------
    def addRoad(self, i, j):
        """ADDROAD Add the directed road i -> j."""

        if i != j and not self._findEdge(i, j):
            self._addEdge(i, j)

        self._selected = None
        self.draw()

    # --------------------------------------------------------------------
    def addTwoWayRoad(self, i, j):
        """ADDTWOWAYROAD Add both directions between two nodes."""

        if i != j:
            if not self._findEdge(i, j):
                self._addEdge(i, j)
            if not self._findEdge(j, i):
                self._addEdge(j, i)

        self._selected = None
        self.draw()

    # --------------------------------------------------------------------
    def removeRoad(self, i, j):
        """REMOVEROAD Remove both directions of one geometric road."""

        E = self.G.edges
        self.G.edges = E[~(((E[:, 0] == i) & (E[:, 1] == j))
                           | ((E[:, 0] == j) & (E[:, 1] == i)))]

        self.draw()

    # --------------------------------------------------------------------
    def generateRandom(self, n=10, dmin=100, dmax=300):
        """GENERATERANDOM Replace the graph by a random Delaunay network."""

        self.G = randomGraph(n, dmin, dmax)
        self._selected = None
        self._dragging = None
        self.draw()

    # --------------------------------------------------------------------
    def save(self, filename=None):
        """SAVE Save the editable graph and nasch.Map constructor data."""

        if filename is None:
            from tkinter import filedialog
            filename = filedialog.asksaveasfilename(
                title='Save NaSch map', defaultextension='.npz',
                filetypes=[('NumPy map files', '*.npz')])
            if not filename:
                return

        data = graphToMapData(self.G, self.vmax, self.density, self.brake)
        data['G'] = self.G
        saveMapData(filename, data)

    # --------------------------------------------------------------------
    def load(self, filename=None):
        """LOAD Load a graph saved by this editor."""

        if filename is None:
            from tkinter import filedialog
            filename = filedialog.askopenfilename(
                title='Load NaSch map', filetypes=[('NumPy map files', '*.npz')])
            if not filename:
                return

        data = loadMapData(filename)

        if 'G' not in data:
            raise ValueError('The file contains no editable graph.')

        self.G = data['G']

        if 'vmax' in data: self.vmax = data['vmax']
        if 'density' in data: self.density = data['density']
        if 'brake' in data: self.brake = data['brake']

        self._ensureXY()
        self._selected = None
        self._dragging = None
        self.draw()

    # --------------------------------------------------------------------
    def draw(self):
        """DRAW Redraw the editor after a topology or geometry change."""

        ax = self._h.ax

        # keep the axis limits, like cla in MATLAB
        xlim = ax.get_xlim()
        ylim = ax.get_ylim()
        ax.cla()

        x = self.G.x
        y = self.G.y
        ends = self.G.edges

        if ends.size:
            pairs = np.unique(np.sort(ends, axis=1), axis=0)

            for i, j in pairs:
                p1 = np.array([x[i], y[i]])
                d = np.array([x[j] - x[i], y[j] - y[i]])
                ax.plot([x[i], x[j]], [y[i], y[j]], linewidth=1.2, color='C0')

                if np.linalg.norm(d) > 0:
                    u = d / np.linalg.norm(d)
                    a = 0.08 * np.linalg.norm(d)

                    if self._findEdge(i, j):
                        c = p1 + 0.58 * d
                        q = c - a / 2 * u
                        self._arrow(ax, q, q + a * u)

                    if self._findEdge(j, i):
                        c = p1 + 0.42 * d
                        q = c + a / 2 * u
                        self._arrow(ax, q, q - a * u)

        ax.scatter(x, y, 70, color='C1', zorder=3)

        if self._selected is not None:
            ax.scatter(x[self._selected], y[self._selected], 160,
                       facecolors='none', edgecolors='k', linewidths=2,
                       zorder=4)

        for i in range(x.size):
            ax.text(x[i], y[i] + 20, str(i), ha='center')

        ax.set_xlim(xlim)
        ax.set_ylim(ylim)
        ax.set_aspect('equal', adjustable='box')
        ax.grid(True)
        self._updateStatus()

        self._h.fig.canvas.draw_idle()

    # ====================================================================
    # private methods
    # ====================================================================
    def _createGUI(self):
        """CREATEGUI Create the editor window and controls."""

        h = self._h
        h.fig = plt.figure('NaSch Map Editor', figsize=(10, 7))
        h.ax = h.fig.add_axes([0.05, 0.08, 0.70, 0.87])
        h.ax.set_xlim(0, 1000)
        h.ax.set_ylim(0, 1000)

        # buttons in the right panel, positions as in the MATLAB editor
        px, pw = 0.78, 0.20

        def button(y, hgt, label, callback, x=0.08, w=0.84):
            b = Button(h.fig.add_axes([px + x * pw, 0.08 + y * 0.87,
                                       w * pw, hgt * 0.87]), label)
            b.on_clicked(lambda event: callback())
            return b

        h.buttons = [
            button(0.88, 0.07, '+ Node', lambda: self._setMode('addNode')),
            button(0.79, 0.07, 'Move Node', lambda: self._setMode('moveNode')),
            button(0.70, 0.07, '- Node', lambda: self._setMode('deleteNode')),
            button(0.57, 0.07, '-> Road', lambda: self._setMode('addRoad')),
            button(0.48, 0.07, '<-> Road', lambda: self._setMode('addTwoWayRoad')),
            button(0.39, 0.07, '- Road', lambda: self._setMode('deleteRoad')),
            button(0.25, 0.08, 'Random network', self._onRandomNetwork),
            button(0.12, 0.07, 'Save', self.save, w=0.39),
            button(0.12, 0.07, 'Load', self.load, x=0.53, w=0.39),
        ]

        h.status = h.fig.text(0.05, 0.02, '', ha='left')

        c = h.fig.canvas
        c.mpl_connect('button_press_event', self._onClick)
        c.mpl_connect('motion_notify_event', self._onMouseMove)
        c.mpl_connect('button_release_event', self._onMouseUp)

    # --------------------------------------------------------------------
    def _setMode(self, mode):
        self.mode = mode
        self._selected = None
        self._dragging = None
        self.draw()

    # --------------------------------------------------------------------
    def _onClick(self, event):
        if event.inaxes is not self._h.ax or event.xdata is None:
            return

        # ignore clicks while zooming or panning with the toolbar
        toolbar = self._h.fig.canvas.toolbar
        if toolbar is not None and toolbar.mode:
            return

        x = event.xdata
        y = event.ydata

        if self.mode == 'addNode':
            self.addNode(x, y)
        elif self.mode == 'moveNode':
            self._dragging = self._findNode(x, y)
            self._selected = self._dragging
            self.draw()
        elif self.mode == 'deleteNode':
            i = self._findNode(x, y)
            if i is not None: self.removeNode(i)
        elif self.mode == 'addRoad':
            i = self._findNode(x, y)
            if i is not None: self._selectRoadEndpoint(i, False)
        elif self.mode == 'addTwoWayRoad':
            i = self._findNode(x, y)
            if i is not None: self._selectRoadEndpoint(i, True)
        elif self.mode == 'deleteRoad':
            i, j = self._findRoad(x, y)
            if i is not None: self.removeRoad(i, j)

    # --------------------------------------------------------------------
    def _onMouseMove(self, event):
        if self._dragging is None or event.inaxes is not self._h.ax:
            return
        self.G.x[self._dragging] = event.xdata
        self.G.y[self._dragging] = event.ydata
        self.draw()

    # --------------------------------------------------------------------
    def _onMouseUp(self, event):
        self._dragging = None
        self._selected = None

    # --------------------------------------------------------------------
    def _onRandomNetwork(self):
        a = _inputdlg(['Number of nodes', 'Minimum distance',
                       'Maximum distance'], 'Random network',
                      ['10', '100', '300'])
        if a is None:
            return
        v = [float(s) for s in a]
        self.generateRandom(int(v[0]), v[1], v[2])

    # --------------------------------------------------------------------
    def _selectRoadEndpoint(self, i, twoWay):
        if self._selected is None:
            self._selected = i
            self.draw()
            return

        j = i
        i = self._selected

        if twoWay:
            self.addTwoWayRoad(i, j)
        else:
            self.addRoad(i, j)

    # --------------------------------------------------------------------
    def _findNode(self, x, y):
        if self.G.x.size == 0:
            return None

        d = np.hypot(self.G.x - x, self.G.y - y)
        i = int(np.argmin(d))
        scale = self._scale()
        if d[i] > 0.035 * scale:
            return None

        return i

    # --------------------------------------------------------------------
    def _findRoad(self, x, y):
        i = None
        j = None

        if self.G.edges.size == 0:
            return i, j

        pairs = np.unique(np.sort(self.G.edges, axis=1), axis=0)
        best = np.inf
        p = np.array([x, y])

        for a, b in pairs:
            p1 = np.array([self.G.x[a], self.G.y[a]])
            d = np.array([self.G.x[b] - p1[0], self.G.y[b] - p1[1]])
            dd = np.dot(d, d)
            if dd == 0:
                dist = np.linalg.norm(p - p1)
            else:
                s = min(1, max(0, np.dot(p - p1, d) / dd))
                dist = np.linalg.norm(p - (p1 + s * d))

            if dist < best:
                best = dist
                i = int(a)
                j = int(b)

        if best > 0.025 * self._scale():
            i = None
            j = None

        return i, j

    # --------------------------------------------------------------------
    def _scale(self):
        ax = self._h.ax
        return max(np.diff(ax.get_xlim())[0], np.diff(ax.get_ylim())[0])

    # --------------------------------------------------------------------
    def _findEdge(self, i, j):
        E = self.G.edges
        return bool(np.any((E[:, 0] == i) & (E[:, 1] == j)))

    # --------------------------------------------------------------------
    def _addEdge(self, i, j):
        self.G.edges = np.vstack([self.G.edges, [i, j]]).astype(int)

    # --------------------------------------------------------------------
    @staticmethod
    def _arrow(ax, p, q):
        ax.annotate('', xy=q, xytext=p,
                    arrowprops=dict(arrowstyle='-|>', color='C0', lw=1.2,
                                    mutation_scale=15, shrinkA=0, shrinkB=0))

    # --------------------------------------------------------------------
    def _ensureXY(self):
        n = int(np.max(self.G.edges)) + 1 if np.size(self.G.edges) else 0
        n = max(n, np.size(getattr(self.G, 'x', [])),
                np.size(getattr(self.G, 'y', [])))

        if getattr(self.G, 'x', None) is None or np.size(self.G.x) != n:
            self.G.x = np.zeros(n)
        if getattr(self.G, 'y', None) is None or np.size(self.G.y) != n:
            self.G.y = np.zeros(n)

        self.G.x = np.asarray(self.G.x, dtype=float)
        self.G.y = np.asarray(self.G.y, dtype=float)
        self.G.edges = np.asarray(self.G.edges, dtype=int).reshape(-1, 2)

    # --------------------------------------------------------------------
    def _updateStatus(self):
        text = {
            'addNode': 'Add node: click a position.',
            'moveNode': 'Move node: drag a node.',
            'deleteNode': 'Delete node: click a node.',
            'addRoad': 'Add road: click start and end node.',
            'addTwoWayRoad': 'Add two-way road: click both nodes.',
            'deleteRoad': 'Delete road: click the road.',
        }[self.mode]
        self._h.status.set_text(text)


# ------------------------------------------------------------------------
def _inputdlg(prompts, title, defaults):
    # ask for several values, like inputdlg in MATLAB; None if cancelled
    import tkinter as tk
    from tkinter import simpledialog

    root = tk.Tk()
    root.withdraw()
    values = []

    try:
        for prompt, default in zip(prompts, defaults):
            s = simpledialog.askstring(title, prompt, initialvalue=default,
                                       parent=root)
            if s is None:
                return None
            values.append(s)
    finally:
        root.destroy()

    return values


if __name__ == '__main__':
    MapEditor()
    plt.show()
