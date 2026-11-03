shader_type canvas_item;
// Darkens the screen edges so the eye settles on the player.

uniform float strength : hint_range(0.0, 1.0) = 0.45;
uniform float radius : hint_range(0.2, 1.2) = 0.85;

void fragment() {
	float distance_from_center = distance(UV, vec2(0.5)) * 1.41421356;
	float edge = smoothstep(radius * 0.55, radius, distance_from_center);
	COLOR = vec4(0.0, 0.0, 0.0, edge * strength);
}
