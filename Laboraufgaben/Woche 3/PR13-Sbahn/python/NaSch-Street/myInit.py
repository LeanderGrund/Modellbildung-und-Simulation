import numpy as np
from types import SimpleNamespace


def myInit(n=200, tend=100, dt=1, density=0.2, brake=0.05, vmax=8, plot=1):
    """MYINIT Initialize the NaSch traffic model.

    The street state is stored as a complex-valued vector:
      NaN     : empty cell
      u.real  : vehicle velocity
      u.imag  : vehicle ID

    Vehicles are distributed randomly with zero initial velocity and
    assigned unique IDs.

    p contains the model and simulation parameters:
      tend    : number of simulation time steps
      dt      : number of single model steps between two displayed states
                (used only by the interactive interface)
      density : initial vehicle density
      brake   : probability of random braking
      vmax    : maximum vehicle velocity in cells per time step
      plot    : 0 = no plot
                1 = color represents velocity
                2 = color represents vehicle ID
    """

    # number of cells of the street
    n = int(n)
    if n <= 0:
        raise ValueError('n must be a positive integer')

    tend = int(tend)
    if tend <= 0:
        raise ValueError('tend must be a positive integer')

    dt = int(dt)
    if dt < 0:
        raise ValueError('dt must be a nonnegative integer')

    if not 0 <= density <= 1:
        raise ValueError('density must be in [0,1]')

    if not 0 <= brake <= 1:
        raise ValueError('brake must be in [0,1]')

    vmax = int(vmax)
    if vmax <= 0:
        raise ValueError('vmax must be a positive integer')

    plot = int(plot)
    if not 0 <= plot <= 2:
        raise ValueError('plot must be in [0,2]')

    p = SimpleNamespace(
        tend=tend,
        dt=dt,
        density=density,
        brake=brake,
        vmax=vmax,
        plot=plot,
    )

    # number of vehicles
    m = int(round(p.density * n))

    # initialize empty street
    u = np.full(n, np.nan + 0j)

    # distribute vehicles randomly and assign unique vehicle IDs
    u[np.random.permutation(n)[:m]] = 1j * np.arange(1, m + 1)

    return u, p
