import warnings

import numpy as np
import matplotlib.pyplot as plt

from ..helpers import parula
from .TimeStreetPlot import TimeStreetPlot


def TimeMapPlot(map, *args):
    """TIMEMAPPLOT Plot selected results of a Map object.

    Optional inputs:
      'map'  : road-network topology
      'avg'  : mean velocity on all roads
      [0, 2] : time-space histories of selected roads (0-based indices)

    Returns the figure, or None if nothing is plotted.
    """

    if not map.plot:
        return None

    nroad = len(map.roads)
    showMap = False
    showAvg = False
    roads = []

    for arg in args:
        if isinstance(arg, str):
            if arg.lower() == 'map':
                showMap = True
            elif arg.lower() == 'avg':
                showAvg = True
            else:
                raise ValueError(f'Unknown option "{arg}".')
        elif np.ndim(arg) <= 1 and np.issubdtype(np.asarray(arg).dtype, np.number):
            roads = list(np.atleast_1d(arg))
        else:
            raise ValueError('Optional inputs must be "map", "avg", or road indices.')

    if any(k < 0 or k >= nroad or k != int(k) for k in roads):
        raise ValueError(f'Road indices must be integers between 0 and {nroad - 1}.')
    roads = [int(k) for k in roads]

    if not showMap and not showAvg and not roads:
        return None

    # Use one common ID colormap for all roads.
    colormapID = None
    if map.plot == 2:
        maxID = 1
        for road in map.roads:
            maxID = max(maxID, int(np.max(np.array(road.G).imag, initial=1)))

        if map.roads[0].colormap.shape[0] >= maxID:
            colormapID = map.roads[0].colormap
        else:
            colormapID = parula(maxID)

    fig = plt.gcf()
    fig.clf()

    # flow layout: a nearly square grid of tiles
    ntile = showMap + showAvg + len(roads)
    ncol = int(np.ceil(np.sqrt(ntile)))
    nrow = int(np.ceil(ntile / ncol))
    axes = fig.subplots(nrow, ncol, squeeze=False).ravel()
    for ax in axes[ntile:]:
        ax.remove()
    tiles = iter(axes)

    if showMap:
        ax = next(tiles)
        for k in range(nroad):
            a = map.node1[k]
            b = map.node2[k]
            p = np.array([map.nodex[a], map.nodey[a]])
            q = np.array([map.nodex[b], map.nodey[b]])
            ax.annotate('', xy=q, xytext=p,
                        arrowprops=dict(arrowstyle='-|>', color='C0', lw=2,
                                        shrinkA=0, shrinkB=0))
            m = (p + q) / 2
            ax.text(m[0], m[1], str(k), ha='center', va='center')
        ax.scatter(map.nodex, map.nodey, 10, color='C0')
        ax.set_aspect('equal')
        ax.set_axis_off()
        ax.set_title('road network')

    if showAvg:
        ax = next(tiles)
        for k, road in enumerate(map.roads):
            with warnings.catch_warnings():
                warnings.simplefilter('ignore', RuntimeWarning)  # empty rows
                vmean = np.nanmean(np.array(road.G).real, axis=1)
            ax.plot(np.arange(1, vmean.size + 1), vmean, label=f'road {k}')
        ax.grid(True)
        ax.set_title('average velocity')
        ax.set_xlabel('time')
        ax.set_ylabel('velocity')
        ax.legend(loc='best')

    for k in roads:
        ax = next(tiles)
        TimeStreetPlot(map.roads[k], ax, colormapID)
        ax.set_title(f'road {k}')

    with warnings.catch_warnings():
        warnings.simplefilter('ignore', UserWarning)  # long legends
        fig.tight_layout()

    return fig
