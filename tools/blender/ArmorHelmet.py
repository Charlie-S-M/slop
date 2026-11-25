"""Armor helmet: a rounded great helm with a visor slit, a crest ridge, and cheek guards.
Roles: Body (set color), Trim (set trim), Glow (visor light on top rarities). Front faces -Y."""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import common as c  # noqa: E402

c.reset_scene()

c.sphere("Body", 0.62, (0, 0, 0.62))
c.cylinder("Body", 0.62, 0.55, (0, 0, 0.3), axis="Z")
c.box("Trim", (1.3, 1.3, 0.12), (0, 0, 0.05), bevel=0.04)
# A raised crest from front to back.
c.box("Trim", (0.12, 1.15, 0.28), (0, 0, 1.22), bevel=0.04)
# The face plate with a visor slit.
c.box("Body", (0.95, 0.12, 0.62), (0, -0.6, 0.38), bevel=0.05)
c.box("Glow", (0.7, 0.05, 0.08), (0, -0.67, 0.5), bevel=0.0)
for side in (-1, 1):
    c.box("Trim", (0.14, 0.5, 0.55), (side * 0.6, -0.15, 0.28), bevel=0.04)
    c.cone("Trim", 0.07, 0, 0.3, (side * 0.45, 0, 1.08), vertices=4)

c.finish_model("ArmorHelmet", required=("Body", "Trim"))
