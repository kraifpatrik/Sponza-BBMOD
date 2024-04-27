// FIXME: Temporary fix!
precision highp float;

////////////////////////////////////////////////////////////////////////////////
//
// Defines
//

// Maximum number of punctual lights
#define BBMOD_MAX_PUNCTUAL_LIGHTS 8
// Number of samples used when computing shadows
#define SHADOWMAP_SAMPLE_COUNT 12

////////////////////////////////////////////////////////////////////////////////
//
// Varyings
//

varying vec3 v_vVertex;

varying vec2 v_vTexCoord;
varying mat3 v_mTBN;
varying vec4 v_vPosition;

varying vec4 v_vPosShadowmap;

////////////////////////////////////////////////////////////////////////////////
//
// Uniforms
//

////////////////////////////////////////////////////////////////////////////////
// Material

// Material index
// uniform float bbmod_MaterialIndex;

// RGB: Base color, A: Opacity
#define bbmod_BaseOpacity gm_BaseTexture

// RGBA
uniform vec4 bbmod_BaseOpacityMultiplier;

// If 1.0 then the material uses roughness
uniform float bbmod_IsRoughness;
// RGB: Tangent-space normal, A: Smoothness or roughness
uniform sampler2D bbmod_NormalW;
// If 1.0 then the material uses metallic workflow
uniform float bbmod_IsMetallic;
// RGB: specular color / R: Metallic, G: ambient occlusion
uniform sampler2D bbmod_Material;

// RGB: Subsurface color, A: Intensity
uniform sampler2D bbmod_Subsurface;
// RGBA: RGBM encoded emissive color
uniform sampler2D bbmod_Emissive;

// Pixels with alpha less than this value will be discarded
uniform float bbmod_AlphaTest;

////////////////////////////////////////////////////////////////////////////////
// Camera

// Camera's position in world space
uniform vec3 bbmod_CamPos;
// Distance to the far clipping plane
uniform float bbmod_ZFar;
// Camera's exposure value
uniform float bbmod_Exposure;

////////////////////////////////////////////////////////////////////////////////
// Fog

// The color of the fog
uniform vec4 bbmod_FogColor;
// Maximum fog intensity
uniform float bbmod_FogIntensity;
// Distance at which the fog starts
uniform float bbmod_FogStart;
// 1.0 / (fogEnd - fogStart)
uniform float bbmod_FogRcpRange;

////////////////////////////////////////////////////////////////////////////////
// Ambient light

// Ambient light's up vector.
uniform vec3 bbmod_LightAmbientDirUp;
// Ambient light color on the upper hemisphere.
uniform vec4 bbmod_LightAmbientUp;
// Ambient light color on the lower hemisphere.
uniform vec4 bbmod_LightAmbientDown;

////////////////////////////////////////////////////////////////////////////////
// Directional light

// Direction of the directional light
uniform vec3 bbmod_LightDirectionalDir;
// Color of the directional light
uniform vec4 bbmod_LightDirectionalColor;

////////////////////////////////////////////////////////////////////////////////
// HDR rendering

// 0.0 = apply exposure, tonemap and gamma correct, 1.0 = output raw values
uniform float bbmod_HDR;

////////////////////////////////////////////////////////////////////////////////
//
// Includes
//
#define X_GAMMA 2.2

/// @desc Converts gamma space color to linear space.
vec3 xGammaToLinear(vec3 rgb)
{
	return pow(rgb, vec3(X_GAMMA));
}

/// @desc Converts linear space color to gamma space.
vec3 xLinearToGamma(vec3 rgb)
{
	return pow(rgb, vec3(1.0 / X_GAMMA));
}

/// @desc Gets color's luminance.
float xLuminance(vec3 rgb)
{
	return (0.2126 * rgb.r + 0.7152 * rgb.g + 0.0722 * rgb.b);
}

void Fog(float depth)
{
	vec3 ambientUp = xGammaToLinear(bbmod_LightAmbientUp.rgb) * bbmod_LightAmbientUp.a;
	vec3 ambientDown = xGammaToLinear(bbmod_LightAmbientDown.rgb) * bbmod_LightAmbientDown.a;
	vec3 directionalLightColor = xGammaToLinear(bbmod_LightDirectionalColor.rgb) * bbmod_LightDirectionalColor.a;
	vec3 fogColor = xGammaToLinear(bbmod_FogColor.rgb) * (ambientUp + ambientDown + directionalLightColor);
	float fogStrength = clamp((depth - bbmod_FogStart) * bbmod_FogRcpRange, 0.0, 1.0) * bbmod_FogColor.a;
	gl_FragColor.rgb = mix(gl_FragColor.rgb, fogColor, fogStrength * bbmod_FogIntensity);
}
void Exposure()
{
	gl_FragColor.rgb *= bbmod_Exposure * bbmod_Exposure;
}
void TonemapReinhard()
{
	gl_FragColor.rgb = gl_FragColor.rgb / (vec3(1.0) + gl_FragColor.rgb);
}

void GammaCorrect()
{
	gl_FragColor.rgb = xLinearToGamma(gl_FragColor.rgb);
}
struct Material
{
	vec3 Base;
	float Opacity;
	vec3 Normal;
	float Metallic;
	float Roughness;
	vec3 Specular;
	float Smoothness;
	float SpecularPower;
	float AO;
	vec3 Emissive;
	vec4 Subsurface;
	vec3 Lightmap;
};

Material CreateMaterial()
{
	Material m;
	m.Base = vec3(1.0);
	m.Opacity = 1.0;
	m.Normal = vec3(0.0, 0.0, 1.0);
	m.Metallic = 0.0;
	m.Roughness = 1.0;
	m.Specular = vec3(0.0);
	m.Smoothness = 0.0;
	m.SpecularPower = 1.0;
	m.AO = 1.0;
	m.Emissive = vec3(0.0);
	m.Subsurface = vec4(0.0);
	m.Lightmap = vec3(0.0);
	return m;
}
#define F0_DEFAULT vec3(0.04)
/// @note Input color should be in gamma space.
/// @source https://graphicrants.blogspot.cz/2009/04/rgbm-color-encoding.html
vec4 xEncodeRGBM(vec3 color)
{
	vec4 rgbm;
	color *= 1.0 / 6.0;
	rgbm.a = clamp(max(max(color.r, color.g), max(color.b, 0.000001)), 0.0, 1.0);
	rgbm.a = ceil(rgbm.a * 255.0) / 255.0;
	rgbm.rgb = color / rgbm.a;
	return rgbm;
}

/// @source https://graphicrants.blogspot.cz/2009/04/rgbm-color-encoding.html
vec3 xDecodeRGBM(vec4 rgbm)
{
	return 6.0 * rgbm.rgb * rgbm.a;
}

/// @desc Unpacks material from textures.
/// @param texBaseOpacity RGB: base color, A: opacity
/// @param isRoughness
/// @param texNormalW
/// @param isMetallic
/// @param texMaterial
/// @param texSubsurface  RGB: subsurface color, A: intensity
/// @param texEmissive    RGBA: RGBM encoded emissive color
/// @param texLightmap    RGBA: RGBM encoded lightmap
/// @param uvLightmap     Lightmap texture coordinates
/// @param TBN            Tangent-bitangent-normal matrix
/// @param uv             Texture coordinates
Material UnpackMaterial(
	sampler2D texBaseOpacity,
	float isRoughness,
	sampler2D texNormalW,
	float isMetallic,
	sampler2D texMaterial,
	sampler2D texSubsurface,
	sampler2D texEmissive,
	mat3 TBN,
	vec2 uv)
{
	Material m = CreateMaterial();

	// Base color and opacity
	vec4 baseOpacity = texture2D(texBaseOpacity,
		uv
		);
	m.Base = xGammaToLinear(baseOpacity.rgb);
	m.Opacity = baseOpacity.a;

	// Normal vector and smoothness/roughness
	vec4 normalW = texture2D(texNormalW,
		uv
		);
	m.Normal = normalize(TBN * (normalW.rgb * 2.0 - 1.0));

	if (!gl_FrontFacing)
	{
		m.Normal *= -1.0;
	}

	if (isRoughness == 1.0)
	{
		m.Roughness = mix(0.1, 0.9, normalW.a);
		m.Smoothness = 1.0 - m.Roughness;
	}
	else
	{
		m.Smoothness = mix(0.1, 0.9, normalW.a);
		m.Roughness = 1.0 - m.Smoothness;
	}

	// Material properties
	vec4 materialProps = texture2D(texMaterial,
		uv
		);

	if (isMetallic == 1.0)
	{
		m.Metallic = materialProps.r;
		m.AO = materialProps.g;
		m.Specular = mix(F0_DEFAULT, m.Base, m.Metallic);
		m.Base *= (1.0 - m.Metallic);
	}
	else
	{
		m.Specular = materialProps.rgb;
		m.SpecularPower = exp2(1.0 + (m.Smoothness * 10.0));
	}

	// Subsurface (color and intensity)
	vec4 subsurface = texture2D(texSubsurface, uv);
	m.Subsurface = vec4(xGammaToLinear(subsurface.rgb).rgb, subsurface.a);

	// Emissive color
	m.Emissive = xGammaToLinear(xDecodeRGBM(texture2D(texEmissive, uv)));

	return m;
}

void UnlitShader(Material material, float depth)
{
	gl_FragColor.rgb = material.Base;
	gl_FragColor.rgb += material.Emissive;
	gl_FragColor.a = material.Opacity;
	// Soft particles
	Fog(depth);

	if (bbmod_HDR == 0.0)
	{
		Exposure();
		TonemapReinhard();
		GammaCorrect();
	}
}

////////////////////////////////////////////////////////////////////////////////
//
// Main
//
void main()
{
	Material material = UnpackMaterial(
		bbmod_BaseOpacity,
		bbmod_IsRoughness,
		bbmod_NormalW,
		bbmod_IsMetallic,
		bbmod_Material,
		bbmod_Subsurface,
		bbmod_Emissive,
		v_mTBN,
		v_vTexCoord);

	material.Base *= xGammaToLinear(bbmod_BaseOpacityMultiplier.rgb);
	material.Opacity *= bbmod_BaseOpacityMultiplier.a;

	if (material.Opacity < bbmod_AlphaTest)
	{
		discard;
	}

	UnlitShader(material, v_vPosition.z);
}
