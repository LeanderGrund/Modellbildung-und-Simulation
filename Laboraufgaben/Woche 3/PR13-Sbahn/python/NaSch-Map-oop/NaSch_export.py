import numpy as np
import matplotlib.pyplot as plt
from matplotlib.collections import PolyCollection
from matplotlib.image import AxesImage
from matplotlib.text import Text

import nasch


def NaSch_export():
    """NASCH_EXPORT Simulate the NaSch model and export vector PDFs."""

    # simulation
    n = 4
    node1 = np.arange(n)
    node2 = np.roll(node1, -1)
    times = np.zeros(n)
    phi = 2 * np.pi * np.arange(n) / n
    nodex = 50 * np.cos(phi)
    nodey = 50 * np.sin(phi)

    map = nasch.Map(node1=node1, node2=node2, nodex=nodex, nodey=nodey,
                    times=times)

    fig = plt.figure()
    map.draw()

    for k in range(2, 101):
        map.update()
        map.draw()

    # plot latest state
    translateFigure(fig)
    fig.savefig('NaSch-state.pdf', bbox_inches='tight', pad_inches=0.02)

    with plt.rc_context({'font.size': 8}):
        fig = plt.figure(figsize=(16, 8 ))
        nasch.plot.TimeMapPlot(map, 'map', 'avg', range(len(map.roads)))

    for hi in fig.findobj(AxesImage):
        image2patch(hi)

    translateFigure(fig)

    fig.savefig('NaSch-space.pdf', bbox_inches='tight', pad_inches=0.02)


# ------------------------------------------------------------------------
def translateFigure(fig):
    """TRANSLATEFIGURE Replace English plot labels by German translations."""

    tr = [
        ('at timestep',      'bei Zeitschritt'),
        ('road network',     'Straßennetz'),
        ('average velocity', 'mittlere Geschwindigkeit'),
        ('road',             'Straße'),
        ('time',             'Zeit'),
        ('velocity',         'Geschwindigkeit'),
    ]

    for h in fig.findobj(Text):
        s = h.get_text()

        for en, de in tr:
            s = s.replace(en, de)

        h.set_text(s)


# ------------------------------------------------------------------------
def image2patch(hi):
    """IMAGE2PATCH Replace an indexed AxesImage object by vector patches.

    Each non-NaN (unmasked) entry of the two-dimensional image data is
    represented by one rectangular patch. NaN entries are omitted completely.

    The function assumes a uniformly spaced image grid.
    """

    C = np.ma.masked_invalid(hi.get_array())
    ax = hi.axes

    m, n = C.shape

    left, right, bottom, top = hi.get_extent()
    if hi.origin == 'upper':
        bottom, top = top, bottom 

    dx = (right - left) / n
    dy = (top - bottom) / m

    x = left + dx * (np.arange(n) + 0.5)
    y = bottom + dy * (np.arange(m) + 0.5)

    i, j = np.nonzero(~np.ma.getmaskarray(C))
    xc = x[j]
    yc = y[i]

    V = np.stack([
        np.column_stack([xc - dx / 2, yc - dy / 2]),
        np.column_stack([xc + dx / 2, yc - dy / 2]),
        np.column_stack([xc + dx / 2, yc + dy / 2]),
        np.column_stack([xc - dx / 2, yc + dy / 2]),
    ], axis=1)

    hp = PolyCollection(V, array=C[i, j].data, cmap=hi.get_cmap(),
                        norm=hi.norm, edgecolors='none')
    hp.set_zorder(hi.get_zorder())
    ax.add_collection(hp, autolim=False)

    hi.remove()

    return hp


if __name__ == '__main__':
    NaSch_export()
