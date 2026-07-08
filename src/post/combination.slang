import aperture;

Texture2D mainTexture;

[[shader("pixel")]]
float4 main(float2 pos: SV_Position) {

    float4 color = mainTexture[pos];

    color.rgb = pow(color.rgb, float3(1.0 / 2.2));

    return color;
}
