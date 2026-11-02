import os
import sys

import numpy as np
import matplotlib as mpl

# the parula color table lives in the shared plotter library
sys.path.insert(0, os.path.join(
    os.path.dirname(__file__), '..', '..', '..', '..', '..', 'tools'))
import plotter

# the roads are drawn with matplotlib, the plotter library only supports
# black and white images and cannot draw the scattered vehicles.
# In a notebook the figure is redisplayed in place, like plotter does.


# ------------------------------------------------------------------------
def jet(m):
    # m equidistant colors of the jet colormap, as an (m,3) array
    return mpl.colormaps['jet'](np.linspace(0, 1, m))[:, :3]


# ------------------------------------------------------------------------
def parula(m):
    # m equidistant colors of the MATLAB parula colormap, as an (m,3) array
    return plotter.interp_cmap(plotter.parula, m) / 255.0


# ------------------------------------------------------------------------
def isNotebook():
    # True if the code runs inside a Jupyter notebook
    return plotter.check_is_notebook()


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
