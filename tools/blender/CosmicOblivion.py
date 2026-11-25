"""Cosmic Oblivion: the evolved Cosmic Annihilator. A heavy minigun whose six barrels orbit a void
core, with swept wing shells, glowing rings, and a floating nebula orb on top."""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import common as c  # noqa: E402

c.reset_scene()

# Pistol grip and a carry handle.
c.box("Handle", (0.44, 0.26, 0.78), (0, 0, -0.06), rotation=(0, -12, 0), bevel=0.06)
c.box("Stock", (1.0, 0.18, 0.12), (-0.6, 0, 1.28), bevel=0.04)
for x in (-0.15, -1.05):
    c.box("Stock", (0.12, 0.16, 0.3), (x, 0, 1.12), bevel=0.03)

# The motor housing and its back plate.
c.box("Body", (1.6, 0.64, 0.8), (-0.55, 0, 0.62), bevel=0.08)
c.box("Body", (0.3, 0.7, 0.9), (0.35, 0, 0.62), bevel=0.06)

# Swept wing shells on both sides.
for side in (-1, 1):
    c.box("Shell", (1.3, 0.08, 0.5), (-0.6, side * 0.38, 0.8), rotation=(side * -14, -12, 0), bevel=0.03)
    c.box("Shell", (0.8, 0.06, 0.35), (-0.3, side * 0.46, 1.0), rotation=(side * -30, -24, 0), bevel=0.02)

# Six barrels orbiting a void core, held by two clamps.
center_z = 0.62
for i in range(6):
    angle = 2 * math.pi * i / 6
    c.cylinder("Metal", 0.07, 2.1, (-2.35, math.cos(angle) * 0.22, center_z + math.sin(angle) * 0.22))
c.cylinder("Crystal", 0.1, 2.0, (-2.35, 0, center_z))
for x in (-1.6, -3.1):
    c.cylinder("Metal", 0.34, 0.14, (x, 0, center_z))
c.box("Tip", (0.12, 0.62, 0.62), (-3.42, 0, center_z), bevel=0.04)

# Glowing rings and seams.
for x in (-2.0, -2.7):
    c.torus("Glow", 0.33, 0.04, (x, 0, center_z))
c.box("Glow", (1.4, 0.66, 0.05), (-0.55, 0, 0.27), bevel=0.01)

# The nebula orb floating over the housing.
c.sphere("Crystal", 0.2, (-0.6, 0, 1.6))
c.torus("Glow", 0.3, 0.025, (-0.6, 0, 1.6), rotation=(70, 0, 0))

c.finish("CosmicOblivion")
