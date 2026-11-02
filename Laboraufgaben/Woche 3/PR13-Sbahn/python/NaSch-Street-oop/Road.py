import os
import sys
from types import SimpleNamespace

import numpy as np
import matplotlib as mpl
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap

# the parula color table lives in the shared plotter library
sys.path.insert(0, os.path.join(
    os.path.dirname(__file__), '..', '..', '..', '..', 'tools'))
import plotter

# the road is drawn with matplotlib, the plotter library only supports
# black and white images and cannot draw the scattered vehicles.
# In a notebook the figure is redisplayed in place, like plotter does.


class Road:
    """ROAD Periodic Nagel-Schreckenberg road with elliptical visualization.

    u stores the velocity in the real part and the vehicle ID in the
    imaginary part; NaN denotes an empty cell. G stores the complete
    time-space history.

    The procedural version in NaSch-Street maps directly onto this class:
      myInit        -> Road(...)
      myUpdate      -> road.update()
      myDrawnow     -> road.draw()
      time history  -> road.G
      TimeSpacePlot -> road.plotTimeSpace()
    """

    def __init__(self, n=200, density=0.2, vmax=8, brake=0.05, plot=1,
                 colormap=None, ratio=0.5):
        """ROAD Initialize one periodic road."""

        n = int(n)
        if n <= 0:
            raise ValueError('n must be a positive integer')

        if not 0 <= density <= 1:
            raise ValueError('density must be in [0,1]')

        vmax = int(vmax)
        if vmax <= 0:
            raise ValueError('vmax must be a positive integer')

        if not 0 <= brake <= 1:
            raise ValueError('brake must be in [0,1]')

        plot = int(plot)
        if not 0 <= plot <= 2:
            raise ValueError('plot must be in [0,2]')

        if ratio <= 0:
            raise ValueError('ratio must be positive')

        self.vmax = vmax
        self.brake = brake
        self.plot = plot
        self.t = 1
        self.ratio = ratio

        # distribute vehicles randomly and assign unique vehicle IDs
        m = int(round(density * n))
        self.u = np.full(n, np.nan + 0j)
        self.u[np.random.permutation(n)[:m]] = 1j * np.arange(1, m + 1)

        # color represents the velocity (plot 1) or the vehicle ID (plot 2)
        if colormap is None or len(colormap) == 0:
            if self.plot == 1:
                self.colormap = jet(self.vmax + 1)[::-1]
            else:
                self.colormap = parula(max(1, m))
        else:
            self.colormap = np.asarray(colormap, dtype=float)

        # time-space history, one row per time step
        self.G = [self.u.copy()]

        # graphics objects, created by the first call of draw
        self._h = None


    # --------------------------------------------------------------------
    def update(self):
        """UPDATE Advance the periodic road by exactly one model step."""

        xcar = np.flatnonzero(~np.isnan(self.u))

        if xcar.size:
            v = self.u[xcar].real
            id = self.u[xcar].imag
            n = self.u.size

            # Free cells in front, including the periodic boundary.
            d = np.append(np.diff(xcar) - 1, xcar[0] + n - xcar[-1] - 1)

            # Nagel-Schreckenberg update.
            v = np.minimum(self.vmax, v + 1)
            v = np.minimum(d, v)
            v = np.maximum(0, v - (np.random.rand(v.size) < self.brake))

            # Move vehicles and wrap around periodically.
            xcar = np.mod(xcar + v, n).astype(int)

            self.u[:] = np.nan
            self.u[xcar] = v + 1j * id

        self.t = self.t + 1
        self.G.append(self.u.copy())

    # --------------------------------------------------------------------
    def draw(self, ax=None):
        """DRAW Draw or update the periodic road as an ellipse.

        Graphics are created on the first call. Later calls update only
        the vehicle positions and colors.
        """

        if not self.plot:
            return

        if ax is None:
            ax = plt.gca()

        initialized = (self._h is not None and self._h.ax is ax
                       and plt.fignum_exists(ax.figure.number))

        if not initialized:
            phi = np.linspace(0, 2 * np.pi, 300)

            self._h = SimpleNamespace()
            self._h.ax = ax
            self._h.notebook = plotter.check_is_notebook()
            self._h.display = None
            if not self._h.notebook:
                plt.ion()  # do not block the caller of draw

            self._h.street, = ax.plot(np.cos(phi), self.ratio * np.sin(phi),
                                      linewidth=2)
            self._h.cars = ax.scatter(np.empty(0), np.empty(0))
            self._h.title = ax.set_title('')

            ax.set_xlim(-1.1, 1.1)
            ax.set_ylim(-1.1 * self.ratio, 1.1 * self.ratio)
            ax.set_aspect('equal')
            ax.set_axis_off()

        pos = np.flatnonzero(~np.isnan(self.u))
        phi = 2 * np.pi * pos / self.u.size

        if self.plot == 1:
            colind = self.u[pos].real.astype(int)
        else:
            colind = self.u[pos].imag.astype(int) - 1

        self._h.cars.set_offsets(
            np.column_stack([np.cos(phi), self.ratio * np.sin(phi)])
            if pos.size else np.empty((0, 2)))
        self._h.cars.set_facecolor(
            self.colormap[colind] if pos.size else np.empty((0, 3)))
        self._h.title.set_text(f'road at timestep = {self.t}')

        show(self._h)

    # --------------------------------------------------------------------
    def plotTimeSpace(self, ax=None):
        """PLOTTIMESPACE Plot the time-space history."""

        if not self.plot:
            return

        if ax is None:
            ax = plt.gca()

        G = np.array(self.G)

        # the first color is the white background of an empty cell
        col = np.vstack([[1, 1, 1], self.colormap])

        if self.plot == 1:
            ind = G.real + 1
        else:
            ind = G.imag  # empty cells carry the ID 0

        ax.imshow(np.ma.masked_invalid(ind), cmap=ListedColormap(col),
                  vmin=-0.5, vmax=col.shape[0] - 0.5,
                  interpolation='nearest', aspect='auto')
        ax.set_axis_off()


# ------------------------------------------------------------------------
def jet(m):
    # m equidistant colors of the jet colormap, as an (m,3) array
    return mpl.colormaps['jet'](np.linspace(0, 1, m))[:, :3]


# ------------------------------------------------------------------------
def parula(m):
    # m equidistant colors of the MATLAB parula colormap, as an (m,3) array
    return plotter.interp_cmap(plotter.parula, m) / 255.0


# ------------------------------------------------------------------------
def show(h):
    # show the current state of the figure without blocking the caller

    if h.notebook:
        # the inline backend draws nothing before the cell is finished, so
        # the figure is displayed once and then updated in place
        from IPython.display import display

        if h.display is None:
            h.display = display(h.ax.figure, display_id=True)
        else:
            h.display.update(h.ax.figure)
    else:
        h.ax.figure.canvas.draw_idle()
        h.ax.figure.canvas.flush_events()
