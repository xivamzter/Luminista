import aperture; // Required import. Always.
import object_shader; // Required import for object shaders. Not recommended otherwise.
import settings; // Contains your shader settings, both realtime and compile time.

// What you intend to output (color). Name these with what you have put as the bindings in Java.
struct FragmentOutput {
    float4 color;
    float4 flatNormal;
    float4 lightmap;
    float4 labPBRNormal;
    float4 labPBRSpecular;
}

// What you intend to pass from the vertex shader to the fragment shader. Can have whatever you want.
struct VertexOutput {
    float2 uv : TEXCOORD; // This : TEXCOORD at the end is called a "semantic". It is used to hint to Aperture what it is. Not required, but recommended. In the future, a list of recommended semantics will be provided.
    float3 pos;
    float4 color : COLOR;
    float3 normal;
    float4 tangent;
    float3 light;
}

// TBN matrix thanks to Jake Michie
float3x3 computeTbnMatrix(float3 normal, float4 tangent) {
    float3x3 tbnMatrix;
    tbnMatrix[2] = normal;
    tbnMatrix[0] = tangent.xyz;
    tbnMatrix[1] = cross(tbnMatrix[0], tbnMatrix[2]) * select(tangent.w >= 0.0, 1.0, -1.0);

    return tbnMatrix;
}

float linearStep(float min, float max, float x) {
	return saturate((x - min) / (max - min));
}

struct BasicShader : Shader<VertexOutput, FragmentOutput> {
    static void emitVertex(Vertex input, out VertexOutput output, out float4 pos) {
        pos = input.pos();

        output.uv = input.uv();
        output.pos = input.pos().xyz;
        output.color = input.color();
        output.normal = input.normal().value;
        output.tangent = input.tangent().value;
        output.light = float3(input.lightCoord(), input.vertexAO().value);
    }

    static FragmentOutput shadeSurface(PixelData objectData, VertexOutput input) {

        FragmentOutput output;

        float4 color = input.color;

        if (let texture = objectData.albedo()) { // Since `albedo()` returns an Optional<Sampleable>, this is one of a few ways to get the true type. You can also do albedo().hasValue and albedo().value, of course.
            color *= texture.sampleTexture(input.uv); // Some objects simply don't have a texture, such as clouds
        }

        // This is equivalent to `if (objectIsCutout && alpha < 0.1) discard;`. It will determine if the object needs it.
        ap.discardCutout(color);

        color.rgb = pow(color.rgb, float3(2.2));

        // The following 2 lines were copied from Amaryllis shader
        const float lmcoordLowerBound = 1.0 / 32.0;
        const float lmcoordUpperBound = 31.0 / 32.0;

        ////////// Vanilla stuff //////////

        float vanillaBlockLight = linearStep(lmcoordLowerBound, lmcoordUpperBound, input.light.r);
        float vanillaSkyLight = linearStep(lmcoordLowerBound, lmcoordUpperBound, input.light.g);
        float vanillaAO = pow(input.light.b, float(2.2));

        ////////// LabPBR Normal //////////

        float4 labNormal = float4(0.0, 0.0, 1.0, 0.0);

        // Sample LabPBR normal map
        if (let normalTex = objectData.normal()) {
            labNormal = normalTex.sampleLevel(input.uv, 0);
        }

        // Storing AO and Heightmap before modification
        float labAO = labNormal.b;
        float labHeightmap = labNormal.a;

        // Remap and calculate z component
        labNormal.xy = labNormal.xy * 2.0 - 1.0;
	    labNormal.z = sqrt(1.0 - dot(labNormal.xy, labNormal.xy));

        float3x3 tbn = computeTbnMatrix(input.normal, input.tangent);

        labNormal.xyz = normalize(mul(labNormal.xyz, tbn));

        ////////// LabPBR Specular //////////

        float4 labSpecular = float4(0.0, 0.0, 0.0, 1.0);

        // Sample LabPBR specular map
        if (let specularTex = objectData.specular()) {
            labSpecular = specularTex.sampleTexture(input.uv);
        }

        float roughness = pow(1.0 - (labSpecular.r), 2.0);
        // roughness = float(roughness / 255);

        ////////// OUTPUTS //////////
        output.color = color;
        output.flatNormal = float4(input.normal, 1.0);
        output.lightmap = float4(vanillaBlockLight, vanillaSkyLight, vanillaAO, 1.0);
        output.labPBRNormal = float4(labNormal.xyz, labAO);
        output.labPBRSpecular = float4(roughness, labSpecular.gba);

        return output;
    }
}