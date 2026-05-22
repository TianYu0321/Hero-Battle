shader_type canvas_item;

uniform float glow_intensity : hint_range(0.0, 1.0) = 0.15;
uniform vec4 glow_color : source_color = vec4(1.0, 0.42, 0.21, 1.0);  // #FF6B35

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    
    // 只对文字边缘发光：利用文字 alpha 的导数
    float alpha = tex.a;
    float edge = alpha * (1.0 - alpha) * 4.0;  // 边缘检测近似
    edge = pow(edge, 0.5);
    
    vec3 glow = glow_color.rgb * glow_intensity * edge;
    COLOR = vec4(tex.rgb + glow, alpha);
}
