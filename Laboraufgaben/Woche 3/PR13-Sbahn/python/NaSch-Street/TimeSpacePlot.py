import warnings
from types import SimpleNamespace

import numpy as np
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap

from myDrawnow import jet, parula


def TimeSpacePlot(G, p):
    """TIMESPACEPLOT Plot the space-time evolution of the NaSch traffic model.

    G contains the street state at successive time steps:
      rows    : time steps
      columns : street cells

    The state is stored as a complex-valued matrix:
      NaN     : empty cell
      G.real  : vehicle velocity
      G.imag  : vehicle ID

    Depending on p.plot, the space-time diagram is colored by
      1 : vehicle velocity
      2 : vehicle ID

    The average vehicle velocity is shown in a second plot.
    """

    if not p.plot:
        return None

    # evaluate simulation data -------------------------------------------

    G = np.asarray(G)
    nt = G.shape[0]

    v = G.real
    id = G.imag

    # average velocity at each time step
    with warnings.catch_warnings():
        warnings.simplefilter('ignore', RuntimeWarning)  # rows without vehicles
        vmean = np.nanmean(v, axis=1)

    # plot ---------------------------------------------------------------

    h = SimpleNamespace()
    h.fig = plt.figure(layout='constrained')
    gs = h.fig.add_gridspec(1, 4)

    # space-time diagram
    h.ax1 = h.fig.add_subplot(gs[0, 0:3])

    # colormap, the first color is the white background of an empty cell
    if p.plot == 1:  # color represents velocity
        col = np.vstack([[1, 1, 1], jet(p.vmax + 1)[::-1]])
        colind = v + 1

    else:  # color represents vehicle ID
        maxID = int(max(1, np.nanmax(id, initial=0)))
        col = np.vstack([[1, 1, 1], parula(maxID)])
        colind = id  # empty cells carry the ID 0

    h.im = h.ax1.imshow(np.ma.masked_invalid(colind),
                        cmap=ListedColormap(col),
                        vmin=-0.5, vmax=col.shape[0] - 0.5,
                        interpolation='nearest', aspect='auto')

    # velocity colorbar
    if p.plot == 1:
        c = h.fig.colorbar(h.im, ax=h.ax1, ticks=np.arange(1, p.vmax + 2))
        c.ax.set_yticklabels([str(k) for k in range(p.vmax + 1)])
        c.set_label('velocity')

    h.ax1.grid(True)
    h.ax1.set_title('street occupation')
    h.ax1.set_xlabel(r'place  $\rightarrow$')
    h.ax1.set_ylabel(r'$\leftarrow$  time')

    # trajectory of vehicle with ID 1
    tt, xx = np.nonzero(id == 1)
    h.ax1.plot(xx, tt, 'o', color='k', markersize=5, markerfacecolor='none')

    # average velocity ---------------------------------------------------

    # identical time axes, the image already points the time axis downwards
    h.ax2 = h.fig.add_subplot(gs[0, 3], sharey=h.ax1)

    h.ax2.plot(vmean, np.arange(nt))
    h.ax2.set_title('average velocity')
    h.ax2.set_xlabel(r'velocity  $\rightarrow$')
    h.ax2.set_ylabel(r'$\leftarrow$  time')
    h.ax2.grid(True)

    return h
