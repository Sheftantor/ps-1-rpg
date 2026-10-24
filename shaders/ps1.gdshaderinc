// Shared body of the PS1 surface shaders (ps1.gdshader, ps1_double_sided.gdshader).
// Snap resolution, snap strength and affine warp are global uniforms (Project
// Settings > Shader Globals), driven by res://settings/ps1_settings.tres.

// Virtual vertical resolution that vertices snap to. Lower = more jitter.
global uniform float ps1_snap_resolution;
// 0 = smooth vertices, 1 = fully locked to the virtual pixel grid.
global uniform float ps1_snap_strength;
// 0 = perspective-correct textures, 1 = PS1 affine texture mapping.
global uniform float ps1_affine_warp;

// Per-instance flash (hit flash, attack telegraphs) set from script with
// set_instance_shader_parameter(&"flash_color", color). Alpha is strength.
instance uniform vec4 flash_color : source_color = vec4(0.0);
// Per-instance color multiplier, e.g. so buildings sharing a facade material differ.
instance uniform vec4 tint : source_color = vec4(1.0);
#ifdef PS1_FADE
// Dithered fade-out (ps1_fade.gdshader only): 1 = solid, 0 = gone. Set with
// set_instance_shader_parameter(&"fade", value).
instance uniform float fade : hint_range(0.0, 1.0) = 1.0;
#endif

group_uniforms surface;
uniform vec4 albedo_color : source_color = vec4(1.0);
// Mipmapped textures pick their mip for the low virtual resolution (see
// ps1_texture_bias()); textures imported without mipmaps stay pure point-sampled.
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_enable, hint_default_white;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
// Ignore mesh UVs and project the texture onto each face from object-space
// position, so uv_scale is tiles per meter and modular pieces tile seamlessly.
uniform bool box_projection = false;
// Lock vertices to the virtual-resolution grid (PS1 wobble). Off for big flat
// ground (roads, sidewalks, road markings): its few huge triangles make the
// whole surface slide in steps, and coplanar layers snap apart and z-fight.
uniform bool vertex_snap = true;
// Fake wet-pavement sheen: brightens toward sheen_color at grazing view angles.
uniform float wet_sheen : hint_range(0.0, 2.0) = 0.0;
uniform vec4 sheen_color : source_color = vec4(0.3, 0.32, 0.38, 1.0);
// Procedural checker overlay for untextured test geometry. 0 disables it.
uniform float checker_size : hint_range(0.0, 128.0) = 0.0;
uniform vec4 checker_color : source_color = vec4(0.6, 0.6, 0.6, 1.0);

group_uniforms emission;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform sampler2D emission_texture : source_color, filter_nearest, repeat_enable, hint_default_white;
uniform float emission_energy : hint_range(0.0, 16.0) = 1.0;

// Lit windows: texels with albedo alpha 0 are glass. Each window cell (the
// texture tile split into window_grid cells) is randomly lit per object.
group_uniforms windows;
uniform float window_lit_ratio : hint_range(0.0, 1.0) = 0.0;
uniform vec2 window_grid = vec2(1.0);
uniform vec4 window_warm_color : source_color = vec4(1.0, 0.76, 0.42, 1.0);
uniform vec4 window_cool_color : source_color = vec4(0.5, 0.6, 0.64, 1.0);
uniform float window_cool_ratio : hint_range(0.0, 1.0) = 0.3;
uniform float window_energy : hint_range(0.0, 8.0) = 1.0;
// Daylight glass: unlit window texels take this colour (alpha = strength),
// each pane a little lighter or darker, like sky reflected in the glass.
uniform vec4 glass_reflect_color : source_color = vec4(0.0);

varying flat vec3 object_origin;
// UV * w and w, both perspective-interpolated: their ratio interpolates linearly
// in screen space, which is affine texture mapping.
varying vec3 affine_uv;

// The post effect keeps one screen pixel per virtual pixel, so sample textures
// as if rendering at the virtual resolution; otherwise detail finer than a
// virtual pixel (thin lane lines) flickers in and out as the camera moves.
float ps1_texture_bias(vec2 viewport_size) {
	return log2(max(1.0, viewport_size.y / ps1_snap_resolution));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	if (box_projection) {
		vec3 n = abs(NORMAL);
		if (n.y >= n.x && n.y >= n.z) {
			UV = VERTEX.xz;
		} else if (n.x >= n.z) {
			UV = vec2(-VERTEX.z * sign(NORMAL.x), -VERTEX.y);
		} else {
			UV = vec2(VERTEX.x * sign(NORMAL.z), -VERTEX.y);
		}
	}
	UV = UV * uv_scale + uv_offset;
	object_origin = MODEL_MATRIX[3].xyz;

	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (vertex_snap && clip.w > 0.0) {
		vec2 grid = vec2(ps1_snap_resolution * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, ps1_snap_resolution) * 0.5;
		vec2 snapped = round(clip.xy / clip.w * grid) / grid * clip.w;
		clip.xy = mix(clip.xy, snapped, ps1_snap_strength);
	}
	POSITION = clip;
	affine_uv = vec3(UV * clip.w, clip.w);
}

void fragment() {
	vec2 uv = ps1_affine_warp > 0.0 ? mix(UV, affine_uv.xy / affine_uv.z, ps1_affine_warp) : UV;

	vec4 albedo_tex = texture(albedo_texture, uv, ps1_texture_bias(VIEWPORT_SIZE));
	vec3 color = albedo_color.rgb * albedo_tex.rgb * tint.rgb;
	if (checker_size > 0.0) {
		vec2 cell = floor(uv * checker_size);
		color *= mix(vec3(1.0), checker_color.rgb, mod(cell.x + cell.y, 2.0));
	}
	if (glass_reflect_color.a > 0.0 && albedo_tex.a < 0.5) {
		vec2 pane = floor(uv * window_grid) + object_origin.xz * 0.731 + object_origin.y;
		vec3 sky = glass_reflect_color.rgb * mix(0.78, 1.12, hash(pane + 5.0));
		color = mix(color, sky * tint.rgb, glass_reflect_color.a);
	}
	ALBEDO = mix(color, flash_color.rgb, flash_color.a);

	vec3 emission = emission_color.rgb * texture(emission_texture, uv).rgb * emission_energy;
	if (window_lit_ratio > 0.0 && albedo_tex.a < 0.5) {
		vec2 window = floor(uv * window_grid) + object_origin.xz * 0.731 + object_origin.y;
		if (hash(window) < window_lit_ratio) {
			float variant = hash(window + 17.0);
			vec3 light = variant < window_cool_ratio ? window_cool_color.rgb : window_warm_color.rgb;
			emission += light * window_energy * mix(0.55, 1.0, hash(window + 31.0));
		}
	}
	if (wet_sheen > 0.0) {
		float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
		emission += sheen_color.rgb * fresnel * wet_sheen;
	}
	// Keep flashes readable on the shadowed side of the mesh.
	EMISSION = mix(emission, ALBEDO * 0.8, flash_color.a);
#ifdef PS1_FADE
	// Screen-door transparency on a 4x4 ordered dither, one cell per virtual
	// pixel: stays opaque (no sorting) and reads as a PS1 fade.
	const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
			3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	ivec2 cell = ivec2(floor(FRAGCOORD.xy / max(1.0, VIEWPORT_SIZE.y / ps1_snap_resolution))) % 4;
	if (fade < (BAYER[cell.y * 4 + cell.x] + 0.5) / 16.0) {
		discard;
	}
#endif
}
