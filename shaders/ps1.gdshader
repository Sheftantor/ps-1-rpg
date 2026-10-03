// PS1-style surface shader: vertex snapping, perspective-correct texture mapping and
// per-vertex (Gouraud) lighting. Reduced color depth happens on
// the whole frame in res://scripts/rendering/ps1_post_effect.gd.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, vertex_lighting;

#include "res://shaders/ps1.gdshaderinc"
