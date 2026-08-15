import aperture;
import helpers.util;

public float ndf(float nDotH, float roughness) {
    float a = roughness * roughness;
    float a2 = a * a;

    float nDotH2 = nDotH * nDotH;

    float nom = a2;
    float denom = (nDotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;

    return nom / denom;
}

public float geometrySchlickGGX(float nDotX, float roughness) {
    float r = (roughness + 1.0);
    float k = (r*r) / 8.0;

    float nom = nDotX;
    float denom = nDotX * (1.0 - k) + k;

    return nom / denom;
}

public float geometrySmith(float nDotV, float nDotL, float roughness) {

    float ggx1 = geometrySchlickGGX(nDotV, roughness);
    float ggx2 = geometrySchlickGGX(nDotL, roughness);

    return ggx1 * ggx2;
}

public float3 fresnelSchlick(float cosTheta, float3 F0) {
    return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

public float3 fresnalLazanyi2019(in float cosTheta, in float3 f0, in float3 f82) {
    float3 a = (823543.0 / 46656.0) * (f0 - f82) + (49.0 / 6.0) * (1.0 - f0);

    return f0 + (1.0 - f0) * pow(1.0 - cosTheta, 5.0) - a * cosTheta * pow(1.0 - cosTheta, 6.0);
}

public float3 SrgbToLinear(float3 c) {
    return pow(c, float3(2.2));
}

struct LabConductorData {
    float3 f0;
    float3 f82;
}

LabConductorData getLabConductorData(in int conductor, in float3 albedo) {
    LabConductorData data;

    if (conductor == 230) {
        // Iron
        data.f0 = SrgbToLinear(float3(0.78, 0.77, 0.74));
        data.f82 = SrgbToLinear(float3(0.75, 0.76, 0.74));
        // Gold
    } else if (conductor == 231) {
        data.f0 = SrgbToLinear(float3(1.00, 0.90, 0.61));
        data.f82 = SrgbToLinear(float3(1.00, 0.92, 0.73));
        // Copper
    } else if (conductor == 234) {
        data.f0 = SrgbToLinear(float3(1.00, 0.89, 0.73));
        data.f82 = SrgbToLinear(float3(1.00, 0.90, 0.80));
        // Default
    } else if (conductor == 255) {
        data.f0 = albedo;
        data.f82 = albedo;
    } else {
        data.f0 = float3(0.04);
        data.f82 = float3(0.04);
    }

    return data;
}

public float3 brdf(float3 l, float3 v, float3 albedo, float reflectance, float3 n, float roughness, float radiance, out float3 debugF0) {

    float3 oL = float3(0.0);

    float metallic = 0.0;
    float3 f0 = float3(0.00);
    float3 f82 = float3(0.00);
    float3 F = float3(0.00);

    float3 h = normalize(v + l);
    float cosTheta = clamp(dot(v, h), 0.0, 1.0);

    float nDotH = clamp(dot(n, h), 0.0, 1.0);
    float nDotV = clamp(dot(n, v), 0.0, 1.0);
    float nDotL = clamp(dot(n, l), 0.0, 1.0);

    int conductor = int(round(reflectance * 255.0));

    LabConductorData conductorData = getLabConductorData(conductor, albedo);

    if (conductor == 255) {
        f0 = albedo;
        metallic = 1.0;

        F = fresnelSchlick(cosTheta, f0);
    } else if (conductor >= 230 && conductor <= 254) {
        f0 = conductorData.f0;
        f82 = conductorData.f82;
        metallic = 1.0;

        F = fresnalLazanyi2019(cosTheta, f0, f82);
    } else if (conductor >= 1 && conductor <= 229) {
        f0 = float3(float(conductor) / 255.0);

        F = fresnelSchlick(cosTheta, f0);
    } else {
        f0 = float3(0.04);

        F = fresnelSchlick(cosTheta, f0);
    }

    debugF0 = f0;

    float NDF = ndf(nDotH, roughness);
    float G = geometrySmith(nDotV, nDotL, roughness);

    float3 kS = F;
    float3 kD = float3(1.0) - kS;
    kD *= 1.0 - metallic;

    float3 nom = NDF * G * F;
    float denom = 4.0 * nDotV * nDotL + 1e-5;
    float3 specular = nom / denom;

    // add to outgoing radiance oL
    
    oL += (kD * albedo / PI + specular) * radiance * nDotL;

    return oL;
}


