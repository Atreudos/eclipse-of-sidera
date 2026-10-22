shader_type canvas_item;
render_mode blend_add;
// Parry dalgası: beyaz çekirdekli, sarı kenarlı genişleyen halka + içinde yumuşak ışıma.
// Tüm değerler piksel (ekran/canvas) cinsindendir; GDScript tarafı her kare günceller.

uniform vec2 center = vec2(640.0, 360.0);
uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform float radius = 0.0;        // dalga önünün yarıçapı
uniform float thickness = 20.0;    // halkanın kalınlığı
uniform float trail = 80.0;        // dalganın arkasında kalan ışıma uzunluğu
uniform float ring_alpha = 1.0;    // halkanın opaklığı (menzil içinde 1, dışında düşük)
uniform float wash_alpha = 0.0;    // dalganın kapladığı alanın hafif ışıması
uniform vec3 yellow : source_color = vec3(1.0, 0.78, 0.18);
uniform vec3 white : source_color = vec3(1.0, 0.97, 0.86);

void fragment() {
	vec2 p = UV * viewport_size;
	float off = distance(p, center) - radius;
	float ring = 1.0 - smoothstep(0.0, thickness, abs(off));
	float core = 1.0 - smoothstep(0.0, thickness * 0.4, abs(off));
	float behind = off < 0.0 ? exp(off / max(trail, 1.0)) : 0.0;
	float inside = off < 0.0 ? 1.0 : 1.0 - smoothstep(0.0, thickness, off);
	vec3 col = mix(yellow, white, clamp(core + behind * 0.25, 0.0, 1.0));
	float a = ring_alpha * (ring * 0.9 + behind * 0.3) + wash_alpha * inside;
	COLOR = vec4(col, clamp(a, 0.0, 1.0));
}
