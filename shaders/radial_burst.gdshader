shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 aura_color : source_color = vec4(0.90, 0.75, 0.35, 0.6);
uniform vec2 center = vec2(0.5, 0.5);

void fragment() {
    float dist = distance(UV, center);
    float ring = smoothstep(progress - 0.1, progress, dist) 
               * smoothstep(progress + 0.2, progress, dist);
    float alpha = aura_color.a * ring * (1.0 - progress);
    COLOR = vec4(aura_color.rgb, alpha);
}
