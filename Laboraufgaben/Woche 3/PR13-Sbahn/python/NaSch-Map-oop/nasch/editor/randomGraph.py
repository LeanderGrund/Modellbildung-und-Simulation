from types import SimpleNamespace

import numpy as np
from scipy.spatial import Delaunay


def randomGraph(n=10, dmin=100, dmax=300):
    """RANDOMGRAPH Generate a bidirectional random Delaunay network.

    Nodes lie in [0,1000]^2. Each new node has a nearest-neighbor distance
    between dmin and dmax. Every Delaunay edge is inserted in both directions.

    The graph replaces the MATLAB digraph: x and y hold the node
    coordinates, edges the (0-based) directed edges as rows [i j].
    """

    n = int(n)
    if n < 3:
        raise ValueError('n must be an integer >= 3')
    if dmin <= 0 or dmax <= 0:
        raise ValueError('dmin and dmax must be positive')
    if dmax <= dmin:
        raise ValueError('dmax must be larger than dmin.')

    L = 1000
    x = np.zeros(n)
    y = np.zeros(n)
    x[0] = L * np.random.rand()
    y[0] = L * np.random.rand()

    for k in range(1, n):
        accepted = False

        for trial in range(20000):
            i = np.random.randint(k)
            r = dmin + (dmax - dmin) * np.random.rand()
            phi = 2 * np.pi * np.random.rand()
            p = np.array([x[i] + r * np.cos(phi), y[i] + r * np.sin(phi)])

            if np.all(p >= 0) and np.all(p <= L):
                d = np.hypot(x[:k] - p[0], y[:k] - p[1])
                if d.min() >= dmin and d.min() <= dmax:
                    x[k] = p[0]
                    y[k] = p[1]
                    accepted = True
                    break

        if not accepted:
            raise RuntimeError('Could not place all nodes with the requested distances.')

    # undirected Delaunay edges, each inserted in both directions
    tri = Delaunay(np.column_stack([x, y]))
    E = np.vstack([tri.simplices[:, [0, 1]], tri.simplices[:, [1, 2]],
                   tri.simplices[:, [2, 0]]])
    E = np.unique(np.sort(E, axis=1), axis=0)

    return SimpleNamespace(x=x, y=y, edges=np.vstack([E, E[:, ::-1]]))
