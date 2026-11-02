import numpy as np

from .Node import Node


class Diverge(Node):
    """DIVERGE One incoming and several outgoing roads."""

    def __init__(self, inp, out):
        super().__init__(inp, out)
        self._selected = None

    def prepare(self, map):
        self._selected = np.random.randint(len(self.out))
        self.inp.temp = self.getTemp(self.out[self._selected])

    def transfer(self, map):
        self.transferTemp(self.inp, self.out[self._selected])
