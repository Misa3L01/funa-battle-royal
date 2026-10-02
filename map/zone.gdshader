// Pared de "La Inflación": franjas que suben y se desvanecen hacia arriba.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform vec4 color : source_color = vec4(0.85, 0.2, 0.95, 0.45);

void fragment() {
	float stripes = step(0.5, fract(UV.x * 60.0 - TIME * 0.4));
	float bands = 0.5 + 0.5 * sin((UV.y * 30.0) + TIME * 3.0);
	float fade = smoothstep(0.0, 0.6, UV.y);
	ALBEDO = color.rgb * (0.7 + 0.3 * stripes);
	ALPHA = color.a * fade * (0.55 + 0.25 * stripes + 0.2 * bands);
}
