from types import SimpleNamespace

import numpy as np
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap

from .helpers import jet, parula, isNotebook, show


class Road:
    """ROAD Non-periodic Nagel-Schreckenberg road.

    u stores velocity in the real part and a global vehicle ID in the
    imaginary part; NaN denotes an empty cell. temp is the temporary
    continuation beyond the road end used by network nodes.
    """

    def __init__(self, n=200, density=0.2, vmax=8, brake=0.05, plot=1,
                 colormap=None, x=(0, 1), y=(0, 0)):
        """ROAD Initialize one non-periodic road."""

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

        x = np.asarray(x, dtype=float)
        y = np.asarray(y, dtype=float)
        if x.shape != (2,) or y.shape != (2,):
            raise ValueError('x and y must contain two values')

        self.vmax = vmax
        self.brake = brake
        self.plot = plot
        self.t = 1
        self.x = x
        self.y = y

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

        # time-space history, one row per saved time step
        self.G = []
        self.temp = np.empty(0, dtype=complex)

        # graphics objects, created by the first call of draw
        self._h = None

    # --------------------------------------------------------------------
    def update(self):
        """UPDATE Advance the road by exactly one model step."""

        xcar = np.flatnonzero(~np.isnan(self.u))
        v = self.u[xcar].real
        id = self.u[xcar].imag
        n = self.u.size

        if xcar.size:
            d = np.append(np.diff(xcar) - 1, n - 1 - xcar[-1] + self.temp.size)
            v = np.minimum(self.vmax, v + 1)
            v = np.minimum(d, v)
            v = np.maximum(0, v - (np.random.rand(v.size) < self.brake))
            xcar = (xcar + v).astype(int)
            value = v + 1j * id

            self.u[:] = np.nan
            self.temp[:] = np.nan

            inside = xcar < n
            self.u[xcar[inside]] = value[inside]

            q = xcar[~inside] - n
            self.temp[q] = value[~inside]
        else:
            self.temp[:] = np.nan

        self.t = self.t + 1

    # --------------------------------------------------------------------
    def save(self):
        """SAVE Append the current state to the time-space history."""

        self.G.append(self.u.copy())

    # --------------------------------------------------------------------
    def draw(self, ax=None):
        """DRAW Draw or update the road.

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
            self._h = SimpleNamespace()
            self._h.ax = ax
            self._h.notebook = isNotebook()
            self._h.display = None
            if not self._h.notebook:
                plt.ion()  # do not block the caller of draw

            self._h.street = ax.quiver(
                self.x[0], self.y[0], np.diff(self.x), np.diff(self.y),
                angles='xy', scale_units='xy', scale=1, color='C0')
            self._h.cars = ax.scatter(np.empty(0), np.empty(0))

            # quiver only registers its base point, so add the road end
            ax.update_datalim(np.column_stack([self.x, self.y]))
            ax.autoscale_view()

        pos = np.flatnonzero(~np.isnan(self.u))
        alpha = (pos + 1) / self.u.size

        if self.plot == 1:
            colind = self.u[pos].real.astype(int)
        else:
            colind = self.u[pos].imag.astype(int) - 1

        self._h.cars.set_offsets(
            np.column_stack([self.x[0] + alpha * np.diff(self.x),
                             self.y[0] + alpha * np.diff(self.y)])
            if pos.size else np.empty((0, 2)))
        self._h.cars.set_facecolor(
            self.colormap[colind] if pos.size else np.empty((0, 3)))

        show(self._h)

    # --------------------------------------------------------------------
    def plotTimeSpace(self, ax=None): # ??
        """PLOTTIMESPACE Plot the saved time-space history."""

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
