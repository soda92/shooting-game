#!/usr/bin/env python3
"""Build a stylized anime character in Blender and export it as GLB.

Usage:
    blender -b -P tools/make_anime_skin.py

Outputs:
    assets/models/anime_pink.glb
    /tmp/opencode/anime_front.png, anime_side.png, anime_run.png

The character is built from smooth primitives with rigid vertex weights,
a small humanoid armature and three actions: Idle, Run, Aim.
"""

import math
import os

import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "models")
PREVIEW_DIR = "/tmp/opencode"
os.makedirs(OUT_DIR, exist_ok=True)

FPS = 30


# --------------------------------------------------------------------------
# scene / materials
# --------------------------------------------------------------------------

def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 61


def make_mat(name, rgb, rough=0.85):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.diffuse_color = (*rgb, 1.0)  # Workbench preview color
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    if bsdf is not None:
        bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Metallic"].default_value = 0.0
    return m


MATS = {}


def build_materials():
    MATS["skin"] = make_mat("Skin", (1.00, 0.82, 0.75))
    MATS["hair"] = make_mat("Hair", (1.00, 0.55, 0.72))
    MATS["blouse"] = make_mat("Blouse", (0.98, 0.98, 1.00))
    MATS["skirt"] = make_mat("Skirt", (0.10, 0.12, 0.26))
    MATS["socks"] = make_mat("Socks", (0.07, 0.07, 0.09))
    MATS["shoe"] = make_mat("Shoe", (0.95, 0.95, 0.97))
    MATS["eye"] = make_mat("EyeWhite", (0.98, 0.98, 1.00))
    MATS["iris"] = make_mat("Iris", (0.15, 0.45, 0.78))
    MATS["pupil"] = make_mat("Pupil", (0.03, 0.04, 0.07))
    MATS["brow"] = make_mat("Brow", (0.55, 0.25, 0.35))
    MATS["ribbon"] = make_mat("Ribbon", (0.80, 0.14, 0.22))
    MATS["gun"] = make_mat("Gun", (0.10, 0.11, 0.14))


# --------------------------------------------------------------------------
# geometry helpers
# --------------------------------------------------------------------------

PARTS = []


def finish_part(obj, mat, bone, smooth=True):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    if smooth:
        bpy.ops.object.shade_smooth()

    vg = obj.vertex_groups.new(name=bone)
    vg.add([v.index for v in obj.data.vertices], 1.0, "REPLACE")
    PARTS.append(obj)
    return obj


def sphere(name, loc, scale, mat, bone, segments=24, rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=segments, ring_count=rings, radius=1.0, location=loc
    )
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    return finish_part(obj, mat, bone)


def cone_between(name, p0, p1, r0, r1, mat, bone, verts=16):
    a = Vector(p0)
    b = Vector(p1)
    vec = b - a
    length = vec.length
    bpy.ops.mesh.primitive_cone_add(
        vertices=verts,
        radius1=r0,
        radius2=r1,
        depth=length,
        end_fill_type="NGON",
        location=(a + b) * 0.5,
    )
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = vec.to_track_quat("Z", "Y")
    return finish_part(obj, mat, bone)


def cylinder(name, loc, radius, depth, mat, bone, verts=16):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=verts, radius=radius, depth=depth, location=loc
    )
    obj = bpy.context.object
    obj.name = name
    return finish_part(obj, mat, bone)


def box(name, loc, size, mat, bone, bevel=0.0, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    obj.scale = size
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0.0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish_part(obj, mat, bone)


def torus(name, loc, major, minor, mat, bone, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major,
        minor_radius=minor,
        major_segments=20,
        minor_segments=8,
        location=loc,
        rotation=rot,
    )
    obj = bpy.context.object
    obj.name = name
    return finish_part(obj, mat, bone)


# --------------------------------------------------------------------------
# character
# --------------------------------------------------------------------------

def build_character():
    # torso / skirt
    cone_between("Torso", (0, 0, 0.98), (0, 0, 1.40), 0.13, 0.15, MATS["blouse"], "chest", 20)
    cone_between("Waist", (0, 0, 0.93), (0, 0, 1.00), 0.12, 0.13, MATS["blouse"], "spine", 20)
    cone_between("Skirt", (0, 0, 0.74), (0, 0, 1.00), 0.30, 0.15, MATS["skirt"], "hips", 24)
    sphere("Hips", (0, 0, 0.94), (0.15, 0.13, 0.10), MATS["skirt"], "hips")
    cylinder("Collar", (0, 0, 1.415), 0.066, 0.030, MATS["blouse"], "chest", 16)

    # neck / head
    cylinder("Neck", (0, 0, 1.435), 0.045, 0.09, MATS["skin"], "neck", 12)
    sphere("Head", (0, 0, 1.58), (0.150, 0.155, 0.160), MATS["skin"], "head", 32, 20)

    # face
    for side in (-1, 1):
        x = side * 0.055
        sphere("EyeWhite" + str(side), (x, -0.145, 1.585), (0.045, 0.018, 0.048), MATS["eye"], "head")
        sphere("Iris" + str(side), (x, -0.159, 1.585), (0.030, 0.008, 0.034), MATS["iris"], "head")
        sphere("Pupil" + str(side), (x, -0.164, 1.585), (0.015, 0.005, 0.020), MATS["pupil"], "head")
        sphere("Shine" + str(side), (x - side * 0.010, -0.167, 1.603), (0.008, 0.004, 0.008), MATS["eye"], "head")
        box("Brow" + str(side), (x, -0.153, 1.650), (0.060, 0.012, 0.012), MATS["brow"], "head", rot=(0, side * 0.12, 0))

    box("Mouth", (0, -0.158, 1.512), (0.035, 0.008, 0.006), MATS["pupil"], "head")

    # hair: cap, back, bangs, side locks
    sphere("HairCap", (0, 0.020, 1.610), (0.172, 0.170, 0.175), MATS["hair"], "head", 28, 18)
    sphere("HairBack", (0, 0.060, 1.540), (0.160, 0.140, 0.185), MATS["hair"], "head", 24, 16)
    for i in range(7):
        x = -0.12 + i * 0.04
        cone_between(
            "Bang" + str(i),
            (x, -0.150, 1.685),
            (x * 1.08, -0.168, 1.620),
            0.022, 0.005, MATS["hair"], "head", 8,
        )
    for side in (-1, 1):
        box("SideLock" + str(side), (side * 0.150, -0.020, 1.500), (0.050, 0.060, 0.220), MATS["hair"], "head")

    # twin tails
    for side in (-1, 1):
        sphere("TailBase" + str(side), (side * 0.160, 0.045, 1.665), (0.052, 0.052, 0.052), MATS["hair"], "head")
        torus("TailTie" + str(side), (side * 0.165, 0.050, 1.650), 0.045, 0.012, MATS["ribbon"], "head", rot=(0, math.pi / 2, 0))
        cone_between(
            "Tail" + str(side),
            (side * 0.175, 0.055, 1.650),
            (side * 0.300, 0.080, 1.120),
            0.060, 0.018, MATS["hair"], "head", 14,
        )

    # ribbon at the collar
    box("RibbonKnot", (0, -0.170, 1.330), (0.050, 0.025, 0.045), MATS["ribbon"], "chest")
    for side in (-1, 1):
        box("RibbonBow" + str(side), (side * 0.055, -0.166, 1.330), (0.060, 0.022, 0.040), MATS["ribbon"], "chest", rot=(0, 0, side * 0.45))

    # arms
    for side in (-1, 1):
        tag = "L" if side > 0 else "R"
        x = side * 0.160
        sphere("Shoulder" + tag, (side * 0.125, 0, 1.355), (0.068, 0.065, 0.068), MATS["blouse"], "shoulder." + tag)
        cone_between("UpperArm" + tag, (x, 0, 1.345), (x, 0, 1.100), 0.052, 0.045, MATS["blouse"], "upper_arm." + tag, 14)
        cylinder("Sleeve" + tag, (x, 0, 1.300), 0.060, 0.075, MATS["blouse"], "upper_arm." + tag, 14)
        sphere("Elbow" + tag, (x, 0, 1.100), (0.048, 0.048, 0.048), MATS["skin"], "upper_arm." + tag)
        cone_between("Forearm" + tag, (x, 0, 1.100), (x, 0, 0.880), 0.042, 0.032, MATS["skin"], "forearm." + tag, 14)
        sphere("Hand" + tag, (x, 0, 0.855), (0.042, 0.036, 0.058), MATS["skin"], "hand." + tag)

    # legs
    for side in (-1, 1):
        tag = "L" if side > 0 else "R"
        x = side * 0.100
        cone_between("Thigh" + tag, (x, 0, 0.940), (x, 0, 0.550), 0.078, 0.058, MATS["skin"], "thigh." + tag, 14)
        sphere("Knee" + tag, (x, 0, 0.550), (0.058, 0.058, 0.058), MATS["skin"], "thigh." + tag)
        cone_between("Shin" + tag, (x, 0, 0.550), (x, 0, 0.130), 0.056, 0.040, MATS["socks"], "shin." + tag, 14)
        cylinder("SockTop" + tag, (x, 0, 0.545), 0.060, 0.025, MATS["eye"], "shin." + tag, 14)
        sphere("Ankle" + tag, (x, 0, 0.130), (0.045, 0.045, 0.045), MATS["socks"], "shin." + tag)
        box("Shoe" + tag, (x, -0.035, 0.060), (0.105, 0.220, 0.105), MATS["shoe"], "foot." + tag, bevel=0.025)

    # pistol in the right hand (points down when idle, forward when aiming)
    box("GunSlide", (-0.160, -0.020, 0.780), (0.040, 0.070, 0.160), MATS["gun"], "hand.R", bevel=0.008)
    box("GunGrip", (-0.160, -0.045, 0.715), (0.035, 0.055, 0.090), MATS["gun"], "hand.R", bevel=0.006)


# --------------------------------------------------------------------------
# armature
# --------------------------------------------------------------------------

def build_armature():
    bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
    arm = bpy.context.object
    arm.name = "Rig"
    arm.data.name = "Rig"

    eb = arm.data.edit_bones
    for b in list(eb):
        eb.remove(b)

    def bone(name, head, tail, parent=None):
        b = eb.new(name)
        b.head = head
        b.tail = tail
        b.use_deform = True
        if parent:
            b.parent = eb[parent]
        return b

    bone("hips", (0, 0, 0.950), (0, 0, 1.020))
    bone("spine", (0, 0, 1.020), (0, 0, 1.220), "hips")
    bone("chest", (0, 0, 1.220), (0, 0, 1.400), "spine")
    bone("neck", (0, 0, 1.400), (0, 0, 1.470), "chest")
    bone("head", (0, 0, 1.470), (0, 0, 1.760), "neck")

    for side in (-1, 1):
        tag = "L" if side > 0 else "R"
        x = side * 0.160
        bone("shoulder." + tag, (side * 0.030, 0, 1.350), (side * 0.120, 0, 1.350), "chest")
        bone("upper_arm." + tag, (x, 0, 1.345), (x, 0, 1.100), "shoulder." + tag)
        bone("forearm." + tag, (x, 0, 1.100), (x, 0, 0.880), "upper_arm." + tag)
        bone("hand." + tag, (x, 0, 0.880), (x, 0, 0.820), "forearm." + tag)
        bone("thigh." + tag, (side * 0.100, 0, 0.940), (side * 0.100, 0, 0.550), "hips")
        bone("shin." + tag, (side * 0.100, 0, 0.550), (side * 0.100, 0, 0.130), "thigh." + tag)
        bone("foot." + tag, (side * 0.100, 0, 0.130), (side * 0.100, -0.170, 0.050), "shin." + tag)

    bpy.ops.object.mode_set(mode="OBJECT")

    return arm


def join_and_bind(arm):
    bpy.ops.object.select_all(action="DESELECT")
    for p in PARTS:
        p.select_set(True)
    bpy.context.view_layer.objects.active = PARTS[0]
    bpy.ops.object.join()
    mesh = bpy.context.object
    mesh.name = "AnimeSkin"

    mesh.parent = arm
    mod = mesh.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    return mesh


# --------------------------------------------------------------------------
# animations
# --------------------------------------------------------------------------

def make_action(arm, name, length, keys):
    """keys: list of (frame, {bone: (rx,ry,rz)})"""
    act = bpy.data.actions.new(name)
    act.use_fake_user = True

    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = act

    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"

    for frame, pose in keys:
        for bone_name, rot in pose.items():
            pb = arm.pose.bones[bone_name]
            pb.rotation_euler = rot
            pb.keyframe_insert("rotation_euler", frame=frame)

    act.frame_start = 1
    act.frame_end = length
    return act


def build_animations(arm):
    make_action(arm, "Idle", 61, [
        (1, {
            "chest": (0.02, 0, 0),
            "head": (0.01, 0, 0),
            "upper_arm.L": (0.02, 0, 0.02),
            "upper_arm.R": (0.02, 0, -0.02),
        }),
        (31, {
            "chest": (-0.02, 0, 0),
            "head": (-0.01, 0, 0),
            "upper_arm.L": (-0.02, 0, 0.02),
            "upper_arm.R": (-0.02, 0, -0.02),
        }),
        (61, {
            "chest": (0.02, 0, 0),
            "head": (0.01, 0, 0),
            "upper_arm.L": (0.02, 0, 0.02),
            "upper_arm.R": (0.02, 0, -0.02),
        }),
    ])

    make_action(arm, "Run", 31, [
        (1, {
            "thigh.L": (0.65, 0, 0),
            "thigh.R": (-0.55, 0, 0),
            "shin.L": (-0.55, 0, 0),
            "shin.R": (0.05, 0, 0),
            "upper_arm.L": (-0.70, 0, 0.05),
            "upper_arm.R": (0.70, 0, -0.05),
            "forearm.L": (-0.35, 0, 0),
            "forearm.R": (-0.20, 0, 0),
            "chest": (0.08, 0, 0),
        }),
        (16, {
            "thigh.L": (-0.55, 0, 0),
            "thigh.R": (0.65, 0, 0),
            "shin.L": (0.05, 0, 0),
            "shin.R": (-0.55, 0, 0),
            "upper_arm.L": (0.70, 0, 0.05),
            "upper_arm.R": (-0.70, 0, -0.05),
            "forearm.L": (-0.20, 0, 0),
            "forearm.R": (-0.35, 0, 0),
            "chest": (0.08, 0, 0),
        }),
        (31, {
            "thigh.L": (0.65, 0, 0),
            "thigh.R": (-0.55, 0, 0),
            "shin.L": (-0.55, 0, 0),
            "shin.R": (0.05, 0, 0),
            "upper_arm.L": (-0.70, 0, 0.05),
            "upper_arm.R": (0.70, 0, -0.05),
            "forearm.L": (-0.35, 0, 0),
            "forearm.R": (-0.20, 0, 0),
            "chest": (0.08, 0, 0),
        }),
    ])

    make_action(arm, "Aim", 2, [
        (1, {
            "upper_arm.L": (-1.40, 0, 0.12),
            "upper_arm.R": (-1.40, 0, -0.12),
            "forearm.L": (-0.15, 0, 0),
            "forearm.R": (-0.15, 0, 0),
            "chest": (0.05, 0, 0),
            "head": (0.02, 0, 0),
        }),
    ])

    # leave Idle active for the preview
    arm.animation_data.action = bpy.data.actions["Idle"]


# --------------------------------------------------------------------------
# preview / export
# --------------------------------------------------------------------------

def setup_camera():
    bpy.ops.object.camera_add(location=(0, -3.6, 1.05))
    cam = bpy.context.object
    cam.data.lens = 60

    target = bpy.data.objects.new("CamTarget", None)
    bpy.context.scene.collection.objects.link(target)
    target.location = (0, 0, 0.95)

    con = cam.constraints.new("TRACK_TO")
    con.target = target
    con.track_axis = "TRACK_NEGATIVE_Z"
    con.up_axis = "UP_Y"
    bpy.context.scene.camera = cam
    return cam, target


def render_preview(path, cam_pos, target_pos, frame=1):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = 600
    scene.render.resolution_y = 800
    scene.render.film_transparent = False
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.display.shading.cavity_type = "WORLD"

    cam = scene.camera
    cam.location = cam_pos
    cam.constraints[0].target.location = target_pos

    scene.frame_set(frame)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def export_glb():
    out = os.path.join(OUT_DIR, "anime_pink.glb")
    bpy.ops.export_scene.gltf(
        filepath=out,
        export_format="GLB",
        use_selection=False,
        export_cameras=False,
        export_lights=False,
        export_apply=False,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_anim_single_armature=True,
        export_optimize_animation_size=True,
        export_yup=True,
    )
    print("EXPORTED", out)


def set_action(arm, name):
    act = bpy.data.actions[name]
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = act
    if hasattr(act, "slots") and len(act.slots) > 0:
        arm.animation_data.action_slot = act.slots[0]


def main():
    reset_scene()
    build_materials()
    build_character()
    arm = build_armature()
    join_and_bind(arm)
    build_animations(arm)
    setup_camera()

    render_preview(os.path.join(PREVIEW_DIR, "anime_front.png"), (0, -3.6, 1.05), (0, 0, 0.95), 1)
    render_preview(os.path.join(PREVIEW_DIR, "anime_side.png"), (2.7, -2.4, 1.25), (0, 0, 0.95), 1)

    set_action(arm, "Run")
    render_preview(os.path.join(PREVIEW_DIR, "anime_run.png"), (2.7, -2.4, 1.25), (0, 0, 0.95), 4)

    set_action(arm, "Aim")
    render_preview(os.path.join(PREVIEW_DIR, "anime_aim.png"), (2.4, -2.8, 1.20), (0, 0, 1.05), 1)

    set_action(arm, "Idle")
    export_glb()


if __name__ == "__main__":
    main()
