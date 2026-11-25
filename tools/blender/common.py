"""Shared helpers for the evolved-gun hero models.

Each model is built from primitives grouped by role (Handle, Body, Shell, Stock, Metal, Tip, Glow,
Crystal). Every role is joined into one mesh object named after the role, so the Studio import gives
one MeshPart per role, which GunBuilder colors from the gun's catalog entry.

Layout matches the existing ForgeModels guns: the grip (Handle) sits at the origin, the barrel runs
toward -X, up is +Z in Blender (+Y in Roblox after export), and the gun is about 4 studs long.

Run a model script headless:
    blender -b --python tools/blender/SolarCrown.py
It writes assets/models/<GunId>.fbx and a preview render assets/models/<GunId>.png.
"""

import math
import os

import bpy
import bmesh
from mathutils import Euler, Vector

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(REPO, "assets", "models")

# Preview colors per role, close to how the game will color them.
ROLE_COLORS = {
    "Handle": (0.25, 0.18, 0.12, 1),
    "Stock": (0.35, 0.24, 0.16, 1),
    "Body": (0.85, 0.65, 0.2, 1),
    "Shell": (0.95, 0.85, 0.55, 1),
    "Metal": (0.35, 0.4, 0.47, 1),
    "Tip": (0.2, 0.2, 0.24, 1),
    "Glow": (1.0, 0.45, 0.1, 1),
    "Crystal": (1.0, 0.9, 0.5, 1),
}

_parts = {}


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _parts.clear()


def _store(role, obj):
    obj.name = f"{role}_piece"
    _parts.setdefault(role, []).append(obj)
    return obj


def _finish(obj, location, rotation, bevel):
    obj.location = Vector(location)
    obj.rotation_euler = Euler([math.radians(a) for a in rotation])
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
    return obj


def box(role, size, location, rotation=(0, 0, 0), bevel=0.03):
    """A box of size (x, y, z), centered at location."""
    bpy.ops.mesh.primitive_cube_add(size=1)
    obj = bpy.context.active_object
    obj.scale = Vector(size)
    bpy.ops.object.transform_apply(scale=True)
    return _store(role, _finish(obj, location, rotation, bevel))


def cylinder(role, radius, length, location, axis="X", rotation=None, vertices=24, bevel=0.02):
    """A cylinder whose length runs along the given axis."""
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=length)
    obj = bpy.context.active_object
    turn = {"X": (0, 90, 0), "Y": (90, 0, 0), "Z": (0, 0, 0)}[axis]
    return _store(role, _finish(obj, location, rotation or turn, bevel))


def cone(role, radius1, radius2, length, location, rotation=(0, 0, 0), vertices=16):
    """A cone or tapered cylinder along its local Z, then rotated."""
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius1, radius2=radius2, depth=length)
    obj = bpy.context.active_object
    return _store(role, _finish(obj, location, rotation, 0))


def torus(role, major, minor, location, rotation=(0, 90, 0), segments=32):
    """A ring; by default it faces along X, wrapped around the barrel."""
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=segments, minor_segments=8)
    obj = bpy.context.active_object
    return _store(role, _finish(obj, location, rotation, 0))


def sphere(role, radius, location, subdivisions=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=radius)
    obj = bpy.context.active_object
    return _store(role, _finish(obj, location, (0, 0, 0), 0))


def spike_ring(role, count, inner, outer, width, center, plane="YZ", alternate=1.0):
    """Pointed spikes radiating from a center, like a sunburst.

    plane "YZ" rings the X axis (around a barrel); "XZ" fans out in the gun's side plane (a sun
    disc seen from the side). Every other spike is scaled by `alternate` for a star look.
    """
    cx, cy, cz = center
    for i in range(count):
        angle = 2 * math.pi * i / count
        reach = outer if i % 2 == 0 else inner + (outer - inner) * alternate
        length = reach - inner
        mid = inner + length / 2
        if plane == "YZ":
            location = (cx, cy + math.cos(angle) * mid, cz + math.sin(angle) * mid)
            # Turning local +Z about X by (angle - 90) points it along (0, cos, sin).
            rotation = (math.degrees(angle) - 90, 0, 0)
        else:
            location = (cx + math.cos(angle) * mid, cy, cz + math.sin(angle) * mid)
            # Turning local +Z about Y by (90 - angle) points it along (cos, 0, sin).
            rotation = (0, 90 - math.degrees(angle), 0)
        cone(role, width, 0, length, location, rotation=rotation, vertices=4)


def _join_roles():
    joined = {}
    for role, objs in _parts.items():
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objs:
            obj.select_set(True)
            bpy.context.view_layer.objects.active = obj
            for mod in list(obj.modifiers):
                bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.context.view_layer.objects.active = objs[0]
        if len(objs) > 1:
            bpy.ops.object.join()
        obj = bpy.context.active_object
        obj.name = role
        obj.data.name = role
        bpy.ops.object.shade_flat()
        joined[role] = obj
    return joined


def _frame_camera(objs):
    """Moves the preview camera back until every object fits."""
    cam = bpy.context.scene.camera
    corners = []
    for obj in objs.values():
        corners += [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    lo = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
    hi = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
    center = (lo + hi) / 2
    span = max(hi.x - lo.x, hi.z - lo.z)
    cam.location = center + Vector((0.8, -span * 1.7, span * 0.45))
    direction = center - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def finish(gun_id):
    """Joins roles, checks the required parts, renders a preview, and exports the FBX."""
    objs = _join_roles()
    missing = [role for role in ("Handle", "Tip") if role not in objs]
    if missing:
        raise SystemExit(f"{gun_id}: missing required parts {missing}")
    os.makedirs(OUT_DIR, exist_ok=True)
    png = os.path.join(OUT_DIR, f"{gun_id}.png")
    fbx = os.path.join(OUT_DIR, f"{gun_id}.fbx")
    scene = bpy.context.scene
    cam_data = bpy.data.cameras.new("Camera")
    cam = bpy.data.objects.new("Camera", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    _frame_camera(objs)
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "OBJECT"
    scene.display.shading.show_cavity = True
    scene.display.shading.show_object_outline = True
    scene.render.resolution_x = 1000
    scene.render.resolution_y = 560
    world = bpy.data.worlds.new("World")
    world.color = (0.08, 0.09, 0.13)
    scene.world = world
    for role, obj in objs.items():
        obj.color = ROLE_COLORS.get(role, (0.8, 0.8, 0.8, 1))
    scene.render.filepath = png
    bpy.ops.render.render(write_still=True)

    bpy.ops.object.select_all(action="DESELECT")
    for obj in objs.values():
        obj.select_set(True)
    bpy.ops.export_scene.fbx(
        filepath=fbx,
        use_selection=True,
        object_types={"MESH"},
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
        use_mesh_modifiers=True,
        mesh_smooth_type="FACE",
        bake_space_transform=True,
    )
    print(f"EXPORTED {gun_id}: parts={sorted(objs)} fbx={fbx} png={png}")
