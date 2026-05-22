shader_type canvas_item;

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float saturation : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D input_texture : source_color, hint_default_black;

void fragment() {
    vec4 tex = texture(input_texture, UV);
    float gray = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
    vec3 desaturated = mix(vec3(gray), tex.rgb, saturation);
    vec3 final_color = mix(desaturated, vec3(1.0), flash);
    COLOR = vec4(final_color, tex.a * COLOR.a);
}
