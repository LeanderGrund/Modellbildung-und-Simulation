import numpy as np


def myUpdate(u, p):
    """MYUPDATE Advance the periodic NaSch model by exactly one time step.

    The street state is stored as a complex-valued vector:
      NaN     : empty cell
      u.real  : vehicle velocity
      u.imag  : vehicle ID
    """

    x = np.flatnonzero(~np.isnan(u))
    if x.size == 0:
        return u

    v = u[x].real
    id = u[x].imag
    n = u.size

    # Number of empty cells in front, including the periodic boundary.
    d = np.append(np.diff(x) - 1, n + x[0] - x[-1] - 1)

    # Nagel-Schreckenberg update.
    v = np.minimum(p.vmax, v + 1)
    v = np.minimum(d, v)
    v = np.maximum(0, v - (np.random.rand(v.size) < p.brake))

    # Move vehicles and wrap around periodically.
    u[x] = np.nan
    x = np.mod(x + v, n).astype(int)
    u[x] = v + 1j * id

    return u
