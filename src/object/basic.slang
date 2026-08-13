import aperture; // Required import. Always.
import object_shader; // Required import for object shaders. Not recommended otherwise.
import settings; // Contains your shader settings, both realtime and compile time.

// What you intend to output (color). Name these with what you have put as the bindings in Java.
struct Out {
    float4 color;
    float4 flatNormal;
    float4 tangent;
    float4 normalTexture;
    float4 specularTexture;
}

// What you intend to pass from the vertex shader to the fragment shader. Can have whatever you want.
struct VOut {
    float2 uv : TEXCOORD; // This : TEXCOORD at the end is called a "semantic". It is used to hint to Aperture what it is. Not required, but recommended. In the future, a list of recommended semantics will be provided.
    float3 pos;
    float4 color : COLOR;
    float3 normal;
    float vertexAO;
    float4 tangent;
}

float3 projectAndDivide(float4x4 invProj, float3 pos) {
    float4 homePos = mul(invProj, float4(pos, 1.0));
    return homePos.xyz / homePos.w;
}

struct BasicShader : Shader<VOut, Out> {
    static void emitVertex(Vertex input, out VOut data, out float4 pos) {
        // Generally, `v.pos()` will be in camera-relative world space. This might not be the case for all objects in beta 1, please report if this becomes a major issue for you.

        pos = input.pos();

        data = VOut(
            input.uv(),
            pos.xyz,
            input.color(),
            input.normal().value,
            input.vertexAO().value,
            input.tangent().value
        );
    }

    static Out shadeSurface(PixelData objectData, VOut input) {

        float4 color = input.color;

        if (let texture = objectData.albedo()) { // Since `albedo()` returns an Optional<Sampleable>, this is one of a few ways to get the true type. You can also do albedo().hasValue and albedo().value, of course.
            color *= texture.sampleTexture(input.uv); // Some objects simply don't have a texture, such as clouds
        }

        // This is equivalent to `if (objectIsCutout && alpha < 0.1) discard;`. It will determine if the object needs it.
        ap.discardCutout(color);

        // Refer to your `TemplatePackSettings`. Hit that `Generate Shader Settings` button there to regenerate the GPU-side.
        // if (userSettings.shadows) {
        //     color.rgb *= lerp(0.3, 1.0, shadowVisibility(input.pos));
        // }

        color.rgb = pow(color.rgb, float3(2.2));
        float vanillaAO = pow(input.vertexAO, float(2.2));

        Out output;
        output.color = color;
        output.flatNormal = float4(input.normal, vanillaAO);
        output.tangent = input.tangent;
        output.normalTexture = float4(0.5, 0.5, 1.0, 1.0);
        if (let normalTex = objectData.normal()) {
            output.normalTexture = normalTex.sampleTexture(input.uv);
        }
        output.specularTexture = float4(0.0, 0.0, 0.0, 1.0);
        if (let specularTex = objectData.specular()) {
            output.specularTexture = specularTex.sampleTexture(input.uv);
        }

        return output;
    }
}