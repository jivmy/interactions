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

/// One photographed candle. Power only changes how strongly this same flame burns.
static float4 candle(float2 p, float time, float power) {
    power = saturate(power);

    float lean = mix(0.050, 0.100, power) * sin(time * 2.05)
               + mix(0.016, 0.034, power) * sin(time * 3.20 + 1.2);
    float breathe = 0.93 + 0.07 * sin(time * 2.70) * sin(time * 1.65 + 0.5);

    float h = mix(0.26, 0.40, power) * breathe;
    float w = h / 3.2;

    float2 q = p;
    q.x -= lean * max(q.y, 0.0);

    float ty = saturate(q.y / max(h, 1e-4));
    float2 adv = float2(q.x * 3.6, q.y * 2.2 - time * 0.90);
    float n0 = fbm3(adv);
    float n1 = fbm3(adv * 1.7 + float2(2.4, -time * 0.32));
    float deform = mix(0.024, 0.048, power);
    q.x += (n0 - 0.5) * deform * (0.18 + 0.95 * ty);
    q.y += (n1 - 0.5) * deform * 0.22 * ty;

    float t = q.y / max(h, 1e-4);
    float shape = sqrt(saturate(t + 0.018)) * saturate(1.05 - t);
    float halfW = (w * 0.5) * (shape / 0.43);
    float nx = q.x / max(halfW, 1e-4);

    float raw = exp(-nx * nx * 2.15);
    raw *= smoothstep(-0.014, 0.038, q.y);
    raw *= 1.0 - smoothstep(0.74, 1.05, t);

    float grain = 0.86 + 0.14 * fbm3(float2(q.x * 6.0, q.y * 3.8 - time * 1.10));
    float dens = saturate(raw * grain * mix(0.80, 1.04, power));

    float cx = q.x / max(w * 0.18, 1e-4);
    float cy = (q.y - h * 0.24) / max(h * 0.16, 1e-4);
    float core = exp(-(cx * cx + cy * cy));

    float3 orange = float3(1.00, 0.40, 0.05);
    float3 yellow = float3(1.00, 0.80, 0.16);
    float3 pale = float3(1.00, 0.95, 0.62);
    float3 white = float3(1.00, 0.98, 0.90);

    float body = pow(dens, 0.72);
    float3 fire = mix(orange, yellow, smoothstep(0.10, 0.42, dens * (1.05 - 0.25 * t)));
    fire = mix(fire, pale, smoothstep(0.35, 0.85, dens) * (1.0 - t * 0.35));
    fire = mix(fire, white, saturate(core * dens * mix(0.50, 0.80, power)));

    float2 r = p;
    r.x -= lean * max(r.y, 0.0);
    float halo = exp(-(r.x * r.x) / max(w * w * 5.0, 1e-5)
                     - (r.y * r.y) / max(h * h * 0.62, 1e-5));
    halo *= mix(0.08, 0.16, power);

    float3 col = kField;
    col = mix(col, float3(1.00, 0.50, 0.10), saturate(halo));
    col = mix(col, fire, saturate(body));
    return float4(col, 1.0);
}

fragment float4 candleFragment(CandleVertOut in [[stage_in]],
                              constant CandleUniforms &u [[buffer(0)]]) {
    float2 p = float2((in.uv.x - 0.5) * u.aspect, in.uv.y - 0.22);
    return candle(p, u.time, saturate(u.power));
}
