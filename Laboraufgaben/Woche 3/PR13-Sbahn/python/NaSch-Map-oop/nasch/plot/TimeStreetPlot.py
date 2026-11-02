import numpy as np
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap

from ..helpers import parula


def TimeStreetPlot(road, ax=None, colormapID=None):
    """TIMESTREETPLOT Plot the time-space history of one Road object."""

    if not road.plot:
        return
    if ax is None:
        ax = plt.gca()

    G = np.array(road.G)

    if road.plot == 1:
        col = np.vstack([[1, 1, 1], road.colormap])
        ind = G.real + 1
    else:
        if colormapID is None or len(colormapID) == 0:
            maxID = int(np.max(G.imag, initial=1))
            if road.colormap.shape[0] >= maxID:
                colormapID = road.colormap
            else:
                colormapID = parula(maxID)

        col = np.vstack([[1, 1, 1], colormapID])
        ind = G.imag  # empty cells carry the ID 0

    # the first color is the white background of an empty cell
    ax.imshow(np.ma.masked_invalid(ind), cmap=ListedColormap(col),
              vmin=-0.5, vmax=col.shape[0] - 0.5,
              interpolation='nearest', aspect='auto')
    ax.set_axis_off()
