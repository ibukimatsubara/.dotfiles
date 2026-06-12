// break_screen.tpl.glsl — 休憩タイマー用シェーダーのテンプレート
// Hammerspoon (break_timer.lua) が {{MODE}} / {{PROGRESS}} を埋めて
// ~/.cache/ghostty-break/break_state.glsl を生成する。生成先は直接編集しない。
//
// MODE 0: タイマー OFF（完全素通し）
// MODE 1: フェード中（PROGRESS 0→1 で 色抜け → ぼかし → 暗転 → 星空）
// MODE 2: 休憩中（星空。PROGRESS は休憩の経過 → 画面下の残量バー）
// MODE 3: 休憩おわり（星空 + 中央の淡い明滅 = キー入力待ち）
// MODE 4: 作業中（素通し + 画面下端に作業の残り時間ライン = ON の目印）

#define MODE {{MODE}}
#define PROGRESS {{PROGRESS}}

#if MODE == 0

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = texture(iChannel0, fragCoord / iResolution.xy);
}

#else

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

// グリッドのセルごとに星を1つ置く星レイヤー
float starLayer(vec2 suv, float scale, float density, float t) {
    vec2 g = suv * scale;
    vec2 id = floor(g);
    vec2 f = fract(g);
    float h = hash12(id);
    float on = step(h, density);
    vec2 pos = vec2(hash12(id + 13.1), hash12(id + 27.7)) * 0.7 + 0.15;
    float d = length(f - pos);
    float size = mix(0.03, 0.10, hash12(id + 5.5));
    float star = smoothstep(size, 0.0, d);
    float tw = 0.55 + 0.45 * sin(t * mix(0.6, 2.2, hash12(id + 3.3)) + h * 6.2831);
    return star * tw * on;
}

// 数秒〜十数秒に一度の流れ星
float shootingStar(vec2 suv, float t) {
    float period = 9.0;
    float cell = floor(t / period);
    float ft = fract(t / period);
    float h = hash11(cell * 7.13);
    float burst = step(h, 0.45);
    float life = 0.16;
    float lp = clamp(ft / life, 0.0, 1.0);
    float alive = step(ft, life);
    vec2 start = vec2(mix(0.3, 1.7, hash11(cell * 3.71)),
                      mix(0.55, 0.95, hash11(cell * 9.17)));
    vec2 dir = normalize(vec2(-0.8, -0.35));
    vec2 head = start + dir * 0.55 * lp;
    float tail = 0.12 * smoothstep(0.0, 0.3, lp);
    vec2 toP = suv - head;
    float along = clamp(dot(toP, -dir), 0.0, tail);
    float d = length(toP + dir * along);
    float fade = 1.0 - along / max(tail, 1e-4);
    float streak = smoothstep(0.0035, 0.0, d) * fade;
    float dim = sin(lp * 3.14159);
    return streak * dim * burst * alive;
}

vec3 nightSky(vec2 uv, vec2 suv, float t, float starA) {
    // Ghostty の fragCoord は y 軸が下向き(Shadertoy と逆)なので高さを反転
    float hgt = 1.0 - uv.y;
    vec3 top = vec3(0.012, 0.018, 0.045);
    vec3 bottom = vec3(0.05, 0.06, 0.13);
    vec3 sky = mix(bottom, top, smoothstep(0.0, 0.85, hgt));
    // 淡い天の川の帯
    float band = exp(-pow(((1.0 - suv.y) - 0.35 - suv.x * 0.18) * 4.0, 2.0));
    sky += vec3(0.03, 0.035, 0.06) * band * (0.6 + 0.2 * sin(t * 0.05));
    float s = 0.0;
    s += starLayer(suv, 18.0, 0.30, t) * 0.50;
    s += starLayer(suv + 31.7, 34.0, 0.25, t * 1.3) * 0.35;
    s += starLayer(suv + 74.3, 60.0, 0.20, t * 0.8) * 0.22;
    vec3 col = sky;
    col += vec3(0.90, 0.95, 1.0) * s * starA;
    col += vec3(0.95, 0.97, 1.0) * shootingStar(suv, t) * starA;
    return col;
}

vec3 blurredTerminal(vec2 uv, float radiusPx) {
    if (radiusPx < 0.01) return texture(iChannel0, uv).rgb;
    vec3 acc = vec3(0.0);
    float total = 0.0;
    for (int x = -2; x <= 2; x++) {
        for (int y = -2; y <= 2; y++) {
            vec2 off = vec2(float(x), float(y)) * radiusPx / iResolution.xy;
            float w = exp(-float(x * x + y * y) * 0.22);
            acc += texture(iChannel0, uv + off).rgb * w;
            total += w;
        }
    }
    return acc / total;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 suv = fragCoord / iResolution.y;  // アスペクト補正済み座標
    float t = iTime;
    vec3 col;

#if MODE == 1
    float p = clamp(PROGRESS, 0.0, 1.0);
    float desat = smoothstep(0.00, 0.45, p);        // まず色が抜けて
    float blurR = smoothstep(0.15, 0.70, p) * 4.0;  // ぼやけてきて
    float dark  = smoothstep(0.35, 0.95, p);        // 夜空に沈み
    float starA = smoothstep(0.55, 1.00, p);        // 星が現れる
    vec3 term = blurredTerminal(uv, blurR);
    float luma = dot(term, vec3(0.299, 0.587, 0.114));
    term = mix(term, vec3(luma), desat);
    col = mix(term, nightSky(uv, suv, t, starA), dark);
#elif MODE == 4
    col = texture(iChannel0, uv).rgb;
#else
    col = nightSky(uv, suv, t, 1.0);
#endif

#if MODE == 2
    // 休憩の残り時間バー（下端の細い線。y軸下向きなので uv.y≈1 が画面下端）
    float remain = 1.0 - clamp(PROGRESS, 0.0, 1.0);
    float bar = step(uv.x, remain) * step(0.994, uv.y) * step(uv.y, 0.998);
    col += vec3(0.25, 0.30, 0.45) * bar;
#endif

#if MODE == 3
    // キー入力待ちの合図：中央の淡い明滅
    vec2 c = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float pulse = exp(-length(c) * 5.0) * (0.35 + 0.30 * sin(t * 2.2));
    col += vec3(0.12, 0.16, 0.28) * pulse;
#endif

#if MODE == 4
    // 作業の残り時間ライン。これが見えていればタイマー ON
    float wremain = 1.0 - clamp(PROGRESS, 0.0, 1.0);
    float wbar = step(uv.x, wremain) * step(0.996, uv.y) * step(uv.y, 0.999);
    col += vec3(0.10, 0.12, 0.20) * wbar;
#endif

    fragColor = vec4(col, 1.0);
}

#endif
