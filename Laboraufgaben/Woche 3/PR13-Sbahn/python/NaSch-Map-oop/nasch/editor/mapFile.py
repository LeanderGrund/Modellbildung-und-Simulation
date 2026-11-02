import os
from types import SimpleNamespace

import numpy as np


# Maps are stored as NumPy .npz archives, the Python counterpart of a MAT
# file. Node indices are stored 0-based. The editable graph is stored in
# the arrays G_x, G_y, and G_edges.


def loadMapData(filename):
    """LOADMAPDATA Load NaSch map data from an .npz file."""

    if not os.path.splitext(filename)[1]:
        filename = filename + '.npz'  # like MATLAB load

    with np.load(filename, allow_pickle=False) as S:
        loaded = {name: S[name] for name in S.files}

    data = {}

    for name in ('node1', 'node2', 'times'):
        if name in loaded:
            data[name] = np.atleast_1d(loaded[name]).astype(int)

    for name in ('nodex', 'nodey'):
        if name in loaded:
            data[name] = np.atleast_1d(loaded[name]).astype(float)

    for name in ('vmax', 'plot'):
        if name in loaded:
            data[name] = int(loaded[name])

    for name in ('density', 'brake'):
        if name in loaded:
            data[name] = float(loaded[name])

    # the editable graph of the map editor
    if {'G_x', 'G_y', 'G_edges'} <= loaded.keys():
        data['G'] = SimpleNamespace(
            x=loaded['G_x'].astype(float),
            y=loaded['G_y'].astype(float),
            edges=loaded['G_edges'].astype(int).reshape(-1, 2))

    return data


def saveMapData(filename, data):
    """SAVEMAPDATA Save map constructor data and graph as .npz file."""

    out = {name: np.asarray(value) for name, value in data.items()
           if name != 'G' and value is not None}

    if 'G' in data:
        G = data['G']
        out['G_x'] = np.asarray(G.x, dtype=float)
        out['G_y'] = np.asarray(G.y, dtype=float)
        out['G_edges'] = np.asarray(G.edges, dtype=int).reshape(-1, 2)

    np.savez(filename, **out)
