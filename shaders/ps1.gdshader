// PS1-style surface shader: vertex snapping, affine texture mapping and
// per-vertex (Gouraud) lighting. Reduced color depth and dithering happen on
// the whole frame in res://scripts/rendering/ps1_post_effect.gd.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, vertex_lighting;

#include "res://shaders/ps1.gdshaderinc"
