"""Starforge Ascendant: the evolved Starforge. A radiant winged minigun with a star-shaped core,
feathered wing shells, a halo ring over the receiver, and barrels flared like light rays."""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import common as c  # noqa: E402

c.reset_scene()

c.box("Handle", (0.42, 0.26, 0.78), (0, 0, -0.06), rotation=(0, -12, 0), bevel=0.06)
c.box("Stock", (0.9, 0.5, 0.55), (0.75, 0, 0.55), bevel=0.08)
c.box("Stock", (0.2, 0.56, 0.8), (1.25, 0, 0.5), bevel=0.06)

# Receiver.
c.box("Body", (1.7, 0.6, 0.7), (-0.5, 0, 0.62), bevel=0.08)

# Feathered wings: three tapering feathers per side, angled up and back.
for side in (-1, 1):
    for i, length in enumerate((1.3, 1.05, 0.8)):
        c.box(
            "Shell",
            (length, 0.05, 0.16),
            (-0.15 + i * 0.12, side * (0.34 + i * 0.05), 0.95 + i * 0.13),
            rotation=(side * -35, -18 - i * 6, 0),
            bevel=0.02,
        )

# Six barrels flared outward like rays, held by a front collar.
for i in range(6):
    angle = 2 * math.pi * i / 6
    y = math.cos(angle) * 0.22
    z = 0.62 + math.sin(angle) * 0.22
    c.cylinder("Metal", 0.065, 2.0, (-2.3, y, z), rotation=(0, 90, 0))
c.cylinder("Metal", 0.32, 0.18, (-1.5, 0, 0.62))
c.cylinder("Metal", 0.3, 0.12, (-3.0, 0, 0.62))
c.box("Tip", (0.1, 0.58, 0.58), (-3.32, 0, 0.62), bevel=0.04)

# A star-shaped core at the front of the receiver.
c.spike_ring("Crystal", 10, 0.12, 0.42, 0.07, (-1.42, 0, 0.62), plane="YZ", alternate=0.5)
c.sphere("Crystal", 0.14, (-1.42, 0, 0.62))

# A halo ring floating over the receiver, and glowing seams.
c.torus("Glow", 0.36, 0.035, (-0.5, 0, 1.45), rotation=(0, 0, 0))
c.box("Glow", (1.5, 0.62, 0.05), (-0.5, 0, 0.29), bevel=0.01)
for x in (-2.1, -2.6):
    c.torus("Glow", 0.3, 0.03, (x, 0, 0.62))

c.finish("StarforgeAscendant")
