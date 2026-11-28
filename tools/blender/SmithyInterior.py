"""The forge cutscene's room: a cozy medieval smithy interior, built at 1 unit = 1 stud and open at
the front (-Y) for the camera. Stone walls with timber posts and beams, a big stone hearth with a
chimney and a glowing mouth on the back wall (+Y), tool racks with hammers and tongs, shelves of
buckets, stacked firewood, hanging chains, and a lantern.
Roles: Stone, Timber, Wood, Iron, Ember, Roof."""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import common as c  # noqa: E402

c.reset_scene()

W, D, H = 88.0, 68.0, 44.0  # width (X), depth (Y), height (Z)

# Floor flagstones: a grid of slightly uneven slabs.
for ix in range(-4, 5):
    for iy in range(-3, 4):
        lift = 0.05 * ((ix * 3 + iy * 5) % 3)
        c.box("Stone", (9.6, 9.6, 0.6 + lift), (ix * 10, iy * 10, -0.3 + lift / 2), bevel=0.25)

# Stone lower walls on the back and sides, with a timber-framed upper half.
c.box("Stone", (W, 2.4, 16), (0, D / 2, 8), bevel=0.4)
for side in (-1, 1):
    c.box("Stone", (2.4, D, 16), (side * W / 2, 0, 8), bevel=0.4)
c.box("Wood", (W, 1.6, H - 16), (0, D / 2 + 0.3, 16 + (H - 16) / 2), bevel=0.1)
for side in (-1, 1):
    c.box("Wood", (1.6, D, H - 16), (side * (W / 2 + 0.3), 0, 16 + (H - 16) / 2), bevel=0.1)
# Timber posts and a beam along the top of the stone.
for x in (-W / 2 + 2, -22, 22, W / 2 - 2):
    c.box("Timber", (2.2, 2.2, H), (x, D / 2 - 1.4, H / 2), bevel=0.2)
for y in (-D / 2 + 2, 0, D / 2 - 2):
    for side in (-1, 1):
        c.box("Timber", (2.2, 2.2, H), (side * (W / 2 - 1.4), y, H / 2), bevel=0.2)
c.box("Timber", (W, 1.8, 2.2), (0, D / 2 - 1.2, 16.6), bevel=0.2)
for side in (-1, 1):
    c.box("Timber", (1.8, D, 2.2), (side * (W / 2 - 1.2), 0, 16.6), bevel=0.2)
# Diagonal braces in the timber frame.
for x in (-33, -11, 11, 33):
    c.box("Timber", (1.2, 1.2, 18), (x, D / 2 - 1.0, 28), rotation=(0, 35 if x < 0 else -35, 0), bevel=0.15)

# Ceiling: big cross beams and plank roof.
for y in range(-30, 31, 12):
    c.box("Timber", (W, 2.6, 2.6), (0, y, H - 2), bevel=0.25)
c.box("Roof", (W + 4, D + 4, 1.2), (0, 0, H + 0.6), bevel=0.2)

# The hearth: a stone mass on the back wall with an arched mouth, glowing coals, and a chimney.
c.box("Stone", (22, 8, 14), (0, D / 2 - 4, 7), bevel=0.6)
c.box("Ember", (12, 2, 6), (0, D / 2 - 8.2, 4.5), bevel=0.3)
c.box("Iron", (14, 1.2, 1.2), (0, D / 2 - 8.6, 8.2), bevel=0.15)
for i in range(7):
    c.sphere("Ember", 0.9, (-5 + i * 1.7, D / 2 - 7.5, 1.6 + (i % 2) * 0.4), subdivisions=1)
c.box("Stone", (14, 7, H - 14), (0, D / 2 - 3.5, 14 + (H - 14) / 2), bevel=0.5)
c.box("Stone", (24, 9, 1.6), (0, D / 2 - 4, 14.6), bevel=0.3)
# A big bellows beside the hearth.
c.box("Wood", (4, 6, 1.4), (14, D / 2 - 7, 2.2), rotation=(0, 0, 12), bevel=0.3)
c.cone("Iron", 0.7, 0.3, 3, (12, D / 2 - 9.5, 2.2), rotation=(90, 0, 0))

# Tool racks on the left wall: a board with hammers and tongs.
c.box("Timber", (0.8, 16, 6), (-W / 2 + 3, -6, 11), bevel=0.15)
for i in range(5):
    y = -13 + i * 3.5
    c.cylinder("Wood", 0.18, 3.2, (-W / 2 + 3.8, y, 10.5), axis="Z")
    if i % 2 == 0:
        c.box("Iron", (1.0, 1.6, 0.9), (-W / 2 + 3.8, y, 12.3), bevel=0.15)
    else:
        c.box("Iron", (0.25, 0.25, 2.6), (-W / 2 + 3.8, y + 0.3, 9.6), rotation=(14, 0, 0), bevel=0.05)

# Shelves on the right wall with buckets and jars.
for level in range(3):
    z = 6 + level * 4.5
    c.box("Timber", (2.4, 18, 0.5), (W / 2 - 3, 4, z), bevel=0.1)
    for i in range(4):
        c.cylinder("Wood", 0.9, 1.6, (W / 2 - 3, -2 + i * 4, z + 1.05), axis="Z")

# Firewood stacked in the back corners.
for corner in (-1, 1):
    for row in range(4):
        for i in range(5 - row):
            c.cylinder(
                "Wood",
                0.7,
                6,
                (corner * (W / 2 - 9), D / 2 - 6 + (i - (4 - row) / 2) * 1.45, 0.7 + row * 1.25),
                axis="X",
            )

# Chains hanging from a beam, and a lantern.
for x in (-18, 18):
    for link in range(8):
        c.torus("Iron", 0.35, 0.09, (x, 6, H - 4 - link * 0.75), rotation=(0, 90 if link % 2 else 0, 0))
c.cylinder("Iron", 0.1, 4, (-30, -12, H - 4), axis="Z")
c.box("Iron", (1.4, 1.4, 2), (-30, -12, H - 7), bevel=0.15)
c.sphere("Ember", 0.55, (-30, -12, H - 7))

c.finish_model("SmithyInterior", required=("Stone", "Timber", "Ember"), resolution=(1200, 800))
