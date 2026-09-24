// PS1-style surface shader: vertex snapping, affine texture mapping,
// per-vertex (Gouraud) lighting, and reduced color depth with ordered dithering.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, vertex_lighting;

// Per-instance flash (hit flash, attack telegraphs) set from script with
// set_instance_shader_parameter(&"flash_color", color). Alpha is strength.
instance uniform vec4 flash_color : source_color = vec4(0.0);

group_uniforms surface;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable, hint_default_white;
uniform vec2 uv_scale = vec2(1.0);
// Procedural checker overlay for untextured test geometry. 0 disables it.
uniform float checker_size : hint_range(0.0, 128.0) = 0.0;
uniform vec4 checker_color : source_color = vec4(0.6, 0.6, 0.6, 1.0);

group_uniforms ps1;
// Virtual vertical resolution that vertices snap to. Lower = more jitter.
uniform float snap_resolution : hint_range(16.0, 1080.0) = 240.0;
// 0 = perspective-correct UVs, 1 = full affine warping.
uniform float affine_strength : hint_range(0.0, 1.0) = 0.0;
// Levels per color channel (PS1 framebuffer was 15-bit, i.e. 32 levels).
uniform float color_depth : hint_range(2.0, 256.0) = 32.0;
uniform bool dithering = true;

const float BAYER_4X4[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

varying vec3 affine_uv;

void vertex() {
	UV *= uv_scale;

	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (clip.w > 0.0) {
		vec2 grid = vec2(snap_resolution * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, snap_resolution) * 0.5;
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	}
	POSITION = clip;

	// Pre-multiplying by w and dividing it back out per-fragment cancels
	// the GPU's perspective correction, giving screen-space (affine) UVs.
	affine_uv = vec3(UV * clip.w, clip.w);
}

void fragment() {
	vec2 uv = mix(UV, affine_uv.xy / affine_uv.z, affine_strength);

	vec3 color = albedo_color.rgb * texture(albedo_texture, uv).rgb;
	if (checker_size > 0.0) {
		vec2 cell = floor(uv * checker_size);
		color *= mix(vec3(1.0), checker_color.rgb, mod(cell.x + cell.y, 2.0));
	}
	color = mix(color, flash_color.rgb, flash_color.a);

	// Quantize in sRGB space so banding is spread evenly like real hardware.
	vec3 srgb = pow(color, vec3(1.0 / 2.2));
	float levels = color_depth - 1.0;
	float threshold = 0.0;
	if (dithering) {
		ivec2 p = ivec2(FRAGCOORD.xy) % 4;
		threshold = BAYER_4X4[p.y * 4 + p.x] / 16.0 - 0.5;
	}
	srgb = clamp(floor(srgb * levels + 0.5 + threshold) / levels, 0.0, 1.0);

	ALBEDO = pow(srgb, vec3(2.2));
	// Keep flashes readable on the shadowed side of the mesh.
	EMISSION = ALBEDO * flash_color.a * 0.8;
}
