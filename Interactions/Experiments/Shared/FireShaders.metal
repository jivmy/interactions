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

static float3 fireRamp(float t) {
    t = saturate(t);
    float3 c = mix(float3(0.20, 0.02, 0.00), float3(0.92, 0.16, 0.02), smoothstep(0.0, 0.28, t));
    c = mix(c, float3(1.00, 0.48, 0.05), smoothstep(0.28, 0.55, t));
    c = mix(c, float3(1.00, 0.86, 0.22), smoothstep(0.55, 0.80, t));
    c = mix(c, float3(1.00, 0.98, 0.88), smoothstep(0.80, 1.0, t));
    return c;
}

static float3 plasmaRamp(float t) {
    t = saturate(t);
    float3 c = mix(float3(0.18, 0.02, 0.42), float3(0.45, 0.12, 0.95), smoothstep(0.0, 0.35, t));
    c = mix(c, float3(0.20, 0.72, 1.00), smoothstep(0.35, 0.65, t));
    c = mix(c, float3(0.92, 0.98, 1.00), smoothstep(0.65, 1.0, t));
    return c;
}

static float3 jetRamp(float t) {
    t = saturate(t);
    float3 c = mix(float3(0.05, 0.12, 0.55), float3(0.15, 0.48, 1.00), smoothstep(0.0, 0.35, t));
    c = mix(c, float3(0.55, 0.88, 1.00), smoothstep(0.35, 0.7, t));
    c = mix(c, float3(1.00, 0.98, 0.95), smoothstep(0.7, 1.0, t));
    return c;
}

static float3 lavaRamp(float t) {
    t = saturate(t);
    float3 c = mix(float3(0.12, 0.02, 0.01), float3(0.70, 0.08, 0.02), smoothstep(0.0, 0.35, t));
    c = mix(c, float3(1.00, 0.28, 0.04), smoothstep(0.35, 0.65, t));
    c = mix(c, float3(1.00, 0.78, 0.20), smoothstep(0.65, 1.0, t));
    return c;
}

static float3 overField(float3 fire, float alpha) {
    return mix(kField, fire, saturate(alpha));
}

static float teardrop(float2 p, float h, float w) {
    float yy = saturate(p.y / max(h, 1e-4));
    float waist = w * (1.05 - yy * yy);
    float dx = abs(p.x) / max(waist, 1e-4);
    float body = smoothstep(1.05, 0.28, dx);
    body *= smoothstep(-0.04, 0.06, p.y);
    body *= smoothstep(h, h * 0.62, p.y);
    return saturate(body);
}

static float2 domainWarp(float2 p, float time, float scale) {
    float2 q = float2(fbm(p * scale + float2(0.0, -time)), fbm(p * scale + float2(3.2, -time * 1.1)));
    return p + (q - 0.5) * 0.55;
}

static float volumeFire(float2 p, float time, float height, float width) {
    float mask = teardrop(p, height, width);
    float2 q = domainWarp(float2(p.x * 3.4, p.y * 2.6 - time * 1.35), time, 1.0);
    float n = fbm(q);
    float tip = saturate(p.y / max(height, 1e-4));
    return saturate(mask * (n * 1.35 + 0.15) * (1.15 - tip * 0.35));
}

static float pixelFire(float2 p, float time, float height, float width, float power) {
    float2 grid = float2(16.0, 24.0);
    float2 cell = floor((p + float2(width, 0.0)) * float2(grid.x / max(width * 2.0, 1e-4), grid.y / max(height, 1e-4)));
    float rise = hash21(cell + floor(time * mix(6.0, 18.0, power)));
    float column = saturate(1.0 - cell.y / grid.y);
    float heat = pow(column, mix(2.4, 1.05, power)) * (0.45 + 0.55 * rise);
    float2 local = fract((p + float2(width, 0.0)) * float2(grid.x / max(width * 2.0, 1e-4), grid.y / max(height, 1e-4)));
    float voxel = 1.0 - smoothstep(0.42, 0.5, max(abs(local.x - 0.5), abs(local.y - 0.5)));
    float mask = smoothstep(width * 1.05, width * 0.15, abs(p.x)) * smoothstep(-0.02, 0.04, p.y) * smoothstep(height, height * 0.2, p.y);
    return saturate(heat * voxel * mask * (0.35 + 0.9 * power));
}

static float emberFire(float2 p, float time, float height, float width, float power) {
    float coals = smoothstep(width * 0.55, 0.0, length(float2(p.x, p.y * 2.2))) * (0.2 + 0.8 * power);
    float sparks = 0.0;
    for (int i = 0; i < 22; i++) {
        float id = float(i) + 11.0;
        float2 rnd = hash22(float2(id, 3.7));
        float life = fract(time * mix(0.35, 1.15, power) * (0.45 + rnd.y) + rnd.x);
        float2 pos = float2((rnd.x - 0.5) * width * 1.6, life * height * (0.45 + 0.7 * power));
        pos.x += sin(life * 9.0 + id) * 0.04;
        float r = mix(0.018, 0.008, life) * mix(0.6, 1.35, power);
        sparks += smoothstep(r, 0.0, length(p - pos)) * (1.0 - life);
    }
    return saturate(coals + sparks);
}

static float plasmaFire(float2 p, float time, float height, float width, float power) {
    float2 c = p - float2(0.0, height * 0.38);
    c.x *= 1.05;
    float r = length(c) / max(mix(0.10, 0.38, power), 1e-4);
    float a = atan2(c.y, c.x);
    float tendril = 0.0;
    for (int i = 0; i < 6; i++) {
        float ang = a * (2.0 + float(i)) + time * (1.2 + float(i) * 0.35);
        tendril += exp(-12.0 * abs(sin(ang) + r * 1.4 - 0.6));
    }
    float core = exp(-r * r * 4.5);
    float field = exp(-r * 2.2) * (0.25 + 0.75 * power);
    return saturate(field + core * 1.1 + tendril * 0.55 * power);
}

static float ribbonFire(float2 p, float time, float height, float width, float power) {
    float acc = 0.0;
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        float phase = fi * 1.17 + time * mix(1.6, 4.8, power);
        float y = saturate(p.y / max(height, 1e-4));
        float x = p.x - sin(y * (2.2 + fi * 0.7) * 3.14159 + phase) * width * mix(0.25, 0.85, power) * y;
        float band = exp(-pow(x / max(width * mix(0.10, 0.22, power), 1e-4), 2.0) * 6.0);
        band *= smoothstep(0.0, 0.08, y) * smoothstep(1.0, 0.55, y);
        acc += band * mix(0.35, 1.0, 1.0 - fi * 0.12);
    }
    return saturate(acc);
}

static float jetFire(float2 p, float time, float height, float width) {
    float yy = saturate(p.y / max(height, 1e-4));
    float cone = mix(width, width * 0.12, pow(yy, 0.65));
    float dx = abs(p.x) / max(cone, 1e-4);
    float mask = smoothstep(1.0, 0.2, dx) * smoothstep(-0.02, 0.03, p.y) * (1.0 - smoothstep(0.82, 1.0, yy));
    float2 q = float2(p.x * 18.0, p.y * 6.0 - time * 8.0);
    float turb = fbm(q);
    return saturate(mask * (0.45 + turb * 0.9));
}

static float moltenFire(float2 p, float time, float height, float width, float power) {
    float2 blob = p - float2(0.0, height * 0.08);
    blob.x /= max(width * (1.0 + 0.08 * sin(time * 2.4)), 1e-4);
    blob.y /= max(height * 0.22, 1e-4);
    float puddle = exp(-dot(blob, blob) * 2.6);
    float drips = 0.0;
    for (int i = 0; i < 5; i++) {
        float id = float(i);
        float x = (hash21(float2(id, 2.2)) - 0.5) * width * 0.9;
        float fall = fract(time * mix(0.15, 0.55, power) + hash21(float2(id, 8.1)));
        float2 d = p - float2(x, -fall * height * 0.85);
        d.x *= 3.2;
        drips += exp(-dot(d, d) * 90.0) * (1.0 - fall);
    }
    float crust = fbm(p * 7.0 + time * 0.15);
    return saturate(puddle * (0.7 + 0.4 * crust) + drips * power);
}

static float vortexFire(float2 p, float time, float height, float width, float power) {
    float2 c = p - float2(0.0, height * 0.28);
    float r = length(c) / max(mix(0.08, width, power), 1e-4);
    float a = atan2(c.y, c.x) + r * 3.5 - time * mix(1.2, 4.2, power);
    float arms = pow(saturate(0.55 + 0.45 * sin(a * 3.0)), 2.2);
    float funnel = exp(-r * 1.6) * smoothstep(1.35, 0.15, r);
    float n = fbm(float2(a * 0.6, r * 3.0 - time * 1.4));
    return saturate(funnel * (arms + n * 0.65));
}

static float4 shadeStyle(int style, float2 p, float time, float power) {
    float h = mix(0.16, 0.78, power);
    float w = mix(0.08, 0.28, power);
    float t = 0.0;
    float3 ramp = fireRamp(0.0);
    if (style == 0) {
        t = volumeFire(p, time, h, w);
        ramp = fireRamp(t);
    } else if (style == 1) {
        t = pixelFire(p, time, h, w * 1.15, power);
        ramp = fireRamp(t);
    } else if (style == 2) {
        t = emberFire(p, time, h, w, power);
        ramp = fireRamp(t * 1.1);
    } else if (style == 3) {
        t = plasmaFire(p, time, h, w, power);
        ramp = plasmaRamp(t);
    } else if (style == 4) {
        t = ribbonFire(p, time, h, w, power);
        ramp = fireRamp(t);
    } else if (style == 5) {
        t = jetFire(p, time, mix(0.20, 0.86, power), mix(0.04, 0.12, power));
        ramp = jetRamp(t);
    } else if (style == 6) {
        t = moltenFire(p, time, h, w * 1.2, power);
        ramp = lavaRamp(t);
    } else {
        t = vortexFire(p, time, h, w, power);
        ramp = fireRamp(t);
    }
    return float4(overField(ramp, t), 1.0);
}

fragment float4 fireballsFragment(FireVertOut in [[stage_in]], constant FireUniforms &u [[buffer(0)]]) {
    float2 uv = in.uv;
    float top = 0.075;
    float bottom = 0.145;
    float usable = 1.0 - top - bottom;
    if (uv.y < bottom || uv.y > 1.0 - top) {
        return float4(kField, 1.0);
    }

    float gx = uv.x * 2.0;
    float gy = (uv.y - bottom) / usable * 4.0;
    int col = int(clamp(floor(gx), 0.0, 1.0));
    int row = int(clamp(floor(gy), 0.0, 3.0));
    int style = (3 - row) * 2 + col;
    float2 local = float2(fract(gx), fract(gy));
    float cellAspect = (u.aspect * 0.5) / max(usable * 0.25, 1e-4);
    float2 p = float2((local.x - 0.5) * cellAspect, local.y - 0.16);
    return shadeStyle(style, p, u.time, saturate(u.intensity));
}

fragment float4 breathFireFragment(FireVertOut in [[stage_in]], constant FireUniforms &u [[buffer(0)]]) {
    float2 uv = in.uv;
    float2 p = float2((uv.x - 0.5) * u.aspect, uv.y - 0.22);
    float heat = saturate(u.intensity);
    float h = mix(0.08, 0.62, heat);
    float w = mix(0.06, 0.30, heat);
    float t = volumeFire(p, u.time, h, w);
    t += emberFire(p, u.time, h, w, heat) * 0.45;
    float3 col = fireRamp(t);
    float stain = exp(-length(float2(p.x, p.y * 0.7)) * mix(8.0, 2.4, heat)) * heat * 0.22;
    col = overField(mix(col, float3(1.0, 0.45, 0.06), stain), max(t, stain));
    return float4(col, 1.0);
}

fragment float4 fireLeanFragment(FireVertOut in [[stage_in]], constant FireUniforms &u [[buffer(0)]]) {
    float2 uv = in.uv;
    float2 p = float2((uv.x - 0.5) * u.aspect, uv.y - 0.18);
    float2 lean = float2(u.tiltX, u.tiltY);
    p.x -= lean.x * p.y * 1.15;
    p.y += lean.y * 0.08;
    float power = saturate(0.55 + length(lean) * 0.35);
    float t = volumeFire(p, u.time, mix(0.42, 0.70, power), mix(0.12, 0.22, power));
    return float4(overField(fireRamp(t), t), 1.0);
}

fragment float4 fireTrailFragment(FireVertOut in [[stage_in]],
                                 constant FireUniforms &u [[buffer(0)]],
                                 constant FirePoint *points [[buffer(1)]]) {
    float2 uv = in.uv;
    float2 p = float2(uv.x * u.aspect, uv.y);
    float acc = 0.0;
    for (int i = 0; i < 24; i++) {
        float s = points[i].strength;
        if (s < 0.01) {
            continue;
        }
        float2 q = float2(points[i].x * u.aspect, points[i].y);
        float age = saturate(points[i].age);
        float2 d = p - q;
        float2 warped = domainWarp(d * 8.0 + float2(0.0, -u.time * 1.6), u.time, 1.0);
        float n = fbm(warped);
        float rad = mix(0.08, 0.028, age) * s;
        float core = exp(-dot(d, d) / max(rad * rad, 1e-5));
        acc += core * (0.45 + 0.7 * n) * (1.0 - age) * s;
    }
    acc = saturate(acc);
    return float4(overField(fireRamp(acc), acc), 1.0);
}

fragment float4 fireWhirlFragment(FireVertOut in [[stage_in]], constant FireUniforms &u [[buffer(0)]]) {
    float2 uv = in.uv;
    float2 p = float2((uv.x - 0.5) * u.aspect, uv.y - 0.22);
    float spin = u.spin;
    float r = length(p);
    float a = atan2(p.y, p.x) + r * 4.2 - u.time * (1.0 + abs(spin) * 6.0) - spin * 0.8;
    float funnel = exp(-r * mix(3.4, 1.3, saturate(abs(spin)))) * smoothstep(0.85, 0.05, r);
    float arms = pow(saturate(0.5 + 0.5 * sin(a * 3.0)), 1.8);
    float n = fbm(float2(a, r * 4.0 - u.time * 2.0));
    float t = saturate(funnel * (arms + n * 0.7) * mix(0.25, 1.15, saturate(abs(spin))));
    return float4(overField(fireRamp(t), t), 1.0);
}

fragment float4 fireSheetFragment(FireVertOut in [[stage_in]], constant FireUniforms &u [[buffer(0)]]) {
    float2 uv = in.uv;
    float2 p = float2((uv.x - 0.5) * u.aspect - u.p0, uv.y);
    float2 q = domainWarp(float2(p.x * 2.2, p.y * 3.4 - u.time * 1.1), u.time, 1.4);
    float n = fbm(q * 2.4);
    float curtain = smoothstep(0.42, 0.08, abs(p.x)) * smoothstep(0.02, 0.12, p.y);
    float t = saturate(curtain * (n * 1.25 + 0.1));
    return float4(overField(fireRamp(t), t), 1.0);
}

fragment float4 fireStrikeFragment(FireVertOut in [[stage_in]], constant FireUniforms &u [[buffer(0)]]) {
    float2 uv = in.uv;
    float2 p = float2((uv.x - 0.5) * u.aspect, uv.y - 0.20);
    float heat = saturate(u.intensity);
    float streak = exp(-pow(abs(p.x * u.prevX - p.y * u.prevY), 2.0) * 28.0) * u.touching * 0.35;
    float t = volumeFire(p, u.time, mix(0.06, 0.66, heat), mix(0.05, 0.24, heat));
    t = saturate(t + streak);
    return float4(overField(fireRamp(t), t), 1.0);
}
