import os
import sys
from types import SimpleNamespace

import numpy as np
import matplotlib as mpl
import matplotlib.pyplot as plt

# the parula color table lives in the shared plotter library
sys.path.insert(0, os.path.join(
    os.path.dirname(__file__), '..', '..', '..', '..', 'tools'))
import plotter

# the street is drawn with matplotlib, the plotter library only supports
# black and white images and cannot draw the scattered vehicles.
# In a notebook the figure is redisplayed in place, like plotter does.


def myDrawnow(u, p, t=None, h=None):
    """MYDRAWNOW Visualize the current state of the NaSch traffic model.

    The street state is stored as a complex-valued vector:
      NaN     : empty cell
      u.real  : vehicle velocity
      u.imag  : vehicle ID

    On the first call, the function creates the visualization and returns
    its graphics handles in h. On subsequent calls, the existing graphics
    objects are updated.
    """

    if not p.plot:
        return h

    n = u.size
    ratio = 0.2  # plot ratio height vs width

    # vehicle positions, velocities, and IDs
    x = np.flatnonzero(~np.isnan(u))
    v = u[x].real
    id = u[x].imag

    # select colors ------------------------------------------------------
    if p.plot == 1:
        col = jet(p.vmax + 1)[::-1]
        colind = v.astype(int)
    else:
        maxID = int(max(1, id.max(initial=0)))

        if h is None or h.colormap.shape[0] < maxID:
            col = parula(maxID)
        else:
            col = h.colormap

        colind = id.astype(int) - 1

    if h is None:
        # initialize visualization ---------------------------------------

        h = SimpleNamespace()
        h.notebook = plotter.check_is_notebook()
        h.display = None
        if not h.notebook:
            plt.ion()  # do not block the caller of drawnow
        h.fig = plt.figure()
        h.ax = h.fig.add_subplot(1, 1, 1)
        h.ratio = ratio
        h.colormap = col

        # street
        phi = np.linspace(0, 2 * np.pi, 100)
        h.street, = h.ax.plot(np.cos(phi), ratio * np.sin(phi))

        # driving direction
        ell = 0.5
        h.direction = h.ax.quiver(-ell / 2, -1.1 * ratio, ell, 0,
                                  angles='xy', scale_units='xy', scale=1,
                                  color='k')

        # vehicles
        phi = 2 * np.pi * x / n
        h.cars = h.ax.scatter(np.cos(phi), ratio * np.sin(phi),
                              c=col[colind] if x.size else np.empty((0, 3)))

        # track the first available vehicle
        h.track, = h.ax.plot([], [], 'o', color='k', markersize=10,
                             markerfacecolor='none')
        if id.size == 0:
            h.trackID = None
            h.track.set_visible(False)
        else:
            h.trackID = id[0]
            h.track.set_data([np.cos(phi[0])], [ratio * np.sin(phi[0])])

        h.ax.set_xlim(-1.05, 1.05)
        h.ax.set_ylim(-1.2 * ratio, 1.15 * ratio)
        h.ax.set_aspect('equal')
        h.ax.set_axis_off()

    else:
        # update visualization -------------------------------------------

        h.colormap = col
        phi = 2 * np.pi * x / n

        # vehicles
        xx = np.cos(phi)
        yy = ratio * np.sin(phi)
        h.cars.set_offsets(np.column_stack([xx, yy]) if x.size
                           else np.empty((0, 2)))
        h.cars.set_facecolor(col[colind] if x.size else np.empty((0, 3)))

        # tracked vehicle
        ind = np.flatnonzero(id == h.trackID)
        ind = ind[0] if ind.size else None

        # if the tracked vehicle was deleted, track the first available one
        if ind is None and id.size:
            h.trackID = id[0]
            ind = 0

        if ind is None:
            # no vehicles available
            h.trackID = None
            h.track.set_visible(False)
        else:
            h.track.set_data([xx[ind]], [yy[ind]])
            h.track.set_visible(True)

    h.ax.set_title(f'grid at timestep = {t}')
    show(h)

    return h


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
            h.display = display(h.fig, display_id=True)
        else:
            h.display.update(h.fig)
    else:
        h.fig.canvas.draw_idle()
        h.fig.canvas.flush_events()


# ------------------------------------------------------------------------
def isgraphics(h):
    # true as long as the figure window of h is still open
    return h is not None and plt.fignum_exists(h.fig.number)
