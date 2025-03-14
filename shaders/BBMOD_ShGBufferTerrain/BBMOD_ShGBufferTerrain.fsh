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

varying vec2 v_vSplatmapCoord;

varying vec4 v_vEye;

////////////////////////////////////////////////////////////////////////////////
//
// Uniforms
//

////////////////////////////////////////////////////////////////////////////////
// Material

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
// Terrain

// First layer:
// RGB: Base color, A: Opacity
#define bbmod_TerrainBaseOpacity0 gm_BaseTexture
// If 1.0 then the material uses roughness
uniform float bbmod_TerrainIsRoughness0;
// RGB: Tangent-space normal, A: Smoothness or roughness
uniform sampler2D bbmod_TerrainNormalW0;
// Splatmap channel to read. Use -1 for none.
uniform int bbmod_SplatmapIndex0;

// Splatmap texture
uniform sampler2D bbmod_Splatmap;
// Colormap texture
uniform sampler2D bbmod_Colormap;

// Second layer:
// RGB: Base color, A: Opacity
uniform sampler2D bbmod_TerrainBaseOpacity1;
// If 1.0 then the material uses roughness
uniform float bbmod_TerrainIsRoughness1;
// RGB: Tangent-space normal, A: Smoothness or roughness
uniform sampler2D bbmod_TerrainNormalW1;
// Splatmap channel to read. Use -1 for none.
uniform int bbmod_SplatmapIndex1;

// Third layer:
// RGB: Base color, A: Opacity
uniform sampler2D bbmod_TerrainBaseOpacity2;
// If 1.0 then the material uses roughness
uniform float bbmod_TerrainIsRoughness2;
// RGB: Tangent-space normal, A: Smoothness or roughness
uniform sampler2D bbmod_TerrainNormalW2;
// Splatmap channel to read. Use -1 for none.
uniform int bbmod_SplatmapIndex2;

////////////////////////////////////////////////////////////////////////////////
// HDR rendering

// 0.0 = apply exposure, tonemap and gamma correct, 1.0 = output raw values
uniform float bbmod_HDR;

////////////////////////////////////////////////////////////////////////////////
//
// Includes
//
/// @param d Linearized depth to encode.
/// @return Encoded depth.
/// @source http://aras-p.info/blog/2009/07/30/encoding-floats-to-rgba-the-final/
vec3 xEncodeDepth(float d)
{
	const float inv255 = 1.0 / 255.0;
	vec3 enc;
	enc.x = d;
	enc.y = d * 255.0;
	enc.z = enc.y * 255.0;
	enc = fract(enc);
	float temp = enc.z * inv255;
	enc.x -= enc.y * inv255;
	enc.y -= temp;
	enc.z -= temp;
	return enc;
}

/// @param c Encoded depth.
/// @return Docoded linear depth.
/// @source http://aras-p.info/blog/2009/07/30/encoding-floats-to-rgba-the-final/
float xDecodeDepth(vec3 c)
{
	const float inv255 = 1.0 / 255.0;
	return c.x + (c.y * inv255) + (c.z * inv255 * inv255);
}
/// @source http://advances.realtimerendering.com/s2010/Kaplanyan-CryEngine3(SIGGRAPH%202010%20Advanced%20RealTime%20Rendering%20Course).pdf
vec3 xBestFitNormal(vec3 normal, sampler2D tex)
{
	normal = normalize(normal);
	vec3 normalUns = abs(normal);
	float maxNAbs = max(max(normalUns.x, normalUns.y), normalUns.z);
	vec2 texCoord = normalUns.z < maxNAbs ? (normalUns.y < maxNAbs ? normalUns.yz : normalUns.xz) : normalUns.xy;
	texCoord = texCoord.x < texCoord.y ? texCoord.yx : texCoord.xy;
	texCoord.y /= texCoord.x;
	normal /= maxNAbs;
	float fittingScale = texture2D(tex, texCoord).r;
	return normal * fittingScale;
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
	mat3 TBN,
	vec2 uv)
{
	Material m = CreateMaterial();

	// Base color and opacity
	vec4 baseOpacity = texture2D(texBaseOpacity, uv);
	m.Base = xGammaToLinear(baseOpacity.rgb);
	m.Opacity = baseOpacity.a;

	// Normal vector and smoothness/roughness
	vec4 normalW = texture2D(texNormalW,
		uv
		);

	m.Normal = normalize(TBN * (normalW.rgb * 2.0 - 1.0));

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
	m.Metallic = 0.0;
	m.AO = 1.0;
	m.Specular = F0_DEFAULT;

	return m;
}

////////////////////////////////////////////////////////////////////////////////
//
// Main
//
void main()
{
	Material material = UnpackMaterial(
		bbmod_TerrainBaseOpacity0,
		bbmod_TerrainIsRoughness0,
		bbmod_TerrainNormalW0,
		v_mTBN,
		v_vTexCoord);

	Material material1 = UnpackMaterial(
		bbmod_TerrainBaseOpacity1,
		bbmod_TerrainIsRoughness1,
		bbmod_TerrainNormalW1,
		v_mTBN,
		v_vTexCoord);

	Material material2 = UnpackMaterial(
		bbmod_TerrainBaseOpacity2,
		bbmod_TerrainIsRoughness2,
		bbmod_TerrainNormalW2,
		v_mTBN,
		v_vTexCoord);

	// Splatmap
	vec4 splatmap = texture2D(bbmod_Splatmap, v_vSplatmapCoord);

	// Blend layers
	if (bbmod_SplatmapIndex0 >= 0)
	{
		// splatmap[index] does not work in HTML5
		float layerStrength = ((bbmod_SplatmapIndex0 == 0) ? splatmap.r
			: ((bbmod_SplatmapIndex0 == 1) ? splatmap.g
			: ((bbmod_SplatmapIndex0 == 2) ? splatmap.b
			: splatmap.a)));

		material.Opacity *= layerStrength;
	}

	if (bbmod_SplatmapIndex1 >= 0)
	{
		// splatmap[index] does not work in HTML5
		float layerStrength = ((bbmod_SplatmapIndex1 == 0) ? splatmap.r
			: ((bbmod_SplatmapIndex1 == 1) ? splatmap.g
			: ((bbmod_SplatmapIndex1 == 2) ? splatmap.b
			: splatmap.a)));
		float layerStrengthInv = 1.0 - layerStrength;

		material.Base    *= layerStrengthInv;
		material.Opacity *= layerStrengthInv;

		material.Base    += layerStrength * material1.Base;
		material.Opacity += layerStrength * material1.Opacity;

		material.Normal        *= layerStrengthInv;
		material.Metallic      *= layerStrengthInv;
		material.Roughness     *= layerStrengthInv;
		material.Specular      *= layerStrengthInv;
		material.Smoothness    *= layerStrengthInv;
		material.SpecularPower *= layerStrengthInv;
		material.AO            *= layerStrengthInv;
		material.Emissive      *= layerStrengthInv;
		material.Subsurface    *= layerStrengthInv;
		material.Lightmap      *= layerStrengthInv;

		material.Normal        += layerStrength * material1.Normal;
		material.Metallic      += layerStrength * material1.Metallic;
		material.Roughness     += layerStrength * material1.Roughness;
		material.Specular      += layerStrength * material1.Specular;
		material.Smoothness    += layerStrength * material1.Smoothness;
		material.SpecularPower += layerStrength * material1.SpecularPower;
		material.AO            += layerStrength * material1.AO;
		material.Emissive      += layerStrength * material1.Emissive;
		material.Subsurface    += layerStrength * material1.Subsurface;
		material.Lightmap      += layerStrength * material1.Lightmap;
	}

	if (bbmod_SplatmapIndex2 >= 0)
	{
		// splatmap[index] does not work in HTML5
		float layerStrength= ((bbmod_SplatmapIndex2 == 0) ? splatmap.r
			: ((bbmod_SplatmapIndex2 == 1) ? splatmap.g
			: ((bbmod_SplatmapIndex2 == 2) ? splatmap.b
			: splatmap.a)));
		float layerStrengthInv = 1.0 - layerStrength;

		material.Base    *= layerStrengthInv;
		material.Opacity *= layerStrengthInv;

		material.Base    += layerStrength * material2.Base;
		material.Opacity += layerStrength * material2.Opacity;

		material.Normal        *= layerStrengthInv;
		material.Metallic      *= layerStrengthInv;
		material.Roughness     *= layerStrengthInv;
		material.Specular      *= layerStrengthInv;
		material.Smoothness    *= layerStrengthInv;
		material.SpecularPower *= layerStrengthInv;
		material.AO            *= layerStrengthInv;
		material.Emissive      *= layerStrengthInv;
		material.Subsurface    *= layerStrengthInv;
		material.Lightmap      *= layerStrengthInv;

		material.Normal        += layerStrength * material2.Normal;
		material.Metallic      += layerStrength * material2.Metallic;
		material.Roughness     += layerStrength * material2.Roughness;
		material.Specular      += layerStrength * material2.Specular;
		material.Smoothness    += layerStrength * material2.Smoothness;
		material.SpecularPower += layerStrength * material2.SpecularPower;
		material.AO            += layerStrength * material2.AO;
		material.Emissive      += layerStrength * material2.Emissive;
		material.Subsurface    += layerStrength * material2.Subsurface;
		material.Lightmap      += layerStrength * material2.Lightmap;
	}

	// Colormap
	material.Base *= xGammaToLinear(texture2D(bbmod_Colormap, v_vSplatmapCoord).xyz);

	if (material.Opacity < bbmod_AlphaTest)
	{
		discard;
	}

	gl_FragData[0] = vec4(xLinearToGamma(mix(material.Base, material.Specular, material.Metallic)), material.AO);
	gl_FragData[1] = vec4(material.Normal * 0.5 + 0.5, material.Roughness);
	gl_FragData[2] = vec4(xEncodeDepth(v_vPosition.z / bbmod_ZFar), material.Metallic);
	gl_FragData[3] = vec4(material.Emissive, 1.0);
	if (bbmod_HDR == 0.0)
	{
		gl_FragData[3].rgb = xLinearToGamma(gl_FragData[3].rgb);
	}
}
