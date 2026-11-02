import numpy as np

from .Node import Node


class Source(Node):
    """SOURCE Insert vehicles periodically into one outgoing road."""

    def __init__(self, out, period):
        super().__init__([], out)
        self.period = period

    def prepare(self, map):
        pass

    def transfer(self, map):
        if (self.period > 0 and map.t % self.period == 0
                and np.isnan(self.out.u[0])):
            self.out.u[0] = self.out.vmax + 1j * map.nextID
            map.nextID = map.nextID + 1
