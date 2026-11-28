"""Titan Colossus: the evolved Titan Howitzer. A massive armored cannon with twin stacked bores,
layered armor plates, glowing vent rings, and a reactor core on top."""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import common as c  # noqa: E402

c.reset_scene()

# Chunky grip and a forward hand grip under the barrel.
c.box("Handle", (0.46, 0.28, 0.8), (0, 0, -0.08), rotation=(0, -12, 0), bevel=0.07)
c.box("Handle", (0.3, 0.24, 0.6), (-1.6, 0, 0.05), rotation=(0, 10, 0), bevel=0.06)

# Heavy shoulder stock with a recoil pad.
c.box("Stock", (1.3, 0.5, 0.7), (0.95, 0, 0.5), bevel=0.08)
c.box("Stock", (0.18, 0.56, 0.9), (1.66, 0, 0.45), bevel=0.05)

# The main housing.
c.box("Body", (2.6, 0.62, 0.75), (-0.9, 0, 0.62), bevel=0.08)

# Layered armor plates over the housing.
for i, x in enumerate((-0.1, -0.85, -1.6)):
    c.box("Shell", (0.7, 0.7, 0.3), (x, 0, 1.05 - i * 0.03), rotation=(0, 4, 0), bevel=0.05)
    for side in (-1, 1):
        c.box("Shell", (0.66, 0.08, 0.55), (x, side * 0.36, 0.62), bevel=0.03)

# Twin stacked bores with a heavy muzzle block.
c.cylinder("Metal", 0.24, 1.6, (-2.75, 0, 0.82))
c.cylinder("Metal", 0.2, 1.6, (-2.75, 0, 0.38))
c.box("Metal", (0.4, 0.68, 0.95), (-3.5, 0, 0.6), bevel=0.06)
c.box("Tip", (0.14, 0.6, 0.85), (-3.77, 0, 0.6), bevel=0.03)

# Glowing vent rings around each bore and a seam along the housing.
for x in (-2.3, -2.9):
    c.torus("Glow", 0.28, 0.05, (x, 0, 0.82))
    c.torus("Glow", 0.24, 0.05, (x, 0, 0.38))
c.box("Glow", (2.4, 0.64, 0.06), (-0.9, 0, 0.3), bevel=0.01)

# A reactor core cradled on top, with prongs around it.
c.sphere("Crystal", 0.24, (-0.85, 0, 1.45))
for side in (-1, 1):
    c.box("Metal", (0.08, 0.08, 0.4), (-0.85, side * 0.26, 1.38), rotation=(side * 18, 0, 0), bevel=0.01)
    c.box("Metal", (0.08, 0.4, 0.08), (-0.85 + side * 0.26, 0, 1.38), rotation=(0, side * -18, 0), bevel=0.01)

c.finish("TitanColossus")
