// Mareo (puro de Smoke Dogg, Nube Verde): la pantalla ondula y se tiñe.
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.55, 1.0, 0.45, 1.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	uv.x += sin(uv.y * 12.0 + TIME * 3.0) * 0.012 * intensity;
	uv.y += cos(uv.x * 10.0 + TIME * 2.3) * 0.012 * intensity;
	vec3 color = texture(screen_texture, uv).rgb;
	vec3 ghost = texture(screen_texture, uv + vec2(0.01, 0.0) * intensity).rgb;
	color = mix(color, (color + ghost) * 0.5, intensity * 0.6);
	COLOR = vec4(mix(color, color * tint.rgb, intensity * 0.5), 1.0);
}
