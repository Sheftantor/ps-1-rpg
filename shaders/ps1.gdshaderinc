// Shared body of the PS1 surface shaders (ps1.gdshader, ps1_double_sided.gdshader).
// Snap/affine strength are global uniforms (Project Settings > Shader Globals).

// Virtual vertical resolution that vertices snap to. Lower = more jitter.
global uniform float ps1_snap_resolution;
// 0 = perspective-correct UVs, 1 = full affine warping.
global uniform float ps1_affine_strength;

// Per-instance flash (hit flash, attack telegraphs) set from script with
// set_instance_shader_parameter(&"flash_color", color). Alpha is strength.
instance uniform vec4 flash_color : source_color = vec4(0.0);
// Per-instance color multiplier, e.g. so buildings sharing a facade material differ.
instance uniform vec4 tint : source_color = vec4(1.0);

group_uniforms surface;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable, hint_default_white;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
// Ignore mesh UVs and project the texture onto each face from object-space
// position, so uv_scale is tiles per meter and modular pieces tile seamlessly.
uniform bool box_projection = false;
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

varying vec3 affine_uv;
varying flat vec3 object_origin;

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
	if (clip.w > 0.0) {
		vec2 grid = vec2(ps1_snap_resolution * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, ps1_snap_resolution) * 0.5;
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	}
	POSITION = clip;

	// Pre-multiplying by w and dividing it back out per-fragment cancels
	// the GPU's perspective correction, giving screen-space (affine) UVs.
	affine_uv = vec3(UV * clip.w, clip.w);
}

void fragment() {
	vec2 uv = mix(UV, affine_uv.xy / affine_uv.z, ps1_affine_strength);

	vec4 albedo_tex = texture(albedo_texture, uv);
	vec3 color = albedo_color.rgb * albedo_tex.rgb * tint.rgb;
	if (checker_size > 0.0) {
		vec2 cell = floor(uv * checker_size);
		color *= mix(vec3(1.0), checker_color.rgb, mod(cell.x + cell.y, 2.0));
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
}
