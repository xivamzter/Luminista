import aperture;
import object_shader;

struct PixelOut {}

struct Interpolants {}

struct BasicShader : Shader<Interpolants, PixelOut> {
    static void emitVertex(Vertex vertex, out Interpolants interpOut, out float4 position) {
        position = vertex.pos();
    }

    static PixelOut shadeSurface(PixelData objectData, Interpolants interpIn) {

        discard;
   
        return {};
    }
}