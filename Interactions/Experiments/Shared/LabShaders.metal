#include <metal_stdlib>
using namespace metal;

struct LabUniforms {
    float time;
    float aspect;
    float touchX;
    float touchY;
    float tiltX;
    float tiltY;
    float pop;
    float p0;
    float p1;
    float p2;
    float p3;
    float b0x;
    float b0y;
    float b0r;
    float b1x;
    float b1y;
    float b1r;
    float b2x;
    float b2y;
    float b2r;
    float b3x;
    float b3y;
    float b3r;
    float pad;
};

struct VertOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertOut labVertex(uint vid [[vertex_id]]) {
    float2 positions[3] = { float2(-1.0, -1.0), float2(3.0, -1.0), float2(-1.0, 3.0) };
    VertOut out;
    out.position = float4(positions[vid], 0.0, 1.0);
    out.uv = positions[vid] * 0.5 + 0.5;
    out.uv.y = 1.0 - out.uv.y;
    return out;
}

static float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

static float circleSDF(float2 p, float2 c, float r, float aspect) {
    float2 d = p - c;
    d.x *= aspect;
    return length(d) - r;
}

fragment float4 metaballFragment(VertOut in [[stage_in]], constant LabUniforms &u [[buffer(0)]]) {
    float2 uv = in.uv;
    float2 p = uv;

    float d = 1e5;
    d = smin(d, circleSDF(p, float2(u.b0x, u.b0y), u.b0r, u.aspect), 0.10);
    d = smin(d, circleSDF(p, float2(u.b1x, u.b1y), u.b1r, u.aspect), 0.10);
    d = smin(d, circleSDF(p, float2(u.b2x, u.b2y), u.b2r, u.aspect), 0.10);
    d = smin(d, circleSDF(p, float2(u.b3x, u.b3y), u.b3r, u.aspect), 0.10);

    float3 paper = float3(0.925, 0.914, 0.890);
    float3 mercury = float3(0.62, 0.64, 0.66);
    float3 dark = float3(0.18, 0.20, 0.22);

    float edge = smoothstep(0.012, -0.004, d);
    float rim = smoothstep(0.03, 0.0, d) - smoothstep(0.004, -0.01, d);

    float2 n = normalize(float2(dFdx(d), dFdy(d)) + 1e-5);
    float2 light = normalize(float2(0.35 + u.tiltX, -0.7 + u.tiltY));
    float spec = pow(saturate(dot(n, light)), 18.0) * edge;
    float fill = mix(dark, mercury, saturate(0.45 + n.y * 0.35));

    float3 col = mix(paper, fill, edge);
    col += spec * 0.55;
    col += rim * float3(0.75, 0.78, 0.80) * 0.35;
    col += (uv.y * 0.03);

    return float4(col, 1.0);
}

fragment float4 soapFragment(VertOut in [[stage_in]], constant LabUniforms &u [[buffer(0)]]) {
    float2 uv = in.uv;
    float2 p = (uv - 0.5) * float2(u.aspect, 1.0);
    float radius = 0.38;
    float dist = length(p);
    float film = smoothstep(radius + 0.004, radius - 0.002, dist);

    float hole = u.pop;
    float holeMask = smoothstep(hole - 0.01, hole + 0.012, dist);
    float rimHole = smoothstep(hole - 0.018, hole, dist) * (1.0 - smoothstep(hole, hole + 0.02, dist));

    float ndotv = saturate(0.35 + 0.55 * (1.0 - dist / max(radius, 0.001)));
    ndotv *= saturate(1.0 - length(float2(u.tiltX, u.tiltY)) * 0.25);
    float thickness = 0.22 + 0.18 * sin(uv.x * 9.0 + u.time * 0.4)
                    + 0.12 * cos(uv.y * 11.0 - u.time * 0.3)
                    + u.tiltY * 0.16 + u.tiltX * 0.08
                    + u.p0 * 0.12;

    float path = thickness * (0.55 + ndotv);
    float3 lambda = float3(0.62, 0.51, 0.42);
    float3 irid = 0.5 + 0.5 * cos(6.28318 * path / lambda + float3(0.0, 2.094, 4.188));
    irid = pow(clamp(irid, 0.0, 1.0), 1.35);

    float3 paper = float3(0.06, 0.07, 0.09);
    float3 col = mix(paper, irid * 0.85 + 0.08, film * holeMask);
    col += rimHole * float3(0.9, 0.95, 1.0) * 0.65;
    float outer = smoothstep(radius - 0.01, radius, dist) * film;
    col += outer * float3(0.8, 0.9, 1.0) * 0.25;

    if (hole > radius) {
        col = paper;
    }

    return float4(col, 1.0);
}
