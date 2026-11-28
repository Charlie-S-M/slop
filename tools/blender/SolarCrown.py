"""Solar Crown: the evolved Solar Flare. A long golden rifle with a blazing sunburst crown around
the barrel, a sun-disc sight rising from the receiver, and swept golden fins."""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import common as c  # noqa: E402

c.reset_scene()

# Grip, raked back, with a trigger guard.
c.box("Handle", (0.42, 0.24, 0.78), (0.02, 0, -0.06), rotation=(0, -16, 0), bevel=0.06)
c.box("Handle", (0.42, 0.16, 0.08), (-0.38, 0, -0.08), bevel=0.02)
c.box("Handle", (0.08, 0.16, 0.3), (-0.58, 0, 0.06), bevel=0.02)

# Stock: a long, tapering butt with a cheek rest.
c.box("Stock", (1.2, 0.3, 0.42), (0.85, 0, 0.42), rotation=(0, 5, 0), bevel=0.07)
c.box("Stock", (0.32, 0.34, 0.86), (1.45, 0, 0.28), bevel=0.07)
c.box("Stock", (0.7, 0.32, 0.12), (0.8, 0, 0.68), bevel=0.04)

# Receiver and its golden shell.
c.box("Body", (1.8, 0.42, 0.56), (-0.45, 0, 0.6), bevel=0.07)
c.box("Shell", (1.5, 0.5, 0.18), (-0.4, 0, 0.94), bevel=0.06)
c.box("Shell", (0.6, 0.56, 0.36), (0.25, 0, 0.62), bevel=0.06)
for side in (-1, 1):
    # Swept fins rising off the back of the shell.
    c.box("Shell", (0.55, 0.04, 0.16), (0.1, side * 0.3, 0.98), rotation=(side * -40, -18, 0), bevel=0.01)
    c.box("Shell", (0.4, 0.04, 0.13), (-0.85, side * 0.28, 0.96), rotation=(side * -40, -18, 0), bevel=0.01)

# Barrel: a stepped shroud, a long bore, and a slotted muzzle brake.
c.cylinder("Metal", 0.2, 0.9, (-1.75, 0, 0.62))
c.cylinder("Metal", 0.12, 1.3, (-2.55, 0, 0.62))
for x in (-3.0, -3.18):
    c.box("Metal", (0.1, 0.4, 0.26), (x, 0, 0.62), bevel=0.02)
c.box("Tip", (0.12, 0.3, 0.3), (-3.3, 0, 0.62), bevel=0.02)

# Glowing seams along the body and rings around the shroud.
c.box("Glow", (1.6, 0.44, 0.05), (-0.45, 0, 0.42), bevel=0.01)
c.box("Glow", (0.05, 0.44, 0.4), (-1.3, 0, 0.62), bevel=0.01)
c.torus("Glow", 0.24, 0.045, (-1.4, 0, 0.62))
c.torus("Glow", 0.24, 0.045, (-2.1, 0, 0.62))

# The sunburst crown around the barrel.
c.torus("Crystal", 0.36, 0.06, (-2.35, 0, 0.62))
c.spike_ring("Crystal", 12, 0.38, 0.95, 0.08, (-2.35, 0, 0.62), plane="YZ", alternate=0.55)

# The sun-disc sight on a short post above the receiver.
c.box("Metal", (0.12, 0.12, 0.22), (-0.55, 0, 1.13), bevel=0.02)
c.cylinder("Crystal", 0.22, 0.1, (-0.55, 0, 1.42), axis="Y")
c.spike_ring("Crystal", 12, 0.24, 0.52, 0.05, (-0.55, 0, 1.42), plane="XZ", alternate=0.55)

c.finish("SolarCrown")
