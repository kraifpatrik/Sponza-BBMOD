renderer = new BBMOD_DeferredRenderer();
renderer.UseAppSurface = true;
renderer.EnableShadows = true;
renderer.EnableSSAO = true;
renderer.SSAORadius = 64;
renderer.SSAODepthRange = 10;
renderer.SSAOPower = 2;

postProcessor = new BBMOD_PostProcessor();
postProcessor.LensDirtStrength = 0;
renderer.PostProcessor = postProcessor;

dof = new BBMOD_DepthOfFieldEffect();
dof.AutoFocus = true;
//dof.SampleCount = 64;
dof.BlurScaleNear = 0.5;
dof.BokehShape = 0;
postProcessor.add_effect(dof);

sunshafts = new BBMOD_SunShaftsEffect(undefined, 0.3, new BBMOD_Color(20, 20, 20));
postProcessor.add_effect(sunshafts);

directionalBlur = new BBMOD_DirectionalBlurEffect();
postProcessor.add_effect(directionalBlur);

postProcessor.add_effect(new BBMOD_ExposureEffect());
postProcessor.add_effect(new BBMOD_LightBloomEffect(new BBMOD_Vec3(-1), undefined, 0.5));
postProcessor.add_effect(new BBMOD_ReinhardTonemapEffect());
postProcessor.add_effect(new BBMOD_GammaCorrectEffect());
postProcessor.add_effect(new BBMOD_ColorGradingEffect(sprite_get_texture(SprColorGrading, 0)));
postProcessor.add_effect(new BBMOD_LumaSharpenEffect(2));
postProcessor.add_effect(new BBMOD_FilmGrainEffect());
postProcessor.add_effect(new BBMOD_ChromaticAberrationEffect(5));
postProcessor.add_effect(new BBMOD_VignetteEffect(1));
postProcessor.add_effect(new BBMOD_FXAAEffect());

z = 0;
camera = new BBMOD_Camera();
camera.FollowObject = self;
camera.MouseSensitivity = 0.5;

var _freezeOnLoad = function (_err, _res)
{
	if (_res)
	{
		_res.freeze();
	}
};

modSponza = BBMOD_RESOURCE_MANAGER.load("Data/Sponza/Sponza.bbmod", _freezeOnLoad);
modSky = BBMOD_RESOURCE_MANAGER.load("Data/BBMOD/Models/Sphere.bbmod", _freezeOnLoad);

matSky = BBMOD_MATERIAL_SKY.clone();
sprSky = sprite_add("Data/BBMOD/Skies/Sky+60.png", 1, false, true, 0, 0);
matSky.BaseOpacity = sprite_get_texture(sprSky, 0);

bbmod_light_ambient_set(BBMOD_C_BLACK);

sprIBL = sprite_add("Data/BBMOD/Skies/IBL+60.png", 1, false, true, 0, 0);
ibl = new BBMOD_ImageBasedLight(sprite_get_texture(sprIBL, 0));
bbmod_ibl_set(ibl);

sun = new BBMOD_DirectionalLight();
sun.Color.Alpha = 5;
sun.CastShadows = true;
sun.ShadowmapResolution = 4096;
bbmod_light_directional_set(sun);

sunshafts.LightDirection = sun.Direction;

reflectionProbe = new BBMOD_ReflectionProbe(new BBMOD_Vec3(0, 0, 1));
reflectionProbe.Infinite = true;
bbmod_reflection_probe_add(reflectionProbe);
