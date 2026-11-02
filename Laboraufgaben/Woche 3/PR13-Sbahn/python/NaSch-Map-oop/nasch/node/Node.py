from abc import ABC, abstractmethod

import numpy as np


class Node(ABC):
    """NODE Base class for connections between roads.

    inp and out hold the incoming and outgoing roads (inp avoids the
    Python keyword in).
    """

    def __init__(self, inp, out):
        self.inp = inp
        self.out = out

    # --------------------------------------------------------------------
    def getTemp(self, outRoad):
        """GETTEMP Return the free beginning of an outgoing road."""

        i = np.flatnonzero(~np.isnan(outRoad.u))

        if i.size == 0:
            n = min(outRoad.vmax, outRoad.u.size)
        else:
            n = min(outRoad.vmax, i[0])

        return np.full(n, np.nan + 0j)

    # --------------------------------------------------------------------
    def transferTemp(self, inRoad, outRoad):
        """TRANSFERTEMP Copy the temporary continuation to the outgoing road."""

        outRoad.u[:inRoad.temp.size] = inRoad.temp

    # --------------------------------------------------------------------
    @abstractmethod
    def prepare(self, map):
        pass

    @abstractmethod
    def transfer(self, map):
        pass
