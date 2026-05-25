shader_type canvas_item;

uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform bool use_texture = false;
uniform sampler2D mask_texture : repeat_disable, filter_linear;
uniform int shape_type : hint_range(0, 4) = 0;
// 0=circle, 1=diamond, 2=horizontal, 3=vertical, 4=curtains
uniform bool reverse = false;

float get_procedural_mask(vec2 uv) {
	vec2 centered = uv - vec2(0.5);
	float dist = 0.0;
	
	if (shape_type == 0) {
		// circle: distance from center
		dist = length(centered);
		return smoothstep(0.0, 0.71, dist);
	} else if (shape_type == 1) {
		// diamond: manhattan distance
		dist = abs(centered.x) + abs(centered.y);
		return smoothstep(0.0, 1.0, dist);
	} else if (shape_type == 2) {
		// horizontal wipe: left to right
		return uv.x;
	} else if (shape_type == 3) {
		// vertical wipe: top to bottom
		return uv.y;
	} else if (shape_type == 4) {
		// curtains: open from center horizontally with wave
		float wave = sin(centered.y * 12.0) * 0.04;
		float dist = abs(centered.x + wave);
		return smoothstep(0.0, 0.54, dist);
	}
	
	return 0.0;
}

void fragment() {
	float mask;
	
	if (use_texture) {
		mask = texture(mask_texture, UV).r;
	} else {
		mask = get_procedural_mask(UV);
	}
	
	// progress=0 -> all transparent (alpha=0)
	// progress=1 -> all opaque (alpha=1)
	// mask值小的区域先出现/先消失
	float alpha = step(mask, progress);
	if (reverse) {
		alpha = 1.0 - alpha;
	}
	COLOR = vec4(color.rgb, alpha * color.a);
}
