@tool
extends Node3D

# Procedural semicircle desk surface.
#
# Builds a ring sector that wraps the seated player. The ring is centered on
# this node's local origin. The player sits at the local origin, desk surface
# at Y=0 (node is offset in Y in the scene).
#
# Shape:
#   - Inner radius of the arc (cut-out where the player's knees are)
#   - Outer radius of the arc (front edge of the desk)
#   - Arc spans from -sweep_half to +sweep_half around local +Z axis
#     (yaw = 0° points at world +Z; scene rotates the node so forward = -Z)
#   - Top surface + a short fascia (drop) on the front outer edge
#
# Geometry is regenerated in _ready(). Also runs in-editor via @tool.

@export var inner_radius: float = 0.48
@export var outer_radius: float = 1.12
@export var sweep_half_degrees: float = 100.0
@export var segments: int = 32
@export var desk_thickness: float = 0.04  # slab thickness so the edge reads as a physical object
@export var fascia_drop: float = 0.32  # height of the front skirt below the top
@export var top_material: Material
@export var fascia_material: Material

@onready var top_mesh: MeshInstance3D = $TopMesh
@onready var bottom_mesh: MeshInstance3D = $BottomMesh
@onready var inner_rim_mesh: MeshInstance3D = $InnerRimMesh
@onready var fascia_mesh: MeshInstance3D = $FasciaMesh
@onready var shape: CollisionShape3D = $StaticBody3D/Shape

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	var top_array := _build_top_arraymesh()
	top_mesh.mesh = top_array
	if top_material:
		top_mesh.material_override = top_material

	bottom_mesh.mesh = _build_bottom_arraymesh()
	if top_material:
		bottom_mesh.material_override = top_material

	inner_rim_mesh.mesh = _build_inner_rim_arraymesh()
	if fascia_material:
		inner_rim_mesh.material_override = fascia_material

	var fas := _build_fascia_arraymesh()
	fascia_mesh.mesh = fas
	if fascia_material:
		fascia_mesh.material_override = fascia_material

	# Collision: flat box across the top surface (matches the arc footprint).
	var col := ConcavePolygonShape3D.new()
	col.set_faces(_build_top_collision_faces())
	shape.shape = col

func _arc_point(radius: float, angle_deg: float, y: float) -> Vector3:
	var a := deg_to_rad(angle_deg)
	return Vector3(sin(a) * radius, y, -cos(a) * radius)

# ── Top surface: ring sector as a triangle strip ─────────────────────────────
func _build_top_arraymesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := (sweep_half_degrees * 2.0) / float(segments)
	for i in segments:
		var a0 := -sweep_half_degrees + step * i
		var a1 := -sweep_half_degrees + step * (i + 1)
		var p_in0  := _arc_point(inner_radius, a0, 0.0)
		var p_out0 := _arc_point(outer_radius, a0, 0.0)
		var p_in1  := _arc_point(inner_radius, a1, 0.0)
		var p_out1 := _arc_point(outer_radius, a1, 0.0)
		# Two tris per segment
		_tri(st, p_in0, p_out0, p_in1, Vector3.UP)
		_tri(st, p_in1, p_out0, p_out1, Vector3.UP)
	return st.commit()

# ── Bottom surface: mirror of the top at y = -desk_thickness, flipped winding ──
func _build_bottom_arraymesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := (sweep_half_degrees * 2.0) / float(segments)
	var y := -desk_thickness
	for i in segments:
		var a0 := -sweep_half_degrees + step * i
		var a1 := -sweep_half_degrees + step * (i + 1)
		var p_in0  := _arc_point(inner_radius, a0, y)
		var p_out0 := _arc_point(outer_radius, a0, y)
		var p_in1  := _arc_point(inner_radius, a1, y)
		var p_out1 := _arc_point(outer_radius, a1, y)
		# Reverse winding so the bottom faces down.
		_tri(st, p_in0, p_in1, p_out0, Vector3.DOWN)
		_tri(st, p_in1, p_out1, p_out0, Vector3.DOWN)
	return st.commit()

# ── Inner rim: vertical ring on the inner arc between y=0 and y=-desk_thickness ──
func _build_inner_rim_arraymesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := (sweep_half_degrees * 2.0) / float(segments)
	for i in segments:
		var a0 := -sweep_half_degrees + step * i
		var a1 := -sweep_half_degrees + step * (i + 1)
		var top0 := _arc_point(inner_radius, a0, 0.0)
		var top1 := _arc_point(inner_radius, a1, 0.0)
		var bot0 := _arc_point(inner_radius, a0, -desk_thickness)
		var bot1 := _arc_point(inner_radius, a1, -desk_thickness)
		# Normal points radially inward (toward the player): -arc_point direction at XY,
		# since top positions on the inner arc are (sin*r, 0, -cos*r) — the inward
		# radial direction is the negative of that flattened to Y=0.
		var n := Vector3(-top0.x, 0.0, -top0.z).normalized()
		# Winding so the front face is inward-facing.
		_tri(st, top0, bot0, top1, n)
		_tri(st, top1, bot0, bot1, n)
	return st.commit()

# ── Front fascia: a curved skirt on the outer edge dropping by fascia_drop ──
func _build_fascia_arraymesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := (sweep_half_degrees * 2.0) / float(segments)
	for i in segments:
		var a0 := -sweep_half_degrees + step * i
		var a1 := -sweep_half_degrees + step * (i + 1)
		var top0  := _arc_point(outer_radius, a0, 0.0)
		var top1  := _arc_point(outer_radius, a1, 0.0)
		var bot0  := _arc_point(outer_radius, a0, -fascia_drop)
		var bot1  := _arc_point(outer_radius, a1, -fascia_drop)
		var n := (top1 - top0).cross(bot0 - top0).normalized()
		_tri(st, top0, top1, bot0, n)
		_tri(st, top1, bot1, bot0, n)
	return st.commit()

func _build_top_collision_faces() -> PackedVector3Array:
	var out := PackedVector3Array()
	var step := (sweep_half_degrees * 2.0) / float(segments)
	for i in segments:
		var a0 := -sweep_half_degrees + step * i
		var a1 := -sweep_half_degrees + step * (i + 1)
		var p_in0  := _arc_point(inner_radius, a0, 0.0)
		var p_out0 := _arc_point(outer_radius, a0, 0.0)
		var p_in1  := _arc_point(inner_radius, a1, 0.0)
		var p_out1 := _arc_point(outer_radius, a1, 0.0)
		out.append(p_in0); out.append(p_out0); out.append(p_in1)
		out.append(p_in1); out.append(p_out0); out.append(p_out1)
	return out

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	st.set_normal(normal); st.add_vertex(a)
	st.set_normal(normal); st.add_vertex(b)
	st.set_normal(normal); st.add_vertex(c)
