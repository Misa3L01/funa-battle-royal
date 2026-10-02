// Skin legendaria: colores que cambian con el tiempo.
shader_type spatial;

void fragment() {
	vec3 color = 0.5 + 0.5 * cos(TIME * 1.5 + UV.xyx * 6.0 + vec3(0.0, 2.0, 4.0));
	ALBEDO = color;
	EMISSION = color * 0.8;
	METALLIC = 0.4;
	ROUGHNESS = 0.2;
}
