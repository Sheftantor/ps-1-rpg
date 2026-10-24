// ps1.gdshader with a dithered fade-out (instance uniform `fade`): swapped onto
// a dead enemy's model as its corpse fades away (res://scripts/enemy/states/dead.gd).
// Kept separate so the discard doesn't cost every other PS1 surface.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, vertex_lighting;

#define PS1_FADE
#include "res://shaders/ps1.gdshaderinc"
