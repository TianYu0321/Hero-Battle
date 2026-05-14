shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform vec4 color_low : source_color = vec4(1.0, 0.0, 0.0, 1.0);   // 红色（低血量）
uniform vec4 color_mid : source_color = vec4(1.0, 0.84, 0.0, 1.0);  // 黄色（中血量）
uniform vec4 color_high : source_color = vec4(0.2, 0.8, 0.3, 1.0);  // 绿色（高血量）
uniform float flash_speed : hint_range(0.0, 10.0) = 0.0;  // 低血量闪烁速度

void fragment() {
    vec2 uv = UV;
    
    // 根据进度裁剪
    if (uv.x > progress) {
        discard;
    }
    
    // 颜色渐变：红→黄→绿
    vec4 final_color;
    if (progress < 0.3) {
        final_color = mix(color_low, color_mid, progress / 0.3);
    } else {
        final_color = mix(color_mid, color_high, (progress - 0.3) / 0.7);
    }
    
    // 低血量闪烁
    if (progress < 0.3 && flash_speed > 0.0) {
        float flash = abs(sin(TIME * flash_speed));
        final_color = mix(final_color, vec4(1.0, 1.0, 1.0, 1.0), flash * 0.3);
    }
    
    COLOR = final_color;
}
