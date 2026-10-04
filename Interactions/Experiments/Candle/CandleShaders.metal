#include <metal_stdlib>
using namespace metal;

struct CandleUniforms {
    float time;
    float aspect;
    float power;
    float pad;
};

struct CandleVertOut {
    float4 position [[position]];
    float2 uv;
};

constant float3 kField = float3(0.96, 0.96, 0.96);

/// Ambient wash. Size and strength never follow power.
constant float kHaloAmt = 0.085;
constant float kHaloW2 = 0.0048;
constant float kHaloH2 = 0.0120;

vertex CandleVertOut candleVertex(uint vid [[vertex_id]]) {
    float2 positions[3] = { float2(-1.0, -1.0), float2(3.0, -1.0), float2(-1.0, 3.0) };
    CandleVertOut out;
    out.position = float4(positions[vid], 0.0, 1.0);
    out.uv = positions[vid] * 0.5 + 0.5;
    return out;
}

static float hash21(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453123);
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

static float fbm3(float2 p) {
    float v = 0.5 * valueNoise(p);
    p = p * 2.11 + float2(1.3, 4.7);
    v += 0.25 * valueNoise(p);
    p = p * 2.09 + float2(2.1, 8.3);
    v += 0.125 * valueNoise(p);
    return v;
}

/// One photographed candle. Power retunes core, rim, and body separately — not one scaled sprite.
static float4 candle(float2 p, float time, float power) {
    power = saturate(power);

    float lean = mix(0.040, 0.085, power) * sin(time * 2.05)
               + mix(0.012, 0.028, power) * sin(time * 3.20 + 1.2);
    float breathe = 0.94 + 0.06 * sin(time * 2.70) * sin(time * 1.65 + 0.5);

    float h = mix(0.145, 0.200, power) * breathe;
    float w = mix(0.048, 0.058, power);

    float2 q = p;
    q.y += h * 0.36;
    q.x -= lean * max(q.y, 0.0);

    float ty = saturate(q.y / max(h, 1e-4));
    float2 adv = float2(q.x * 3.6, q.y * 2.2 - time * 0.90);
    float n0 = fbm3(adv);
    float n1 = fbm3(adv * 1.7 + float2(2.4, -time * 0.32));
    float deform = mix(0.016, 0.032, power);
    q.x += (n0 - 0.5) * deform * (0.18 + 0.95 * ty);
    q.y += (n1 - 0.5) * deform * 0.22 * ty;

    float t = q.y / max(h, 1e-4);
    float shape = sqrt(saturate(t + 0.018)) * saturate(1.05 - t);
    float halfW = (w * 0.5) * (shape / 0.43);
    float sd = abs(q.x) - halfW;
    float nx = q.x / max(halfW, 1e-4);

    float raw = exp(-nx * nx * 2.15);
    raw *= smoothstep(-0.012, 0.030, q.y);
    raw *= 1.0 - smoothstep(0.74, 1.05, t);

    float grain = 0.86 + 0.14 * fbm3(float2(q.x * 6.0, q.y * 3.8 - time * 1.10));
    float dens = saturate(raw * grain * mix(0.74, 1.04, power));

    // Rim thickness is a fixed UV band, not a fraction of the envelope.
    float rim = saturate((0.38 - dens) * 2.4) * dens;
    rim *= 1.0 - smoothstep(0.010, 0.0, sd);
    rim *= smoothstep(0.04, 0.14, t);
    rim *= mix(0.70, 1.00, power);

    float coreW = mix(0.009, 0.015, power);
    float coreH = mix(0.018, 0.028, power);
    float coreY = mix(0.038, 0.052, power);
    float cx = q.x / max(coreW, 1e-4);
    float cy = (q.y - coreY) / max(coreH, 1e-4);
    float core = exp(-(cx * cx + cy * cy));
    float coreAmt = mix(0.42, 0.90, power);

    float3 orange = float3(1.00, 0.40, 0.05);
    float3 yellow = float3(1.00, 0.80, 0.16);
    float3 pale = float3(1.00, 0.95, 0.62);
    float3 white = float3(1.00, 0.98, 0.90);

    float body = pow(dens, 0.72);
    float3 fire = mix(orange, yellow, smoothstep(0.10, 0.46, dens * (1.02 - 0.18 * t)));
    fire = mix(fire, pale, smoothstep(0.38, 0.86, dens) * (1.0 - t * 0.30));
    fire = mix(fire, white, saturate(core * dens * coreAmt));
    fire = mix(fire, orange, saturate(rim * 0.45));

    float halo = exp(-(p.x * p.x) / kHaloW2 - (p.y * p.y) / kHaloH2) * kHaloAmt;

    float3 col = kField;
    col = mix(col, float3(1.00, 0.50, 0.10), saturate(halo));
    col = mix(col, fire, saturate(body));
    return float4(col, 1.0);
}

fragment float4 candleFragment(CandleVertOut in [[stage_in]],
                              constant CandleUniforms &u [[buffer(0)]]) {
    float2 p = float2((in.uv.x - 0.5) * u.aspect, in.uv.y - 0.50);
    return candle(p, u.time, saturate(u.power));
}
