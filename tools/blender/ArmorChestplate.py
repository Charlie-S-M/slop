"""Armor chestplate: a sculpted breastplate (two angled halves meeting at a ridge), a tapered waist
of overlapping plates, a collar, and layered pauldrons. Roles: Body, Trim, Glow. Front faces -Y."""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import common as c  # noqa: E402

c.reset_scene()

# The breastplate: two halves angled toward a center ridge, over a back plate.
for side in (-1, 1):
    c.box("Body", (0.95, 0.55, 1.05), (side * 0.45, -0.2, 1.05), rotation=(0, 0, side * 14), bevel=0.14)
c.box("Body", (1.75, 0.55, 1.1), (0, 0.25, 1.05), bevel=0.14)
c.box("Trim", (0.1, 0.12, 1.0), (0, -0.5, 1.05), rotation=(8, 0, 0), bevel=0.03)
c.sphere("Glow", 0.13, (0, -0.55, 1.2), subdivisions=2)
# The collar.
c.torus("Trim", 0.42, 0.08, (0, 0, 1.62), rotation=(0, 0, 0))
# A tapered waist of overlapping plates.
for index in range(3):
    width = 1.35 - index * 0.14
    c.box("Body", (width, 0.85, 0.22), (0, 0, 0.42 - index * 0.17), bevel=0.06)
    c.box("Trim", (width + 0.04, 0.88, 0.05), (0, 0, 0.32 - index * 0.17), bevel=0.01)
# Layered pauldrons.
for side in (-1, 1):
    c.sphere("Body", 0.4, (side * 1.0, 0, 1.45), subdivisions=3)
    for layer in range(2):
        c.box(
            "Trim",
            (0.55, 0.85, 0.08),
            (side * (1.08 + layer * 0.06), 0, 1.22 - layer * 0.16),
            rotation=(0, side * -28, 0),
            bevel=0.03,
        )

c.finish_model("ArmorChestplate", required=("Body", "Trim"))
