import numpy as np

from .Node import Node


class Merge(Node):
    """MERGE Several incoming roads with fixed priority and one outgoing road."""

    def __init__(self, inp, out):
        super().__init__(inp, out)

    def prepare(self, map):
        self.inp[0].temp = self.getTemp(self.out)

        for k in range(1, len(self.inp)):
            previous = self.inp[k - 1]
            n = min(previous.vmax, previous.u.size)

            if np.all(np.isnan(previous.u[-n:])):
                self.inp[k].temp = self.getTemp(self.out)
            else:
                self.inp[k].temp = np.empty(0, dtype=complex)

    def transfer(self, map):
        for k in range(len(self.inp)):
            self.transferTemp(self.inp[k], self.out)
