import aperture;
import helpers.util;
import settings;

Texture2D mainTexture;
StructuredBuffer<float2> exposureBuffer;

[[shader("pixel")]]
float4 main(float2 pos: SV_Position) {

    float4 color = mainTexture[pos];

    float exposure = exposureBuffer[0].y;

    if (!userSettings.DEBUG_VIEW) {
        color.rgb = decodeColorRgbm16F(color.rgba);
        // color.rgb /= 10000.0;

        color.rgb *= exposure;

        color.rgb = color.rgb / (1.0 + color.rgb);
    }
   
    color.rgb = pow(color.rgb, float3(1.0 / 2.2));

    return color;
}
