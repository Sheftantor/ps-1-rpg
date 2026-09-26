#[compute]
#version 450

// PS1 framebuffer emulation for PS1PostEffect: pixelates the frame to a low
// virtual resolution (nearest-neighbor, no smoothing), then quantizes each
// low-res pixel to a reduced color depth with 4x4 ordered dithering.
// One invocation owns one low-res pixel block, so the in-place write is race-free.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;

layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	float block_size;
	// Levels per color channel (PS1 framebuffer was 15-bit, i.e. 32 levels). 0 disables.
	float color_levels;
	float dither_strength;
	float pad0;
	float pad1;
	float pad2;
} params;

const float BAYER_4X4[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

void main() {
	ivec2 block = ivec2(gl_GlobalInvocationID.xy);
	int size = int(params.block_size);
	ivec2 raster = ivec2(params.raster_size);
	ivec2 origin = block * size;
	if (origin.x >= raster.x || origin.y >= raster.y) {
		return;
	}

	vec4 color = imageLoad(color_image, min(origin + size / 2, raster - 1));

	if (params.color_levels > 0.0) {
		// Quantize in sRGB space so banding is spread evenly like real hardware.
		// Dither is indexed by low-res pixel so the pattern is as chunky as the pixels.
		ivec2 p = block % 4;
		float threshold = (BAYER_4X4[p.y * 4 + p.x] / 16.0 - 0.5) * params.dither_strength;
		float levels = params.color_levels - 1.0;
		vec3 srgb = pow(clamp(color.rgb, 0.0, 1.0), vec3(1.0 / 2.2));
		srgb = clamp(floor(srgb * levels + 0.5 + threshold) / levels, 0.0, 1.0);
		color.rgb = pow(srgb, vec3(2.2));
	}

	for (int y = 0; y < size; y++) {
		for (int x = 0; x < size; x++) {
			ivec2 pixel = origin + ivec2(x, y);
			if (pixel.x < raster.x && pixel.y < raster.y) {
				imageStore(color_image, pixel, color);
			}
		}
	}
}
