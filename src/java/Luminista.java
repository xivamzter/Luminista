import org.joml.Vector4f;

import dev.irisshaders.aperture.api.*;
import dev.irisshaders.aperture.api.objects.*;
import dev.irisshaders.aperture.api.pipeline.*;
import dev.irisshaders.aperture.api.renderer.*;

public class Luminista implements ShaderPack {

    @Override
    public void configurePipeline(Screen screen, PipelineConfig pipeline) {
        pipeline.combinationPass("post/combination");

        var mainTexture = pipeline.texture2D("mainTexture", TextureFormat.RGBA16_SFLOAT).renderSize().create();
        var flatNormalTexture = pipeline.texture2D("flatNormalTexture", TextureFormat.RGBA16_SFLOAT).renderSize().create();
        var lightmapTexture = pipeline.texture2D("lightmapTexture", TextureFormat.RGBA8_UNORM).renderSize().create();
        var labPBRNormalTexture = pipeline.texture2D("labPBRNormalTexture", TextureFormat.RGBA16_SFLOAT).renderSize().create();
        var labPBRSpecularTexture = pipeline.texture2D("labPBRSpecularTexture", TextureFormat.RGBA8_UNORM).renderSize().create();

        var skyScatteringTexture = pipeline.texture2D("skyScatteringTexture", TextureFormat.RGBA16_SFLOAT).size(screen.renderWidth() / 2, screen.renderHeight() / 2).create();
        var skyTransmittanceTexture = pipeline.texture2D("skyTransmittanceTexture", TextureFormat.RGBA16_SFLOAT).size(screen.renderWidth() / 2, screen.renderHeight() / 2).create();
        var ambientScatteringTexture = pipeline.texture2D("ambientScatteringTexture", TextureFormat.RGBA16_SFLOAT).size(1, 1).create();

        Buffer luminanceHistogramBuffer = pipeline.buffer("luminanceHistogramBuffer", Integer.BYTES * 256);
        Buffer exposureBuffer = pipeline.buffer("exposureBuffer", Integer.BYTES * 256);

        if (pipeline.settings().getBoolValue("SHADOW_ENABLED"))
        pipeline.object(ProgramUsage.SHADOW, "object/shadow", "ShadowShader");
        pipeline.object(ProgramUsage.SKYBOX, "object/skybox", "BasicShader");
        pipeline.object(ProgramUsage.BASIC, "object/basic", "BasicShader").writes("color", mainTexture).writes("flatNormal", flatNormalTexture).writes("lightmap", lightmapTexture).writes("labPBRNormal", labPBRNormalTexture).writes("labPBRSpecular", labPBRSpecularTexture);
        pipeline.object(ProgramUsage.TRANSLUCENT, "object/basic", "BasicShader").writes("color", mainTexture).writes("flatNormal", flatNormalTexture).writes("lightmap", lightmapTexture).writes("labPBRNormal", labPBRNormalTexture).writes("labPBRSpecular", labPBRSpecularTexture);

        pipeline.stage(ProgramStage.PRE_RENDER).clearTo(new Vector4f(0.0f),mainTexture);

        pipeline.stage(ProgramStage.POST_RENDER).composite("sky", "post/sky", "raymarchSky").writes("scattering", skyScatteringTexture).writes("transmittance", skyTransmittanceTexture);
        pipeline.stage(ProgramStage.POST_RENDER).composite("ssao", "post/ssao", "ambientOcclusion").writes("lightmap", lightmapTexture);
        pipeline.stage(ProgramStage.POST_RENDER).composite("ambient", "post/ambient", "ambientSky").writes("ambientScattering", ambientScatteringTexture);
        pipeline.stage(ProgramStage.POST_RENDER).composite("lighting", "post/lighting", "applyLighting").writes("color", mainTexture);

        pipeline.stage(ProgramStage.POST_RENDER).compute("histogram", "compute/histogram", "applyHistogram").dispatch3D(Math.ceilDiv(screen.renderWidth(), 16), Math.ceilDiv(screen.renderHeight(), 8), 1); //Global histogram
        pipeline.stage(ProgramStage.POST_RENDER).compute("histogramAverage", "compute/histogramAverage", "applyHistogramAverage").dispatch3D(Math.ceilDiv(screen.renderWidth(), 16), Math.ceilDiv(screen.renderHeight(), 8), 1); //Calculate average

        // pipeline.stage(ProgramStage.POST_RENDER).compute("exposure", "compute/exposureBlend", "applyExposure").dispatch3D(Math.ceilDiv(screen.renderWidth(), 16), Math.ceilDiv(screen.renderHeight(), 8), 1);
    }

    @Override
    public void configureRenderer(RendererConfig rendererConfig) {
        rendererConfig.setSunPathRotation(23.47f);
        rendererConfig.setShadowCascades(rendererConfig.getSettings().getIntValue("SHADOW_CASCADE_COUNT"));
        rendererConfig.setShadowDistance(rendererConfig.getSettings().getIntValue("SHADOW_DISTANCE"));
        rendererConfig.setShadowResolution(rendererConfig.getSettings().getIntValue("SHADOW_RESOLUTION"));
    }

}
