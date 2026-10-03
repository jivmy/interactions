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
    v += 0.5 * valueNoise(p);
    p = p * 2.11 + float2(1.3, 4.7);
    v += 0.25 * valueNoise(p);
    p = p * 2.09 + float2(2.1, 8.3);
    v += 0.125 * valueNoise(p);
    return v;
}

/// Bright only: orange → yellow → white-hot. No near-black rim.
static float3 flameColor(float t) {
    t = saturate(t);
    float3 c = mix(float3(1.00, 0.42, 0.06), float3(1.00, 0.62, 0.10), smoothstep(0.00, 0.35, t));
    c = mix(c, float3(1.00, 0.82, 0.20), smoothstep(0.35, 0.60, t));
    c = mix(c, float3(1.00, 0.96, 0.70), smoothstep(0.60, 0.82, t));
    c = mix(c, float3(1.00, 0.99, 0.94), smoothstep(0.82, 1.00, t));
    return c;
}

static float2 qbez(float2 a, float2 c, float2 b, float t) {
    float u = 1.0 - t;
    return u * u * a + 2.0 * u * t * c + t * t * b;
}

static float rayHits(float2 p, float2 a, float2 c, float2 b) {
    float A = a.y - 2.0 * c.y + b.y;
    float B = 2.0 * (c.y - a.y);
    float C = a.y - p.y;
    float hits = 0.0;
    if (abs(A) < 1e-6) {
        if (abs(B) > 1e-6) {
            float t = -C / B;
            if (t >= 0.0 && t <= 1.0) {
                float2 q = qbez(a, c, b, t);
                if (q.x > p.x) {
                    hits += 1.0;
                }
            }
        }
    } else {
        float disc = B * B - 4.0 * A * C;
        if (disc >= 0.0) {
            float s = sqrt(disc);
            float inv = 0.5 / A;
            float t0 = (-B - s) * inv;
            float t1 = (-B + s) * inv;
            if (t0 >= 0.0 && t0 <= 1.0) {
                float2 q = qbez(a, c, b, t0);
                if (q.x > p.x) {
                    hits += 1.0;
                }
            }
            if (t1 >= 0.0 && t1 <= 1.0) {
                float2 q = qbez(a, c, b, t1);
                if (q.x > p.x) {
                    hits += 1.0;
                }
            }
        }
    }
    return hits;
}

static float bezDist(float2 p, float2 a, float2 c, float2 b) {
    float d = 8.0;
    for (int i = 0; i <= 10; i++) {
        float t = float(i) / 10.0;
        d = min(d, length(p - qbez(a, c, b, t)));
    }
    return d;
}

/// Exact Canvas `flamePath` from FireballKind.candle (commit 7c44861).
static float canvasFlameMask(float2 canvasP, float w, float h) {
    float2 tip = float2(0.0, -h);
    float2 left = float2(-w * 0.5, -h * 0.22);
    float2 right = float2(w * 0.5, -h * 0.22);
    float2 bottom = float2(0.0, w * 0.10);
    float2 cTL = float2(-w * 0.58, -h * 0.58);
    float2 cLB = float2(-w * 0.40, w * 0.28);
    float2 cBR = float2(w * 0.40, w * 0.28);
    float2 cRT = float2(w * 0.58, -h * 0.58);

    float hits = 0.0;
    hits += rayHits(canvasP, tip, cTL, left);
    hits += rayHits(canvasP, left, cLB, bottom);
    hits += rayHits(canvasP, bottom, cBR, right);
    hits += rayHits(canvasP, right, cRT, tip);
    float inside = step(0.5, fmod(hits, 2.0));

    float ud = bezDist(canvasP, tip, cTL, left);
    ud = min(ud, bezDist(canvasP, left, cLB, bottom));
    ud = min(ud, bezDist(canvasP, bottom, cBR, right));
    ud = min(ud, bezDist(canvasP, right, cRT, tip));
    float sd = mix(ud, -ud, inside);
    return saturate(0.5 - sd / 0.0065);
}

static float2 toCanvas(float2 p, float lean) {
    float2 c = float2(p.x, -p.y);
    float cs = cos(lean);
    float sn = sin(lean);
    return float2(cs * c.x - sn * c.y, sn * c.x + cs * c.y);
}

/// Layered organic teardrop: dark orange outer, yellow body, white-hot core, lean + flicker.
static float4 canvasCandle(float2 p, float time, float power, float extraLean) {
    power = saturate(power);
    float roar = power * power;
    float flicker = 0.80 + 0.20 * sin(time * 11.2) * sin(time * 6.7 + 0.4);
    float lean = sin(time * 2.35) * mix(0.02, 0.16, power) + extraLean;
    float h = mix(0.055, 0.46, power) * flicker;
    float w = mix(0.031, 0.25, power);
    float2 q = toCanvas(p, lean);

    float3 col = kField;
    float stainR = mix(0.10, 0.28, power);
    float stain = exp(-length(float2(p.x / stainR, p.y / (stainR * 1.15))) ) * mix(0.05, 0.22, power);
    col = mix(col, float3(1.00, 0.45, 0.08), saturate(stain));

    float a0 = canvasFlameMask(q, w * 1.55, h * 1.12) * mix(0.16, 0.42, power);
    col = mix(col, float3(0.95, 0.22, 0.04), a0);
    float a1 = canvasFlameMask(q, w * 1.12, h) * 0.92;
    col = mix(col, float3(1.00, 0.42, 0.06), a1);
    float a2 = canvasFlameMask(q, w * 0.70, h * 0.78) * 0.95;
    col = mix(col, float3(1.00, 0.78, 0.16), a2);
    float a3 = canvasFlameMask(q, w * 0.34, h * 0.42) * 0.96;
    col = mix(col, float3(1.00, 0.97, 0.82), a3);

    float coreH = mix(0.016, 0.055 + roar * 0.038, power);
    float2 core = q - float2(0.0, -coreH * 0.05);
    core.x /= max(w * 0.10, 1e-4);
    core.y /= max(coreH * 0.50, 1e-4);
    float coreM = saturate(1.0 - dot(core, core));
    col = mix(col, float3(0.65, 0.82, 1.00), coreM * mix(0.15, 0.75, power) * a1);
    return float4(col, 1.0);
}

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
    float dens = env * mix(0.62, 1.12, holes);
    dens *= 1.0 - yy * 0.18;

    float2 core = float2(lean * h * 0.08, h * 0.14);
    float cx = (q.x - core.x) / max(w * 0.42, 1e-4);
    float cy = (q.y - core.y) / max(h * 0.26, 1e-4);
    float coreHeat = exp(-dot(float2(cx, cy), float2(cx, cy)) * 2.6);
    float tipCool = 1.0 - smoothstep(0.55, 1.02, yy);
    float localHeat = saturate(coreHeat * 1.12 + env * 0.42);
    localHeat *= mix(0.86, 1.08, holes) * tipCool;

    density = saturate(density + dens);
    heat = max(heat, saturate(localHeat));
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
        acc += smoothstep(r, 0.0, length(p - pos)) * (1.0 - life);
    }
    return saturate(acc);
}

static float heatHaze(float2 p, float time, float h, float w, float amount) {
    float n = fbm3(float2(p.x * 9.0, p.y * 3.2 - time * 3.4));
    float column = smoothstep(w * 2.6, 0.0, abs(p.x));
    float rise = smoothstep(-0.04, 0.16, p.y) * smoothstep(h * 1.55, 0.0, p.y);
    return saturate(n * column * rise * amount);
}

static float4 composeBright(float density, float heat, float sparks, float haze) {
    float3 col = kField;
    col = mix(col, float3(1.00, 0.55, 0.14), saturate(haze) * 0.09);
    col = mix(col, float3(1.00, 0.42, 0.06), saturate(density * 0.45) * 0.40);
    col = mix(col, flameColor(heat), saturate(density));
    col += sparks * float3(1.00, 0.88, 0.40);
    return float4(col, 1.0);
}

/// kind 1 hearth, 2 torch, 3 bonfire
static float4 brightFuel(float2 p, float time, int kind, float power) {
    power = saturate(power);
    float flick = flicker(time, float(kind) * 13.7);
    float dens = 0.0;
    float heat = 0.0;
    float sparks = 0.0;
    float haze = 0.0;
    float t = time * mix(0.85, 1.25, power);

    if (kind == 1) {
        float h = mix(0.16, 0.42, power) * flick;
        float w = mix(0.16, 0.32, power);
        addTongue(p + float2(-w * 0.28, 0.0), t, h * 0.92, w * 0.42, 0.06, mix(0.22, 0.40, power), 0.4, dens, heat);
        addTongue(p, t, h, w * 0.48, -0.03, mix(0.24, 0.44, power), 1.7, dens, heat);
        addTongue(p + float2(w * 0.30, 0.0), t, h * 0.84, w * 0.40, -0.08, mix(0.20, 0.38, power), 2.9, dens, heat);
        sparks = sparkField(p, t, h, w, power * 0.55, 11.0);
        haze = heatHaze(p, t, h, w, mix(0.10, 0.22, power));
    } else if (kind == 2) {
        float h = mix(0.30, 0.70, power) * flick;
        float w = mix(0.07, 0.14, power);
        float lean = 0.16 * sin(t * 0.95) + 0.08 * (fbm3(float2(t * 0.55, 3.1)) - 0.5);
        addTongue(p, t, h, w, lean, mix(0.28, 0.50, power), 0.2, dens, heat);
        addTongue(p + float2(w * 0.15, 0.0), t, h * 0.78, w * 0.62, lean + 0.12, mix(0.24, 0.46, power), 3.3, dens, heat);
        sparks = sparkField(p, t, h, w, power * 0.4, 23.0);
        haze = heatHaze(p, t, h, w, mix(0.08, 0.18, power));
    } else {
        float h = mix(0.24, 0.60, power) * flick;
        float w = mix(0.22, 0.42, power);
        addTongue(p + float2(-w * 0.38, 0.0), t, h * 0.82, w * 0.36, 0.10, mix(0.30, 0.52, power), 0.6, dens, heat);
        addTongue(p + float2(-w * 0.12, 0.0), t, h * 1.02, w * 0.40, -0.04, mix(0.32, 0.56, power), 1.8, dens, heat);
        addTongue(p + float2(w * 0.14, 0.0), t, h * 0.94, w * 0.38, 0.05, mix(0.30, 0.54, power), 3.1, dens, heat);
        addTongue(p + float2(w * 0.40, 0.0), t, h * 0.76, w * 0.34, -0.12, mix(0.28, 0.50, power), 4.4, dens, heat);
        sparks = sparkField(p, t, h, w, power * 0.7, 37.0);
        haze = heatHaze(p, t, h, w, mix(0.12, 0.24, power));
    }

    dens *= mix(0.55, 1.0, power);
    heat *= mix(0.78, 1.0, power);
    return composeBright(dens, heat, sparks, haze);
}

static float4 oneFire(float2 p, float time, int kind, float power) {
    if (kind <= 0) {
        return canvasCandle(p, time, power, 0.0);
    }
    return brightFuel(p, time, kind, power);
}

fragment float4 fireballsFragment(FireVertOut in [[stage_in]], constant FireUniforms &u [[buffer(0)]]) {
    float2 p = float2((in.uv.x - 0.5) * u.aspect, in.uv.y - 0.20);
    int kind = int(clamp(u.style + 0.5, 0.0, 3.0));
    return oneFire(p, u.time, kind, saturate(u.intensity));
}

fragment float4 breathFireFragment(FireVertOut in [[stage_in]], constant FireUniforms &u [[buffer(0)]]) {
    float2 p = float2((in.uv.x - 0.5) * u.aspect, in.uv.y - 0.20);
    return brightFuel(p, u.time, 1, saturate(u.intensity));
}

fragment float4 fireLeanFragment(FireVertOut in [[stage_in]], constant FireUniforms &u [[buffer(0)]]) {
    float2 p = float2((in.uv.x - 0.5) * u.aspect, in.uv.y - 0.18);
    p.x -= u.tiltX * p.y * 1.05;
    p.y += u.tiltY * 0.07;
    float power = saturate(0.52 + length(float2(u.tiltX, u.tiltY)) * 0.32);
    return canvasCandle(p, u.time, power, u.tiltX * 0.18);
}

fragment float4 fireTrailFragment(FireVertOut in [[stage_in]],
                                 constant FireUniforms &u [[buffer(0)]],
                                 constant FirePoint *points [[buffer(1)]]) {
    float2 p = float2(in.uv.x * u.aspect, in.uv.y);
    float dens = 0.0;
    float heat = 0.0;
    float haze = 0.0;
    for (int i = 0; i < 24; i++) {
        float s = points[i].strength;
        if (s < 0.02) {
            continue;
        }
        float live = (1.0 - saturate(points[i].age)) * s;
        float2 q = p - float2(points[i].x * u.aspect, points[i].y);
        q.y -= 0.01;
        float h = mix(0.05, 0.16, live);
        float w = mix(0.03, 0.07, live);
        addTongue(q, u.time + float(i) * 0.37, h, w, 0.05, 0.28, float(i), dens, heat);
        haze = max(haze, heatHaze(q, u.time, h, w, live * 0.18));
    }
    return composeBright(dens, heat, 0.0, haze);
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
    addTongue(q, u.time, h, w, spin * 0.08, mix(0.30, 0.52, power), 0.0, dens, heat);
    addTongue(q + float2(w * 0.22, 0.0), u.time, h * 0.82, w * 0.7, spin * 0.12, mix(0.28, 0.48, power), 2.2, dens, heat);
    float sparks = sparkField(q, u.time, h, w, power * 0.45, 19.0);
    float haze = heatHaze(p, u.time, h, w, mix(0.10, 0.20, power));
    return composeBright(dens, heat, sparks, haze);
}

fragment float4 fireSheetFragment(FireVertOut in [[stage_in]], constant FireUniforms &u [[buffer(0)]]) {
    float2 p = float2((in.uv.x - 0.5) * u.aspect - u.p0, in.uv.y - 0.04);
    float dens = 0.0;
    float heat = 0.0;
    float h = 0.52;
    float w = 0.10;
    addTongue(p + float2(-0.28, 0.0), u.time, h * 0.88, w, 0.04, 0.40, 0.5, dens, heat);
    addTongue(p + float2(-0.10, 0.0), u.time, h, w, -0.03, 0.44, 1.6, dens, heat);
    addTongue(p + float2(0.08, 0.0), u.time, h * 0.94, w, 0.05, 0.42, 2.8, dens, heat);
    addTongue(p + float2(0.26, 0.0), u.time, h * 0.82, w, -0.06, 0.38, 3.9, dens, heat);
    float curtain = smoothstep(0.46, 0.10, abs(p.x));
    dens *= curtain;
    heat *= curtain;
    float haze = heatHaze(p, u.time, h, 0.22, 0.16) * curtain;
    return composeBright(dens, heat, 0.0, haze);
}

fragment float4 fireStrikeFragment(FireVertOut in [[stage_in]], constant FireUniforms &u [[buffer(0)]]) {
    float2 p = float2((in.uv.x - 0.5) * u.aspect, in.uv.y - 0.20);
    float heatIn = saturate(u.intensity);
    float4 fire = brightFuel(p, u.time, 1, heatIn);
    if (u.touching < 0.5 || heatIn < 0.02) {
        return fire;
    }
    float2 dir = float2(u.prevX, u.prevY);
    float along = p.x * dir.x + p.y * dir.y;
    float across = p.x * dir.y - p.y * dir.x;
    float streak = exp(-across * across * 42.0) * smoothstep(0.35, -0.02, along) * 0.28;
    float3 col = fire.rgb + streak * float3(1.00, 0.82, 0.28);
    return float4(col, 1.0);
}
