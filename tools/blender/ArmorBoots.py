"""Armor boots: a pair of greaves with knee caps, ankle cuffs, and plated toes.
Roles: Body, Trim, Glow. Front faces -Y."""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import common as c  # noqa: E402

c.reset_scene()

for side in (-1, 1):
    x = side * 0.45
    c.box("Body", (0.55, 0.6, 0.9), (x, 0, 0.7), bevel=0.08)
    c.box("Body", (0.6, 0.95, 0.35), (x, -0.15, 0.18), bevel=0.1)
    c.box("Trim", (0.62, 0.66, 0.1), (x, 0, 0.42), bevel=0.03)
    c.box("Trim", (0.62, 1.0, 0.08), (x, -0.15, 0.02), bevel=0.02)
    c.sphere("Trim", 0.22, (x, -0.28, 1.12), subdivisions=1)
    c.box("Glow", (0.35, 0.05, 0.06), (x, -0.31, 0.7), bevel=0.0)

c.finish_model("ArmorBoots", required=("Body", "Trim"))
