import numpy as np


def graphToMapData(G, vmax=8, density=0.2, brake=0.05):
    """GRAPHTOMAPDATA Replace every graph node by a roundabout.

    Roundabout approaches use the directions of the global graph edges.
    Long ring sections are split so that their length is at most 3*vmax.
    Short roads are allowed. Sources and sinks use period 2.

    G is a graph as returned by randomGraph (x, y, edges). All node
    indices of the result are 0-based.
    """

    vmax = int(vmax)
    if vmax <= 0:
        raise ValueError('vmax must be a positive integer')
    if not 0 <= density <= 1:
        raise ValueError('density must be in [0,1]')
    if not 0 <= brake <= 1:
        raise ValueError('brake must be in [0,1]')

    x = np.asarray(G.x, dtype=float)
    y = np.asarray(G.y, dtype=float)
    ends = np.asarray(G.edges, dtype=int).reshape(-1, 2)
    nGlobal = x.size

    if nGlobal == 0:
        raise ValueError('The graph is empty.')

    node1 = []
    node2 = []
    nodex = []
    nodey = []
    neighbors = [None] * nGlobal
    inPort = [None] * nGlobal
    outPort = [None] * nGlobal

    def addPoint(p):
        nodex.append(p[0])
        nodey.append(p[1])
        return len(nodex) - 1

    def addRoad(a, b):
        node1.append(a)
        node2.append(b)

    def addSplitRoad(a, b):
        p1 = np.array([nodex[a], nodey[a]])
        p2 = np.array([nodex[b], nodey[b]])
        len_ = np.linalg.norm(p2 - p1)
        n = max(1, int(np.ceil(len_ / (3 * vmax))))
        previous = a

        for q in range(1, n):
            current = addPoint(p1 + q / n * (p2 - p1))
            addRoad(previous, current)
            previous = current

        addRoad(previous, b)

    for i in range(nGlobal):
        e = ends[(ends[:, 0] == i) | (ends[:, 1] == i)]
        nbr = np.unique(e)
        nbr = nbr[nbr != i]

        if nbr.size == 0:
            raise ValueError(f'Node {i} is isolated.')

        phi = np.mod(np.arctan2(y[nbr] - y[i], x[nbr] - x[i]), 2 * np.pi)
        order = np.argsort(phi, kind='stable')
        phi = phi[order]
        nbr = nbr[order]
        neighbors[i] = nbr
        m = nbr.size

        if m == 1:
            radius = vmax / 2
        else:
            gap = np.diff(np.append(phi, phi[0] + 2 * np.pi))
            radius = np.max(vmax / 2 / np.tan(gap / 4))

        outer = radius + 2 * vmax
        halfLane = vmax / 2
        div = np.zeros(m, dtype=int)
        merge = np.zeros(m, dtype=int)
        exit = np.zeros(m, dtype=int)
        entry = np.zeros(m, dtype=int)
        c = np.array([x[i], y[i]])

        for k in range(m):
            er = np.array([np.cos(phi[k]), np.sin(phi[k])])
            et = np.array([-np.sin(phi[k]), np.cos(phi[k])])
            div[k] = addPoint(c + radius * er - halfLane * et)
            merge[k] = addPoint(c + radius * er + halfLane * et)
            exit[k] = addPoint(c + outer * er - halfLane * et)
            entry[k] = addPoint(c + outer * er + halfLane * et)
            addRoad(div[k], merge[k])
            addRoad(div[k], exit[k])
            addRoad(entry[k], merge[k])

        for k in range(m):
            addSplitRoad(merge[k], div[(k + 1) % m])

        inPort[i] = entry
        outPort[i] = exit

    for i, j in ends:
        a = outPort[i][neighbors[i] == j][0]
        b = inPort[j][neighbors[j] == i][0]

        addRoad(a, b)

    node1 = np.array(node1, dtype=int)
    node2 = np.array(node2, dtype=int)
    times = np.zeros(node1.size, dtype=int)

    for i in range(len(nodex)):
        inp = np.flatnonzero(node2 == i)
        out = np.flatnonzero(node1 == i)

        if inp.size == 0 and out.size == 1:
            times[out] = 2
        elif inp.size == 1 and out.size == 0:
            times[inp] = 2

    return dict(node1=node1, node2=node2, nodex=np.array(nodex),
                nodey=np.array(nodey), times=times, vmax=vmax,
                density=density, brake=brake)
