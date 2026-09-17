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
    d = smin(d, circleSDF(p, float2(u.b0x, u.b0y), u.b0r, u.aspect), 0.11);
    d = smin(d, circleSDF(p, float2(u.b1x, u.b1y), u.b1r, u.aspect), 0.11);
    d = smin(d, circleSDF(p, float2(u.b2x, u.b2y), u.b2r, u.aspect), 0.11);
    d = smin(d, circleSDF(p, float2(u.b3x, u.b3y), u.b3r, u.aspect), 0.11);

    float3 paper = float3(0.957, 0.949, 0.929);
    float contact = smoothstep(0.07, 0.0, d) * (1.0 - smoothstep(0.012, -0.002, d));
    paper *= 1.0 - contact * 0.10;

    float3 mercury = float3(0.68, 0.70, 0.73);
    float3 dark = float3(0.14, 0.16, 0.18);

    float edge = smoothstep(0.009, -0.003, d);
    float rim = smoothstep(0.026, 0.0, d) - smoothstep(0.002, -0.008, d);

    float2 n = normalize(float2(dfdx(d), dfdy(d)) + 1e-5);
    float2 light = normalize(float2(0.40 + u.tiltX * 0.8, -0.74 + u.tiltY * 0.6));
    float spec = pow(saturate(dot(n, light)), 26.0) * edge;
    float spec2 = pow(saturate(dot(n, normalize(float2(-0.55, -0.35)))), 48.0) * edge;
    float fres = pow(1.0 - saturate(abs(n.y)), 2.6) * edge;
    float3 fill = mix(dark, mercury, saturate(0.50 + n.y * 0.40));

    float grain = fract(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453) * 0.012;
    float env = pow(saturate(dot(n, normalize(float2(0.12, -0.96)))), 14.0) * edge;
    float3 col = mix(paper, fill, edge);
    col += spec * 0.70;
    col += spec2 * 0.18;
    col += rim * float3(0.82, 0.85, 0.88) * 0.42;
    col += fres * float3(0.78, 0.82, 0.86) * 0.22;
    col += env * float3(0.93, 0.91, 0.86) * 0.20;
    col += (uv.y * 0.02) + grain;

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

    float ndotv = saturate(0.32 + 0.58 * (1.0 - dist / max(radius, 0.001)));
    ndotv *= saturate(1.0 - length(float2(u.tiltX, u.tiltY)) * 0.22);
    float thickness = 0.20 + 0.16 * sin(uv.x * 9.0 + u.time * 0.42)
                    + 0.11 * cos(uv.y * 12.0 - u.time * 0.33)
                    + 0.07 * sin(uv.x * 22.0 + u.time * 0.55 + u.tiltX)
                    + u.tiltY * 0.15 + u.tiltX * 0.07
                    + u.p0 * 0.12;

    float path = thickness * (0.52 + ndotv);
    float3 lambda = float3(0.63, 0.52, 0.43);
    float3 irid = 0.5 + 0.5 * cos(6.28318 * path / lambda + float3(0.0, 2.094, 4.188));
    irid = pow(clamp(irid, 0.0, 1.0), 1.22);

    float3 paper = float3(0.045, 0.05, 0.065);
    float3 col = mix(paper, irid * 0.92 + 0.05, film * holeMask);
    col += rimHole * float3(0.93, 0.97, 1.0) * 0.78;
    float outer = smoothstep(radius - 0.012, radius, dist) * film;
    col += outer * float3(0.84, 0.93, 1.0) * 0.38;
    float highlight = pow(saturate(0.16 - p.y), 3.0) * film * holeMask;
    col += highlight * 0.20;
    float wire = smoothstep(radius + 0.018, radius + 0.006, dist) * (1.0 - smoothstep(radius + 0.006, radius - 0.002, dist));
    col += wire * float3(0.80, 0.74, 0.52) * 0.55;

    if (hole > radius) {
        col = paper;
    }

    return float4(col, 1.0);
}
