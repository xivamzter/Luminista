import aperture; // Required import. Always.
import object_shader; // Required import for object shaders. Not recommended otherwise.
import settings; // Contains your shader settings, both realtime and compile time.

// Imports `helpers/shadows.slang`, since it is declared with `public module shadows`. See the Slang user guide for more info if confused.
import helpers.shadows;
import helpers.shadowSampling;

// What you intend to output (color). Name these with what you have put as the bindings in Java.
struct Out {
    float4 color;
}

// What you intend to pass from the vertex shader to the fragment shader. Can have whatever you want.
struct VOut {
    float2 uv : TEXCOORD; // This : TEXCOORD at the end is called a "semantic". It is used to hint to Aperture what it is. Not required, but recommended. In the future, a list of recommended semantics will be provided.
    float3 pos;
    float4 color : COLOR;
    float3 normal;
    float vertexAO;
}

struct BasicShader : Shader<VOut, Out> {
    static void emitVertex(Vertex input, out VOut data, out float4 pos) {
        // Generally, `v.pos()` will be in camera-relative world space. This might not be the case for all objects in beta 1, please report if this becomes a major issue for you.

        float3 normal = input.normal().value;

        pos = input.pos();

        data = VOut(
            input.uv(),
            pos.xyz,
            input.color(),
            normal,
            input.vertexAO().hasValue ? input.vertexAO().value : 1.00);
    }

    static Out shadeSurface(PixelData objectData, VOut input) {

        float4 color = input.color;
        float3 flatNormal = input.normal;

        if (let texture = objectData.albedo()) { // Since `albedo()` returns an Optional<Sampleable>, this is one of a few ways to get the true type. You can also do albedo().hasValue and albedo().value, of course.
            color *= texture.sampleTexture(input.uv); // Some objects simply don't have a texture, such as clouds
        }

        // This is equivalent to `if (objectIsCutout && alpha < 0.1) discard;`. It will determine if the object needs it.
        ap.discardCutout(color);

        // Refer to your `TemplatePackSettings`. Hit that `Generate Shader Settings` button there to regenerate the GPU-side.
        // if (userSettings.shadows) {
        //     color.rgb *= lerp(0.3, 1.0, shadowVisibility(input.pos));
        // }

        float3 shadow = lerp(0.3, 1.0, shadowVisibility(input.pos));
        // float3 shadow = lerp(0.3, 1.0, shadowVisibility1(input.pos, flatNormal));

        float3 lightVec = mul(ap.camera.viewInv, float4(normalize(ap.celestial.sunPosition), 0.0)).xyz;
        float3 dirLight = shadow * saturate(dot(flatNormal, lightVec));

        if (userSettings.shadows) {
            color.rgb *= shadow * input.vertexAO;
        }

        color.rgb = pow(color.rgb, float3(2.2));

        Out output;
        // output.color = float4(flatNormal, 1.0);
        output.color = color;
        // output.color = float4(float3(depth), 1.0);

        return output;
    }
}