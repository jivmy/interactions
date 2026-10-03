#include <metal_stdlib>
using namespace metal;

struct FireUniforms {
    float time;
    float aspect;
    float width;
    float height;
    float intensity;
    float touchX;
    float touchY;
    float prevX;
    float prevY;
    float touching;
    float tiltX;
    float tiltY;
    float spin;
    float style;
    float p0;
    float p1;
};

struct FirePoint {
    float x;
    float y;
    float age;
    float strength;
};

struct FireVertOut {
    float4 position [[position]];
    float2 uv;
};

constant float3 kField = float3(0.96, 0.96, 0.96);

vertex FireVertOut fireVertex(uint vid [[vertex_id]]) {
    float2 positions[3] = { float2(-1.0, -1.0), float2(3.0, -1.0), float2(-1.0, 3.0) };
    FireVertOut out;
    out.position = float4(positions[vid], 0.0, 1.0);
    out.uv = positions[vid] * 0.5 + 0.5;
    return out;
}

static float hash21(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453123);
}

static float2 hash22(float2 p) {
    float n = sin(dot(p, float2(127.1, 311.7)));
    return fract(float2(n, n * 1.2154) * 43758.5453);
}

static float valueNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + float2(1.0, 0.0));
    float c = hash21(i + float2(0.0, 1.0));
    float d = hash21(i + float2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float fbm(float2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * valueNoise(p);
        p = p * 2.07 + float2(1.7, 9.2);
        a *= 0.5;
    }
    return v;
}

static float fbm3(float2 p) {
    float v = 0.0;
    float a = 0.5;
    v += a * valueNoise(p);
    p = p * 2.11 + float2(1.3, 4.7);
    a = 0.25;
    v += a * valueNoise(p);
    p = p * 2.09 + float2(2.1, 8.3);
    v += 0.125 * valueNoise(p);
    return v;
}

/// Deep red → orange → yellow → small white-hot core. Not a filled white blob.
static float3 blackbody(float t) {
    t = saturate(t);
    float3 c = mix(float3(0.10, 0.01, 0.00), float3(0.62, 0.05, 0.00), smoothstep(0.00, 0.20, t));
    c = mix(c, float3(0.95, 0.20, 0.01), smoothstep(0.20, 0.40, t));
    c = mix(c, float3(1.00, 0.48, 0.05), smoothstep(0.40, 0.58, t));
    c = mix(c, float3(1.00, 0.82, 0.20), smoothstep(0.58, 0.74, t));
    c = mix(c, float3(1.00, 0.96, 0.70), smoothstep(0.74, 0.88, t));
    c = mix(c, float3(1.00, 0.99, 0.94), smoothstep(0.88, 1.00, t));
    return c;
}

/// Organic candle silhouette: wide low, pointed tip.
static float teardrop(float2 p, float h, float w) {
    float yy = p.y / max(h, 1e-4);
    float base = smoothstep(-0.04, 0.07, p.y);
    float tip = 1.0 - smoothstep(0.78, 1.10, yy);
    float waist = w * (1.08 - yy * yy);
    waist *= 0.62 + 0.38 * smoothstep(-0.02, 0.18, yy);
    waist *= tip + 0.04;
    float dx = abs(p.x) / max(waist, 1e-4);
    float body = 1.0 - smoothstep(0.38, 1.06, dx);
    return saturate(body * base * saturate(tip + 0.08));
}

static float2 riseWarp(float2 p, float time, float amount) {
    float2 q = p * float2(3.1, 2.05);
    q.y -= time * 1.25;
    float n0 = fbm(q);
    float n1 = fbm(q * 2.17 + float2(n0 * 1.5, -time * 0.85));
    p.x += (n0 - 0.5) * amount;
    p.y += (n1 - 0.5) * amount * 0.20;
    return p;
}

static float flicker(float time, float seed) {
    float a = fbm3(float2(time * 1.7 + seed, 0.4));
    float b = fbm3(float2(time * 4.3 + seed * 1.7, 2.1));
    return 0.88 + a * 0.10 + b * 0.06;
}

static void addTongue(
    float2 p,
    float time,
    float h,
    float w,
    float lean,
    float turb,
    float phase,
    thread float &density,
    thread float &heat
) {
    float2 q = p;
    q.x -= lean * q.y;
    q = riseWarp(q, time + phase, turb * (0.28 + q.y * 1.15));
    float env = teardrop(q, h, w);
    if (env < 0.004) {
        return;
    }

    float yy = saturate(q.y / max(h, 1e-4));
    float holes = fbm(float2(q.x * 6.4, q.y * 4.6 - time * 2.6 + phase));
    float dens = env * mix(0.58, 1.18, holes);
    dens *= 1.0 - yy * 0.22;

    float2 core = float2(lean * h * 0.08, h * 0.14);
    float cx = (q.x - core.x) / max(w * 0.42, 1e-4);
    float cy = (q.y - core.y) / max(h * 0.26, 1e-4);
    float coreHeat = exp(-dot(float2(cx, cy), float2(cx, cy)) * 2.6);
    float edgeCool = 1.0 - smoothstep(0.45, 1.0, abs(q.x) / max(w, 1e-4));
    float tipCool = 1.0 - smoothstep(0.55, 1.02, yy);
    float localHeat = saturate(coreHeat * 1.12 + env * 0.28 * edgeCool);
    localHeat *= mix(0.82, 1.08, holes);
    localHeat *= tipCool;

    density = saturate(density + dens);
    heat = max(heat, saturate(localHeat));
}

static float coalBed(float2 p, float time, float w, float amount) {
    if (amount < 0.01) {
        return 0.0;
    }
    float bed = smoothstep(0.075, 0.0, abs(p.y + 0.008)) * smoothstep(w * 1.55, w * 0.15, abs(p.x));
    float crack = fbm(float2(p.x * 16.0, p.y * 22.0 + time * 0.28));
    float pulse = 0.78 + 0.22 * fbm3(float2(time * 1.1, p.x * 8.0));
    return saturate(bed * mix(0.18, 1.0, pow(crack, 1.35)) * pulse * amount);
}

static float smokePlume(float2 p, float time, float h, float w, float amount) {
    if (amount < 0.01 || p.y < h * 0.28) {
        return 0.0;
    }
    float2 s = p;
    s.x += (fbm3(float2(p.y * 1.6, time * 0.22)) - 0.5) * w * 1.8;
    s.y -= time * 0.12;
    float n = fbm(s * float2(2.4, 1.55) + float2(0.0, -time * 0.35));
    float rise = smoothstep(h * 0.40, h * 0.92, p.y) * smoothstep(h * 2.15, h * 1.05, p.y);
    float column = smoothstep(w * 2.8, 0.0, abs(s.x));
    return saturate(n * rise * column * amount);
}

static float sparkField(float2 p, float time, float h, float w, float amount, float seed) {
    if (amount < 0.08) {
        return 0.0;
    }
    float acc = 0.0;
    for (int i = 0; i < 12; i++) {
        float id = float(i) + seed;
        float2 rnd = hash22(float2(id, 4.7));
        float life = fract(time * (0.28 + rnd.y * 0.55) + rnd.x);
        float2 pos = float2((rnd.x - 0.5) * w * 1.7, life * h * (0.55 + 0.7 * amount));
        pos.x += sin(life * 8.0 + id) * w * 0.22;
        float r = mix(0.012, 0.004, life) * mix(0.7, 1.25, amount);
        float d = length(p - pos);
        acc += smoothstep(r, 0.0, d) * (1.0 - life);
    }
    return saturate(acc);
}

static float heatHaze(float2 p, float time, float h, float w, float amount) {
    float n = fbm3(float2(p.x * 9.0, p.y * 3.2 - time * 3.4));
    float column = smoothstep(w * 2.6, 0.0, abs(p.x));
    float rise = smoothstep(-0.04, 0.16, p.y) * smoothstep(h * 1.55, 0.0, p.y);
    return saturate(n * column * rise * amount);
}

static float4 composeFire(float density, float heat, float coals, float smoke, float sparks, float haze) {
    float3 col = kField;
    col = mix(col, float3(1.00, 0.93, 0.84), haze * 0.10);

    float3 soot = float3(0.42, 0.40, 0.38);
    col = mix(col, soot, saturate(smoke * 0.55));

    float3 ember = blackbody(0.42 + coals * 0.45);
    col = mix(col, ember, saturate(coals));

    float glow = saturate(density * 0.55);
    col = mix(col, blackbody(heat * 0.55), glow * 0.65);

    float body = saturate(density);
    col = mix(col, blackbody(heat), body);

    col += sparks * float3(1.00, 0.72, 0.28);
    col += saturate(heat - 0.78) * density * float3(0.35, 0.22, 0.08);
    return float4(col, 1.0);
}

/// kind 0 candle, 1 hearth, 2 torch, 3 bonfire
static float4 realisticFire(float2 p, float time, int kind, float power) {
    power = saturate(power);
    float flick = flicker(time, float(kind) * 13.7);
    float dens = 0.0;
    float heat = 0.0;
    float coals = 0.0;
    float smoke = 0.0;
    float sparks = 0.0;
    float haze = 0.0;
    float t = time * mix(0.85, 1.25, power);

    if (kind == 0) {
        float h = mix(0.18, 0.40, power) * flick;
        float w = mix(0.055, 0.098, power);
        float lean = 0.10 * sin(t * 1.15 + fbm3(float2(t * 0.4, 1.2)) * 2.0);
        addTongue(p, t, h, w, lean, mix(0.16, 0.30, power), 0.0, dens, heat);
        coals = coalBed(p, t, w * 0.55, mix(0.12, 0.28, power));
        float wick = smoothstep(0.018, 0.0, length(float2(p.x * 4.5, p.y - 0.01)));
        coals = max(coals, wick * 0.45);
        smoke = smokePlume(p, t, h, w, mix(0.10, 0.28, power));
        haze = heatHaze(p, t, h, w, mix(0.18, 0.40, power));
    } else if (kind == 1) {
        float h = mix(0.14, 0.36, power) * flick;
        float w = mix(0.14, 0.28, power);
        addTongue(p + float2(-w * 0.28, 0.0), t, h * 0.92, w * 0.42, 0.06, mix(0.28, 0.48, power), 0.4, dens, heat);
        addTongue(p, t, h, w * 0.48, -0.03, mix(0.30, 0.52, power), 1.7, dens, heat);
        addTongue(p + float2(w * 0.30, 0.0), t, h * 0.84, w * 0.40, -0.08, mix(0.26, 0.46, power), 2.9, dens, heat);
        coals = coalBed(p, t, w, mix(0.45, 1.0, power));
        smoke = smokePlume(p, t, h, w, mix(0.28, 0.62, power));
        sparks = sparkField(p, t, h, w, power * 0.7, 11.0);
        haze = heatHaze(p, t, h, w, mix(0.28, 0.55, power));
    } else if (kind == 2) {
        float h = mix(0.28, 0.68, power) * flick;
        float w = mix(0.06, 0.13, power);
        float lean = 0.16 * sin(t * 0.95) + 0.08 * (fbm3(float2(t * 0.55, 3.1)) - 0.5);
        addTongue(p, t, h, w, lean, mix(0.36, 0.64, power), 0.2, dens, heat);
        addTongue(p + float2(w * 0.15, 0.0), t, h * 0.78, w * 0.62, lean + 0.12, mix(0.32, 0.58, power), 3.3, dens, heat);
        coals = coalBed(p, t, w * 0.8, mix(0.18, 0.40, power));
        smoke = smokePlume(p, t, h, w, mix(0.42, 0.88, power));
        sparks = sparkField(p, t, h, w, power * 0.5, 23.0);
        haze = heatHaze(p, t, h, w, mix(0.22, 0.48, power));
    } else {
        float h = mix(0.22, 0.58, power) * flick;
        float w = mix(0.20, 0.40, power);
        addTongue(p + float2(-w * 0.38, 0.0), t, h * 0.82, w * 0.36, 0.10, mix(0.40, 0.70, power), 0.6, dens, heat);
        addTongue(p + float2(-w * 0.12, 0.0), t, h * 1.02, w * 0.40, -0.04, mix(0.44, 0.76, power), 1.8, dens, heat);
        addTongue(p + float2(w * 0.14, 0.0), t, h * 0.94, w * 0.38, 0.05, mix(0.42, 0.72, power), 3.1, dens, heat);
        addTongue(p + float2(w * 0.40, 0.0), t, h * 0.76, w * 0.34, -0.12, mix(0.38, 0.68, power), 4.4, dens, heat);
        coals = coalBed(p, t, w, mix(0.55, 1.0, power));
        smoke = smokePlume(p, t, h, w * 1.15, mix(0.48, 0.95, power));
        sparks = sparkField(p, t, h, w, power * 0.9, 37.0);
        haze = heatHaze(p, t, h, w, mix(0.40, 0.72, power));
    }

    dens *= mix(0.55, 1.0, power);
    heat *= mix(0.72, 1.0, power);
    return composeFire(dens, heat, coals, smoke, sparks, haze);
}

fragment float4 fireballsFragment(FireVertOut in [[stage_in]], constant FireUniforms &u [[buffer(0)]]) {
    float2 uv = in.uv;
    float top = 0.070;
    float bottom = 0.145;
    float usable = 1.0 - top - bottom;
    if (uv.y < bottom || uv.y > 1.0 - top) {
        return float4(kField, 1.0);
    }

    float gx = uv.x * 2.0;
    float gy = (uv.y - bottom) / usable * 2.0;
    int col = int(clamp(floor(gx), 0.0, 1.0));
    int row = int(clamp(floor(gy), 0.0, 1.0));
    int kind = (1 - row) * 2 + col;
    float2 local = float2(fract(gx), fract(gy));
    float cellAspect = (u.aspect * 0.5) / max(usable * 0.5, 1e-4);
    float2 p = float2((local.x - 0.5) * cellAspect, local.y - 0.12);
    return realisticFire(p, u.time, kind, saturate(u.intensity));
}

fragment float4 breathFireFragment(FireVertOut in [[stage_in]], constant FireUniforms &u [[buffer(0)]]) {
    float2 p = float2((in.uv.x - 0.5) * u.aspect, in.uv.y - 0.20);
    return realisticFire(p, u.time, 1, saturate(u.intensity));
}

fragment float4 fireLeanFragment(FireVertOut in [[stage_in]], constant FireUniforms &u [[buffer(0)]]) {
    float2 p = float2((in.uv.x - 0.5) * u.aspect, in.uv.y - 0.18);
    p.x -= u.tiltX * p.y * 1.05;
    p.y += u.tiltY * 0.07;
    float power = saturate(0.52 + length(float2(u.tiltX, u.tiltY)) * 0.32);
    return realisticFire(p, u.time, 0, power);
}

fragment float4 fireTrailFragment(FireVertOut in [[stage_in]],
                                 constant FireUniforms &u [[buffer(0)]],
                                 constant FirePoint *points [[buffer(1)]]) {
    float2 p = float2(in.uv.x * u.aspect, in.uv.y);
    float dens = 0.0;
    float heat = 0.0;
    float coals = 0.0;
    float smoke = 0.0;
    float sparks = 0.0;
    float haze = 0.0;
    for (int i = 0; i < 24; i++) {
        float s = points[i].strength;
        if (s < 0.02) {
            continue;
        }
        float age = saturate(points[i].age);
        float live = (1.0 - age) * s;
        float2 q = p - float2(points[i].x * u.aspect, points[i].y);
        q.y -= 0.01;
        float h = mix(0.05, 0.16, live);
        float w = mix(0.03, 0.07, live);
        addTongue(q, u.time + float(i) * 0.37, h, w, 0.05, 0.34, float(i), dens, heat);
        coals = max(coals, coalBed(q, u.time, w, live * 0.45));
        smoke = max(smoke, smokePlume(q, u.time, h, w, live * 0.35));
        haze = max(haze, heatHaze(q, u.time, h, w, live * 0.3));
    }
    sparks = 0.0;
    return composeFire(dens, heat, coals, smoke, sparks, haze);
}

fragment float4 fireWhirlFragment(FireVertOut in [[stage_in]], constant FireUniforms &u [[buffer(0)]]) {
    float2 p = float2((in.uv.x - 0.5) * u.aspect, in.uv.y - 0.16);
    float spin = u.spin;
    float twist = p.y * (2.2 + abs(spin) * 4.5) - u.time * spin * 5.5;
    float2 q = p;
    q.x -= sin(twist) * mix(0.02, 0.09, saturate(abs(spin)));
    float power = saturate(0.28 + abs(spin) * 0.55);
    float h = mix(0.38, 0.74, power);
    float w = mix(0.07, 0.15, power);
    float dens = 0.0;
    float heat = 0.0;
    addTongue(q, u.time, h, w, spin * 0.08, mix(0.40, 0.72, power), 0.0, dens, heat);
    addTongue(q + float2(w * 0.22, 0.0), u.time, h * 0.82, w * 0.7, spin * 0.12, mix(0.36, 0.64, power), 2.2, dens, heat);
    float coals = coalBed(p, u.time, w * 1.3, power * 0.7);
    float smoke = smokePlume(q, u.time, h, w, mix(0.35, 0.80, power));
    float sparks = sparkField(q, u.time, h, w, power * 0.55, 19.0);
    float haze = heatHaze(p, u.time, h, w, mix(0.30, 0.60, power));
    return composeFire(dens, heat, coals, smoke, sparks, haze);
}

fragment float4 fireSheetFragment(FireVertOut in [[stage_in]], constant FireUniforms &u [[buffer(0)]]) {
    float2 p = float2((in.uv.x - 0.5) * u.aspect - u.p0, in.uv.y - 0.04);
    float dens = 0.0;
    float heat = 0.0;
    float h = 0.52;
    float w = 0.10;
    addTongue(p + float2(-0.28, 0.0), u.time, h * 0.88, w, 0.04, 0.48, 0.5, dens, heat);
    addTongue(p + float2(-0.10, 0.0), u.time, h, w, -0.03, 0.52, 1.6, dens, heat);
    addTongue(p + float2(0.08, 0.0), u.time, h * 0.94, w, 0.05, 0.50, 2.8, dens, heat);
    addTongue(p + float2(0.26, 0.0), u.time, h * 0.82, w, -0.06, 0.46, 3.9, dens, heat);
    float curtain = smoothstep(0.46, 0.10, abs(p.x));
    dens *= curtain;
    heat *= curtain;
    float coals = coalBed(p, u.time, 0.38, 0.85) * curtain;
    float smoke = smokePlume(p, u.time, h, 0.22, 0.7) * curtain;
    float haze = heatHaze(p, u.time, h, 0.22, 0.5) * curtain;
    return composeFire(dens, heat, coals, smoke, 0.0, haze);
}

fragment float4 fireStrikeFragment(FireVertOut in [[stage_in]], constant FireUniforms &u [[buffer(0)]]) {
    float2 p = float2((in.uv.x - 0.5) * u.aspect, in.uv.y - 0.20);
    float heatIn = saturate(u.intensity);
    float4 fire = realisticFire(p, u.time, 1, heatIn);
    if (u.touching < 0.5 || heatIn < 0.02) {
        return fire;
    }
    float2 dir = float2(u.prevX, u.prevY);
    float along = p.x * dir.x + p.y * dir.y;
    float across = p.x * dir.y - p.y * dir.x;
    float streak = exp(-across * across * 42.0) * smoothstep(0.35, -0.02, along) * 0.28;
    float3 col = fire.rgb + streak * blackbody(0.7);
    return float4(col, 1.0);
}
