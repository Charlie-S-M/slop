"""Gilded Sovereign: the evolved Gilded Handcannon. A royal revolver-style handcannon with a
fluted drum, an engraved golden frame, a long ribbed barrel, and a jeweled crown on top."""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import common as c  # noqa: E402

c.reset_scene()

# A curved grip: three stacked blocks bending back, with a pommel.
c.box("Handle", (0.36, 0.26, 0.4), (0.05, 0, 0.12), rotation=(0, -10, 0), bevel=0.06)
c.box("Handle", (0.36, 0.26, 0.4), (0.14, 0, -0.22), rotation=(0, -24, 0), bevel=0.06)
c.box("Stock", (0.42, 0.3, 0.14), (0.24, 0, -0.45), rotation=(0, -24, 0), bevel=0.05)

# The golden frame and its trigger guard.
c.box("Body", (1.0, 0.32, 0.42), (-0.35, 0, 0.5), bevel=0.06)
c.box("Body", (0.5, 0.18, 0.08), (-0.45, 0, 0.12), bevel=0.02)
c.box("Body", (0.08, 0.18, 0.3), (-0.68, 0, 0.24), bevel=0.02)
c.box("Shell", (0.9, 0.36, 0.1), (-0.35, 0, 0.75), bevel=0.04)

# The fluted drum: a cylinder with grooves around it.
c.cylinder("Metal", 0.27, 0.5, (-0.35, 0, 0.48))
for i in range(6):
    angle = 2 * math.pi * i / 6
    c.box(
        "Glow",
        (0.46, 0.05, 0.05),
        (-0.35, math.cos(angle) * 0.27, 0.48 + math.sin(angle) * 0.27),
        bevel=0.0,
    )

# A long ribbed barrel with a rib along the top.
c.cylinder("Metal", 0.13, 1.1, (-1.35, 0, 0.55))
c.box("Shell", (1.1, 0.1, 0.08), (-1.35, 0, 0.7), bevel=0.02)
for x in (-1.0, -1.35, -1.7):
    c.torus("Glow", 0.15, 0.03, (x, 0, 0.55))
c.box("Tip", (0.12, 0.3, 0.3), (-1.95, 0, 0.55), bevel=0.03)

# A jeweled crown on top of the frame.
c.box("Shell", (0.5, 0.3, 0.1), (-0.35, 0, 0.86), bevel=0.02)
for i, dx in enumerate((-0.2, -0.1, 0.0, 0.1, 0.2)):
    height = 0.28 if i % 2 == 0 else 0.18
    c.cone("Shell", 0.05, 0, height, (-0.35 + dx, 0, 0.91 + height / 2), vertices=4)
c.sphere("Crystal", 0.08, (-0.35, 0.16, 0.86), subdivisions=1)
c.sphere("Crystal", 0.08, (-0.35, -0.16, 0.86), subdivisions=1)
c.sphere("Crystal", 0.1, (-0.35, 0, 1.2), subdivisions=1)

c.finish("GildedSovereign")
