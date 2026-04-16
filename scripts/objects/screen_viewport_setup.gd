extends Node3D

# Wires the SubViewport render texture onto the screen quad mesh at runtime.
# Attach to the Screen node inside MicroficheReader.

@onready var viewport: SubViewport = $SubViewport
@onready var screen_mesh: MeshInstance3D = $ScreenSurface

func _ready() -> void:
	await RenderingServer.frame_post_draw
	_apply_viewport_texture()

func _apply_viewport_texture() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = viewport.get_texture()
	mat.emission_enabled = true
	mat.emission_texture = viewport.get_texture()
	mat.emission_energy_multiplier = 1.4
	mat.roughness = 0.05
	mat.metallic = 0.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen_mesh.set_surface_override_material(0, mat)
