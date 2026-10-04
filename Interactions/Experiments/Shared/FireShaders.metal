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

static float2 leanP(float2 p, float a) {
    float c = cos(a);
    float s = sin(a);
    return float2(c * p.x - s * p.y, s * p.x + c * p.y);
}

/// Smooth teardrop coverage. One body, soft edge — no jagged bezier crawl.
static float flameCover(float2 p, float h, float w) {
    float t = p.y / max(h, 1e-4);
    float base = smoothstep(-0.045, 0.055, p.y);
    float tip = smoothstep(1.07, 0.80, t);
    float waist = w * (1.03 - t * t);
    waist *= 0.68 + 0.32 * smoothstep(-0.02, 0.18, t);
    waist *= 0.12 + 0.88 * tip;
    float nx = abs(p.x) / max(waist * 0.5, 1e-4);
    float radial = smoothstep(1.06, 0.52, nx);
    return saturate(radial * base * tip);
}

static float calmFlicker(float time, float phase) {
    return 0.985 + 0.015 * sin(time * 1.65 + phase) * sin(time * 1.12 + phase * 0.7);
}

static float calmLean(float time, float phase, float power) {
    return 0.026 * sin(time * 0.46 + phase) * mix(0.35, 1.0, power);
}

/// Visible but smooth. Build 25's 1.5% / 1.5° motion read as a still.
static float liveFlicker(float time, float phase) {
    float a = sin(time * 2.05 + phase);
    float b = sin(time * 1.28 + phase * 1.4);
    return 0.935 + 0.065 * (0.58 * a + 0.42 * b);
}

static float liveLean(float time, float phase, float power) {
    return mix(0.04, 0.08, power) * sin(time * 0.82 + phase);
}

static float2 liveRise(float2 p, float time, float phase, float amount) {
    float tip = saturate(p.y * 1.85);
    float2 adv = float2(p.x * 2.15 + phase, p.y * 1.5 - time * 0.78);
    float n0 = fbm3(adv);
    float n1 = fbm3(adv * 1.8 + float2(2.8, -time * 0.33));
    p.x += (n0 - 0.5) * amount * (0.22 + 0.78 * tip);
    p.y += (n1 - 0.5) * amount * 0.20 * tip;
    return p;
}

/// Old Canvas candle layers: orange outer, yellow body, white-hot core.
static float3 paintLayered(float3 col, float2 p, float h, float w, float power) {
    float stainR = mix(0.07, 0.18, power);
    float stain = exp(-length(float2(p.x / stainR, p.y / (stainR * 1.15)))) * mix(0.04, 0.16, power);
    col = mix(col, float3(1.00, 0.45, 0.08), saturate(stain));
    col = mix(col, float3(0.95, 0.22, 0.04), flameCover(p, h * 1.12, w * 1.55) * mix(0.16, 0.42, power));
    col = mix(col, float3(1.00, 0.42, 0.06), flameCover(p, h, w * 1.12) * 0.92);
    col = mix(col, float3(1.00, 0.78, 0.16), flameCover(p, h * 0.78, w * 0.70) * 0.95);
    col = mix(col, float3(1.00, 0.97, 0.82), flameCover(p, h * 0.42, w * 0.34) * 0.96);
    return col;
}

static float4 canvasCandle(float2 p, float time, float power, float extraLean) {
    power = saturate(power);
    float flick = calmFlicker(time, 0.0);
    float lean = calmLean(time, 0.0, power) + extraLean * 0.25;
    float h = mix(0.10, 0.44, power) * flick;
    float w = mix(0.055, 0.22, power);
    float2 q = leanP(p, lean);
    return float4(paintLayered(kField, q, h, w, power), 1.0);
}

/// Bright composite. No soot, no charcoal rim.
static float4 emitFire(float cover, float heat) {
    float3 col = kField;
    col = mix(col, float3(1.00, 0.48, 0.08), saturate(cover) * 0.30);
    col = mix(col, flameColor(saturate(heat)), saturate(cover));
    return float4(col, 1.0);
}

static float2 cellP(float2 uv, float aspect) {
    return float2((uv.x - 0.5) * aspect, uv.y - 0.18);
}

/// Grid A0 — concentric Canvas teardrop layers. Power: hotter core, more tip warp.
static float4 shadeCandle(float2 p, float time, float power) {
    power = saturate(power);
    float flick = liveFlicker(time, 0.15);
    float lean = liveLean(time, 0.0, power);
    float2 q = leanP(p, lean);
    q = liveRise(q, time, 0.0, mix(0.045, 0.13, power));
    float h = 0.34 * mix(0.94, 1.10, power) * flick;
    float w = 0.145 * (0.97 + 0.03 * sin(time * 1.48));
    return float4(paintLayered(kField, q, h, w, power), 1.0);
}

/// Grid A1 — one tongue along a traveling S-curve. Power: more bend, spine heat, width noise.
static float4 shadeSpine(float2 p, float time, float power) {
    power = saturate(power);
    float h = 0.40;
    float t = p.y / h;
    float amp = mix(0.028, 0.078, power);
    float cl = amp * sin(p.y * 5.4 + time * 1.55);
    cl += amp * 0.38 * sin(p.y * 9.2 + time * 0.92 + 1.1);
    float2 q = float2(p.x - cl, p.y);
    q = liveRise(q, time, 2.2, mix(0.03, 0.10, power));
    float halfW = mix(0.048, 0.072, power) * (1.02 - t * t);
    halfW *= 0.15 + 0.85 * smoothstep(1.06, 0.70, t);
    halfW *= smoothstep(-0.035, 0.055, q.y);
    float d = abs(q.x) / max(halfW, 1e-4);
    float cover = saturate(smoothstep(1.08, 0.42, d) * smoothstep(-0.04, 0.05, q.y) * smoothstep(1.08, 0.74, t));
    float n = fbm3(float2(q.x * 7.5, q.y * 4.6 - time * mix(0.55, 1.35, power)));
    cover *= 0.80 + 0.20 * n;
    float heat = saturate((1.0 - d * 0.62) * (1.0 - saturate(t) * 0.28));
    heat *= mix(0.52, 1.0, power);
    heat *= 0.72 + 0.28 * n;
    return emitFire(cover, heat);
}

/// Grid A2 — parallel-sided column, taper only at the tip. Power: boil, mouth flare, brightness.
static float4 shadeColumn(float2 p, float time, float power) {
    power = saturate(power);
    float h = 0.46;
    float t = p.y / h;
    float2 q = leanP(p, liveLean(time, 1.4, power) * 0.45);
    q.x += mix(0.004, 0.016, power) * sin(time * 1.7 + q.y * 6.0);
    float halfW = 0.052;
    halfW += mix(0.0, 0.028, power) * smoothstep(0.52, 0.92, t);
    halfW *= smoothstep(1.07, 0.80, t);
    halfW *= smoothstep(-0.03, 0.05, q.y);
    float d = abs(q.x) / max(halfW, 1e-4);
    float cover = saturate(smoothstep(1.04, 0.48, d) * smoothstep(-0.03, 0.05, q.y) * smoothstep(1.08, 0.78, t));
    float bands = fbm3(float2(q.x * 16.0, q.y * 2.8 - time * mix(0.70, 1.90, power)));
    float boil = mix(0.06, 0.32, power);
    cover *= 1.0 - boil * (1.0 - bands);
    float heat = saturate((1.0 - d * 0.50) * (0.62 + 0.38 * bands));
    heat *= mix(0.48, 1.0, power);
    return emitFire(cover, heat);
}

/// Grid A3 — votive bowl: wide pool, short lift. Power: white-hot pool, more lift, shimmer.
static float4 shadeBowl(float2 p, float time, float power) {
    power = saturate(power);
    float2 q = p;
    q.x += mix(0.004, 0.014, power) * sin(time * 1.15 + 0.6);
    q.y += 0.012 * sin(time * 1.85) * mix(0.4, 1.0, power);
    float2 ep = float2(q.x / 0.18, (q.y - 0.025) / mix(0.075, 0.11, power));
    float pool = exp(-dot(ep, ep) * mix(1.15, 0.82, power));
    float shimmer = fbm3(float2(q.x * 9.0 + time * 0.4, q.y * 6.0 - time * mix(0.4, 1.1, power)));
    pool *= 0.78 + 0.22 * shimmer;
    float tip = flameCover(q - float2(0.0, 0.04), mix(0.12, 0.18, power), mix(0.055, 0.08, power));
    tip *= 0.70 + 0.30 * fbm3(float2(q.x * 6.0, q.y * 5.0 - time * 0.9));
    float cover = max(pool * 0.96, tip * 0.90);
    float heat = pool * mix(0.55, 1.02, power) + tip * mix(0.35, 0.70, power);
    return emitFire(cover, saturate(heat));
}

/// Grid A4 — thin blade, one hotter edge. Power: edge temperature, tip flutter, brightness.
static float4 shadeBlade(float2 p, float time, float power) {
    power = saturate(power);
    float h = 0.44;
    float t = saturate(p.y / h);
    float flutter = mix(0.006, 0.024, power) * sin(time * 2.15 + p.y * 9.5);
    float2 q = float2(p.x - flutter * t, p.y);
    float left = 0.016;
    float right = mix(0.028, 0.046, power);
    float halfW = (q.x < 0.0) ? left : right;
    halfW *= (1.04 - t * t);
    halfW *= 0.12 + 0.88 * smoothstep(1.06, 0.72, t);
    halfW *= smoothstep(-0.03, 0.05, q.y);
    float d = abs(q.x) / max(halfW, 1e-4);
    float cover = saturate(smoothstep(1.06, 0.38, d) * smoothstep(-0.03, 0.05, q.y) * smoothstep(1.08, 0.74, t));
    float n = fbm3(float2(q.x * 12.0, q.y * 5.5 - time * mix(0.6, 1.5, power)));
    cover *= 0.82 + 0.18 * n;
    float edge = saturate(q.x / max(right, 1e-4));
    float heat = saturate((1.0 - d * 0.55) * mix(0.55, 1.0, edge));
    heat *= mix(0.50, 1.0, power);
    heat *= 0.74 + 0.26 * n;
    return emitFire(cover, heat);
}

/// Grid A5 — round orb on a short neck. Power: corona volume, convection speed, brightness.
static float4 shadeOrb(float2 p, float time, float power) {
    power = saturate(power);
    float2 c = float2(0.0, 0.145);
    float2 q = p - c;
    float ang = atan2(q.x, q.y);
    float rad = length(q / float2(0.115, 0.125));
    float swirl = time * mix(0.45, 1.25, power);
    float n = fbm3(float2(rad * 3.6, ang * 1.4 + swirl));
    float corona = mix(1.02, 1.22, power);
    float cover = smoothstep(corona, 0.48, rad);
    cover *= 0.76 + 0.24 * n;
    float neck = flameCover(p, 0.11, 0.038);
    cover = max(cover, neck * 0.82);
    float heat = saturate((1.0 - rad * 0.72) * (0.55 + 0.45 * n));
    heat *= mix(0.50, 1.0, power);
    return emitFire(saturate(cover), heat);
}

/// Grid B0 — domain-warped FBM density. Power: warp, fill, temperature.
static float4 shadeVolume(float2 p, float time, float power) {
    power = saturate(power);
    float warp = mix(0.035, 0.13, power);
    float2 q = p;
    q.x += (fbm3(float2(p.x * 3.1, p.y * 2.2 - time * 0.82)) - 0.5) * warp;
    q.y += (fbm3(float2(p.x * 2.4 + 3.0, p.y * 3.0 - time * 0.48)) - 0.5) * warp * 0.35;
    float env = flameCover(q, 0.40, 0.155);
    float dens = fbm(float2(q.x * 5.2, q.y * 4.1 - time * mix(0.55, 1.45, power)));
    dens = saturate(dens * mix(0.65, 1.28, power)) * env;
    float t = saturate(q.y / 0.40);
    float heat = saturate(dens * (1.05 - t * 0.32) * mix(0.55, 1.0, power));
    return emitFire(dens, heat);
}

/// Grid B1 — curl-noise advection of one plume. Power: curl strength, twist, brightness.
static float4 shadeCurl(float2 p, float time, float power) {
    power = saturate(power);
    float e = 0.018;
    float ty = time * mix(0.50, 1.20, power);
    float nL = fbm3(float2((p.x - e) * 4.0, p.y * 3.0 - ty));
    float nR = fbm3(float2((p.x + e) * 4.0, p.y * 3.0 - ty));
    float nD = fbm3(float2(p.x * 4.0, (p.y - e) * 3.0 - ty));
    float nU = fbm3(float2(p.x * 4.0, (p.y + e) * 3.0 - ty));
    float2 grad = float2(nR - nL, nU - nD) / (2.0 * e);
    float2 curl = float2(-grad.y, grad.x);
    float2 q = p + curl * mix(0.025, 0.095, power);
    float env = flameCover(q, 0.42, 0.12);
    float dens = env * (0.70 + 0.30 * fbm3(float2(q.x * 6.0, q.y * 4.4 - ty)));
    dens *= mix(0.55, 1.0, power);
    float heat = saturate((1.0 - saturate(q.y / 0.42) * 0.30) * dens * mix(0.70, 1.15, power));
    return emitFire(dens, heat);
}

/// Grid B2 — polar cardioid with angular heat drift. Power: scallop, radial flicker, heat.
static float4 shadePolar(float2 p, float time, float power) {
    power = saturate(power);
    float2 o = float2(p.x, p.y + 0.01);
    float r = length(o);
    float th = atan2(o.x, o.y);
    float card = pow(max(0.0, 0.5 * (1.0 + cos(th))), 1.28);
    float scallop = 1.0 + mix(0.03, 0.14, power) * sin(th * 3.0 + time * 1.05);
    float rMax = 0.40 * card * scallop;
    float cover = saturate(smoothstep(rMax * 1.06, rMax * 0.46, r) * smoothstep(1.85, 1.15, abs(th)));
    float n = fbm3(float2(th * 1.8 + time * mix(0.35, 0.95, power), r * 5.0 - time * 0.7));
    cover *= 0.78 + 0.22 * n;
    float heat = saturate((1.0 - r / max(rMax, 1e-4) * 0.55) * mix(0.52, 1.0, power));
    heat *= 0.70 + 0.30 * n;
    return emitFire(cover, heat);
}

/// Grid B3 — wide kiln mouth, rising horizontal strata. Power: band contrast, lift, fill.
static float4 shadeForge(float2 p, float time, float power) {
    power = saturate(power);
    float2 q = p;
    q.x += (fbm3(float2(p.x * 2.2, p.y * 3.4 - time * 0.6)) - 0.5) * mix(0.02, 0.07, power);
    float wide = 0.24;
    float tall = mix(0.20, 0.28, power);
    float env = smoothstep(wide, wide * 0.35, abs(q.x));
    env *= smoothstep(-0.03, 0.045, q.y);
    env *= smoothstep(tall, tall * 0.28, q.y);
    float lift = time * mix(0.16, 0.42, power);
    float bands = 0.52 + 0.48 * sin((q.y - lift) * mix(16.0, 26.0, power));
    float n = fbm3(float2(q.x * 5.5, q.y * 7.5 - time * mix(0.45, 1.15, power)));
    float dens = env * bands * (0.68 + 0.32 * n) * mix(0.50, 1.0, power);
    float heat = saturate(dens * (1.05 - saturate(q.y / tall) * 0.25) * mix(0.70, 1.15, power));
    return emitFire(dens, heat);
}

/// Grid B4 — thin wick stem, flare only near the top. Power: flare volume, tip dance, heat.
static float4 shadeWick(float2 p, float time, float power) {
    power = saturate(power);
    float h = 0.44;
    float t = saturate(p.y / h);
    float dance = mix(0.005, 0.020, power) * sin(time * 2.05 + 0.8) * smoothstep(0.45, 0.85, t);
    float2 q = float2(p.x - dance, p.y);
    float stem = 0.016;
    float flare = mix(0.028, 0.095, power) * smoothstep(0.40, 0.76, t);
    float halfW = (stem + flare) * (0.12 + 0.88 * smoothstep(1.06, 0.74, t));
    halfW *= smoothstep(-0.03, 0.05, q.y);
    float d = abs(q.x) / max(halfW, 1e-4);
    float cover = saturate(smoothstep(1.06, 0.40, d) * smoothstep(-0.03, 0.05, q.y) * smoothstep(1.08, 0.75, t));
    float n = fbm3(float2(q.x * 10.0, q.y * 6.0 - time * mix(0.55, 1.40, power)));
    cover *= 0.80 + 0.20 * n;
    float heat = saturate((1.0 - d * 0.58) * mix(0.45, 0.72, t));
    heat *= mix(0.50, 1.0, power);
    heat *= 0.72 + 0.28 * n;
    return emitFire(cover, heat);
}

/// Grid B5 — mushroom bloom: narrow then a sudden crown. Power: crown open, head boil, heat.
static float4 shadeBloom(float2 p, float time, float power) {
    power = saturate(power);
    float h = 0.42;
    float t = saturate(p.y / h);
    float2 q = leanP(p, liveLean(time, 3.1, power) * 0.55);
    q = liveRise(q, time, 5.0, mix(0.04, 0.12, power));
    float stem = 0.038;
    float open = mix(0.04, 0.14, power);
    float crown = open * smoothstep(0.34, 0.58, t) * (1.0 - smoothstep(0.68, 1.02, t));
    float halfW = (stem + crown) * smoothstep(-0.03, 0.05, q.y);
    float d = abs(q.x) / max(halfW, 1e-4);
    float cover = saturate(smoothstep(1.06, 0.44, d) * smoothstep(-0.03, 0.05, q.y) * smoothstep(1.08, 0.76, t));
    float boil = fbm3(float2(q.x * 7.0, q.y * 5.2 - time * mix(0.50, 1.35, power)));
    float head = smoothstep(0.36, 0.62, t);
    cover *= 1.0 - mix(0.04, 0.22, power) * head * (1.0 - boil);
    float heat = saturate((1.0 - d * 0.55) * mix(0.50, 1.0, 0.35 + 0.65 * head));
    heat *= mix(0.50, 1.0, power);
    heat *= 0.70 + 0.30 * boil;
    return emitFire(cover, heat);
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
        addTongue(p, t, h, w * 0.48, -0.02, mix(0.12, 0.22, power), 0.4, dens, heat);
        haze = heatHaze(p, t, h, w, mix(0.08, 0.16, power));
    } else if (kind == 2) {
        float h = mix(0.30, 0.70, power) * flick;
        float w = mix(0.07, 0.14, power);
        float lean = 0.05 * sin(t * 0.45);
        addTongue(p, t, h, w, lean, mix(0.12, 0.22, power), 0.2, dens, heat);
        haze = heatHaze(p, t, h, w, mix(0.06, 0.12, power));
    } else {
        float h = mix(0.24, 0.60, power) * flick;
        float w = mix(0.18, 0.32, power);
        addTongue(p, t, h, w, 0.03, mix(0.14, 0.24, power), 0.6, dens, heat);
        haze = heatHaze(p, t, h, w, mix(0.08, 0.16, power));
    }

    dens *= mix(0.55, 1.0, power);
    heat *= mix(0.78, 1.0, power);
    return composeBright(dens, heat, sparks, haze);
}

fragment float4 fireShadeCandle(FireVertOut in [[stage_in]], constant FireUniforms &u [[buffer(0)]]) {
    return shadeCandle(cellP(in.uv, u.aspect), u.time, u.intensity);
}

fragment float4 fireShadeSpine(FireVertOut in [[stage_in]], constant FireUniforms &u [[buffer(0)]]) {
    return shadeSpine(cellP(in.uv, u.aspect), u.time, u.intensity);
}

fragment float4 fireShadeColumn(FireVertOut in [[stage_in]], constant FireUniforms &u [[buffer(0)]]) {
    return shadeColumn(cellP(in.uv, u.aspect), u.time, u.intensity);
}

fragment float4 fireShadeBowl(FireVertOut in [[stage_in]], constant FireUniforms &u [[buffer(0)]]) {
    return shadeBowl(cellP(in.uv, u.aspect), u.time, u.intensity);
}

fragment float4 fireShadeBlade(FireVertOut in [[stage_in]], constant FireUniforms &u [[buffer(0)]]) {
    return shadeBlade(cellP(in.uv, u.aspect), u.time, u.intensity);
}

fragment float4 fireShadeOrb(FireVertOut in [[stage_in]], constant FireUniforms &u [[buffer(0)]]) {
    return shadeOrb(cellP(in.uv, u.aspect), u.time, u.intensity);
}

fragment float4 fireShadeVolume(FireVertOut in [[stage_in]], constant FireUniforms &u [[buffer(0)]]) {
    return shadeVolume(cellP(in.uv, u.aspect), u.time, u.intensity);
}

fragment float4 fireShadeCurl(FireVertOut in [[stage_in]], constant FireUniforms &u [[buffer(0)]]) {
    return shadeCurl(cellP(in.uv, u.aspect), u.time, u.intensity);
}

fragment float4 fireShadePolar(FireVertOut in [[stage_in]], constant FireUniforms &u [[buffer(0)]]) {
    return shadePolar(cellP(in.uv, u.aspect), u.time, u.intensity);
}

fragment float4 fireShadeForge(FireVertOut in [[stage_in]], constant FireUniforms &u [[buffer(0)]]) {
    return shadeForge(cellP(in.uv, u.aspect), u.time, u.intensity);
}

fragment float4 fireShadeWick(FireVertOut in [[stage_in]], constant FireUniforms &u [[buffer(0)]]) {
    return shadeWick(cellP(in.uv, u.aspect), u.time, u.intensity);
}

fragment float4 fireShadeBloom(FireVertOut in [[stage_in]], constant FireUniforms &u [[buffer(0)]]) {
    return shadeBloom(cellP(in.uv, u.aspect), u.time, u.intensity);
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
    addTongue(q, u.time, h, w, spin * 0.04, mix(0.14, 0.24, power), 0.0, dens, heat);
    float haze = heatHaze(p, u.time, h, w, mix(0.08, 0.14, power));
    return composeBright(dens, heat, 0.0, haze);
}

fragment float4 fireSheetFragment(FireVertOut in [[stage_in]], constant FireUniforms &u [[buffer(0)]]) {
    float2 p = float2((in.uv.x - 0.5) * u.aspect - u.p0, in.uv.y - 0.04);
    float dens = 0.0;
    float heat = 0.0;
    float h = 0.52;
    float w = 0.10;
    addTongue(p, u.time, h, w * 1.4, 0.02, 0.18, 0.5, dens, heat);
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
