from .Node import Node


class Connector(Node):
    """CONNECTOR One incoming and one outgoing road."""

    def __init__(self, inp, out):
        super().__init__(inp, out)

    def prepare(self, map):
        self.inp.temp = self.getTemp(self.out)

    def transfer(self, map):
        self.transferTemp(self.inp, self.out)
