import aperture;
import helpers.util;
import settings;

Texture2D mainTexture;

[[shader("pixel")]]
float4 main(float2 pos: SV_Position) {

    float4 color = mainTexture[pos];

    if (!userSettings.DEBUG_VIEW) {
        color.rgb = decodeColorRgbm16F(color.rgba);

        color.rgb /= 10000.0;
        color = color / (1.0 + color);
    }
   
    color.rgb = pow(color.rgb, float3(1.0 / 2.2));

    return color;
}
