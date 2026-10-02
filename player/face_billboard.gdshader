// Cara garabato: siempre mira a la cámara (billboard que respeta la escala)
// y se adelanta un poco hacia la cámara para no cortarse con el cuerpo.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D face_texture : source_color, filter_linear_mipmap;
uniform float push_toward_camera = 0.2;
// 0..1: destello blanco al recibir un golpe.
uniform float flash = 0.0;

void vertex() {
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * scale.x,
		INV_VIEW_MATRIX[1] * scale.y,
		INV_VIEW_MATRIX[2] * scale.z,
		MODEL_MATRIX[3]);
	vec4 view_position = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view_position.z += push_toward_camera;
	POSITION = PROJECTION_MATRIX * view_position;
}

void fragment() {
	vec4 color = texture(face_texture, UV);
	ALBEDO = mix(color.rgb, vec3(1.0), flash);
	ALPHA = color.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
