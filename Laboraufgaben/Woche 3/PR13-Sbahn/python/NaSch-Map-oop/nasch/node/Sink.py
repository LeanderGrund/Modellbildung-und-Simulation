import numpy as np

from .Node import Node


class Sink(Node):
    """SINK Remove vehicles periodically from one incoming road."""

    def __init__(self, inp, period):
        super().__init__(inp, [])
        self.period = period

    def prepare(self, map):
        if self.period > 0 and map.t % self.period == 0:
            self.inp.temp = np.full(self.inp.vmax, np.nan + 0j)
        else:
            self.inp.temp = np.empty(0, dtype=complex)

    def transfer(self, map):
        map.leave = map.leave + np.count_nonzero(~np.isnan(self.inp.temp))
