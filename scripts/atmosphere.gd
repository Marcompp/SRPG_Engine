class_name Atmosphere
extends CanvasLayer
## The HD-2D look on the map (docs/ui_theme.md): a layer between the world and the UI
## with one full-screen shader (warm-to-cool grading, slow light shafts, a vignette and
## tilt-shift blur toward the top and bottom), a soft glow under the map cursor and a
## few drifting light motes. The UI draws above it, so text stays sharp. Off when the
## "atmosphere" option is.

const SHADER := """
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float strength = 1.0;

// Tilt-shift: no blur in a band around the middle of the screen, up to `max_blur`
// pixels at the top and bottom edges.
const float FOCUS = 0.56;
const float SHARP = 0.3;
const float max_blur = 0.6;

vec3 blurred(vec2 uv, vec2 px, float radius) {
	if (radius < 0.05) {
		return texture(screen_texture, uv).rgb;
	}
	vec3 sum = texture(screen_texture, uv).rgb;
	float n = 1.0;
	for (int ring = 1; ring <= 2; ring++) {
		float r = radius * float(ring) / 2.0;
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.7853982 + float(ring) * 0.39;
			sum += texture(screen_texture, uv + vec2(cos(a), sin(a)) * r * px).rgb;
			n += 1.0;
		}
	}
	return sum / n;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float away = max(0.0, abs(uv.y - FOCUS) - SHARP) / (1.0 - FOCUS - SHARP);
	vec3 col = blurred(uv, SCREEN_PIXEL_SIZE, smoothstep(0.0, 1.0, away) * max_blur * strength);
	vec3 plain = col;
	// Grading: warm light from above, cool shade below, a touch more contrast.
	col *= mix(vec3(1.07, 1.0, 0.88), vec3(0.88, 0.93, 1.06), uv.y);
	col = mix(vec3(dot(col, vec3(0.299, 0.587, 0.114))), col, 1.08);
	col = (col - 0.5) * 1.06 + 0.5;
	// Light shafts: soft diagonal bands drifting slowly across.
	float d = uv.x + uv.y * 0.45 - TIME * 0.012;
	float shafts = pow(0.5 + 0.5 * sin(d * 9.0), 6.0) * 0.5 + pow(0.5 + 0.5 * sin(d * 4.3 + 1.7), 8.0) * 0.5;
	col += vec3(1.0, 0.86, 0.62) * shafts * 0.07 * (1.0 - uv.y * 0.6);
	// Vignette.
	vec2 c = (uv - vec2(0.5, 0.52)) * vec2(1.0, 0.82);
	col *= mix(0.6, 1.0, smoothstep(0.78, 0.3, length(c)));
	COLOR = vec4(mix(plain, clamp(col, 0.0, 1.0), strength), 1.0);
}
"""

const MOTES := 22
const GLOW_SIZE := 44.0

var cursor: Node2D
var _veil: ColorRect
var _glow: Sprite2D
var _motes: CPUParticles2D
var _time := 0.0


func _init(world_cursor: Node2D) -> void:
	layer = 1
	cursor = world_cursor
	_veil = ColorRect.new()
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.size = Vector2(240, 160)
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = SHADER
	_veil.material = material
	add_child(_veil)

	_glow = Sprite2D.new()
	_glow.texture = _soft_dot(64, Color(1.0, 0.93, 0.75))
	_glow.scale = Vector2.ONE * GLOW_SIZE / 64.0
	_glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	add_child(_glow)

	_motes = CPUParticles2D.new()
	_motes.amount = MOTES
	_motes.lifetime = 9.0
	_motes.preprocess = 9.0
	_motes.texture = _soft_dot(16, Color(1.0, 0.92, 0.7))
	_motes.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_motes.material = add
	_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_motes.emission_rect_extents = Vector2(130, 90)
	_motes.position = Vector2(120, 90)
	_motes.direction = Vector2(0.3, -1)
	_motes.spread = 25.0
	_motes.gravity = Vector2.ZERO
	_motes.initial_velocity_min = 1.5
	_motes.initial_velocity_max = 4.0
	_motes.scale_amount_min = 0.12
	_motes.scale_amount_max = 0.3
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	_motes.color_ramp = fade
	add_child(_motes)


func _process(delta: float) -> void:
	visible = Settings.value("atmosphere")
	if not visible:
		return
	_time = fmod(_time + delta, TAU)
	_glow.visible = cursor != null and cursor.is_visible_in_tree()
	if _glow.visible:
		# The cursor's cell center on screen, wherever the camera is.
		_glow.position = cursor.get_global_transform_with_canvas().origin + Vector2.ONE * BattleMap.TILE / 2.0
		_glow.modulate.a = 0.2 + 0.06 * sin(_time * 2.0)


## A round, soft-edged white dot tinted `color` (for the glow and the motes).
static func _soft_dot(size: int, color: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([color, Color(color, 0.35), Color(color, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = size
	tex.height = size
	return tex
