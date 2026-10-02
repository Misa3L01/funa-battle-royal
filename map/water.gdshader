// Agua: color según profundidad, espuma en la orilla y ondas suaves.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 shallow_color : source_color = vec3(0.25, 0.8, 0.82);
uniform vec3 deep_color : source_color = vec3(0.03, 0.22, 0.45);
uniform float depth_fade = 5.0;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	behind.xyz /= behind.w;
	float water_depth = clamp((VERTEX.z - behind.z) / depth_fade, 0.0, 1.0);
	float foam = 1.0 - smoothstep(0.0, 0.08, water_depth);
	vec3 world_position = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float ripple = sin(world_position.x * 0.35 + TIME * 1.2) * sin(world_position.z * 0.3 + TIME * 0.9);
	ALBEDO = mix(shallow_color, deep_color, water_depth) + vec3(foam * 0.7) + vec3(ripple * 0.02);
	ALPHA = mix(0.5, 0.93, water_depth);
	ROUGHNESS = 0.08;
	SPECULAR = 0.6;
	NORMAL = normalize(NORMAL + vec3(ripple * 0.06, 0.0, ripple * 0.06));
}
