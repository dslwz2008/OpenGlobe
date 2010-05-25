#version 150

in vec2 position;
                  
out vec3 normalFS;
out vec3 positionToLightFS;
out vec3 positionToEyeFS;
out vec2 textureCoordinate;
out vec2 repeatTextureCoordinate;
out float height;

uniform mat4 mg_modelViewPerspectiveProjectionMatrix;
uniform vec3 mg_cameraEye;
uniform vec3 mg_cameraLightPosition;
uniform sampler2DRect mg_texture0;    // Height map
uniform float u_heightExaggeration;
uniform int u_normalAlgorithm;
uniform vec2 u_positionToTextureCoordinate;
uniform vec2 u_positionToRepeatTextureCoordinate;

vec3 ComputeNormalThreeSamples(
    vec3 displacedPosition, 
    sampler2DRect heightMap, 
    float heightExaggeration)
{
    vec3 right = vec3(displacedPosition.xy + vec2(1.0, 0.0), texture(heightMap, displacedPosition.xy + vec2(1.0, 0.0)).r * heightExaggeration);
    vec3 top = vec3(displacedPosition.xy + vec2(0.0, 1.0), texture(heightMap, displacedPosition.xy + vec2(0.0, 1.0)).r * heightExaggeration);
    return cross(right - displacedPosition, top - displacedPosition);
}

vec3 ComputeNormalFourSamples(
    vec3 displacedPosition, 
    sampler2DRect heightMap, 
    float heightExaggeration)
{
    //
    // Original unoptimized verion
    //
    //vec2 position = displacedPosition.xy;
    //vec3 left = vec3(position - vec2(1.0, 0.0), texture(heightMap, position - vec2(1.0, 0.0)).r * heightExaggeration);
    //vec3 right = vec3(position + vec2(1.0, 0.0), texture(heightMap, position + vec2(1.0, 0.0)).r * heightExaggeration);
    //vec3 bottom = vec3(position - vec2(0.0, 1.0), texture(heightMap, position - vec2(0.0, 1.0)).r * heightExaggeration);
    //vec3 top = vec3(position + vec2(0.0, 1.0), texture(heightMap, position + vec2(0.0, 1.0)).r * heightExaggeration);
    //return cross(right - left, top - bottom);

    vec2 position = displacedPosition.xy;
    float leftHeight = texture(heightMap, position - vec2(1.0, 0.0)).r * heightExaggeration;
    float rightHeight = texture(heightMap, position + vec2(1.0, 0.0)).r * heightExaggeration;
    float bottomHeight = texture(heightMap, position - vec2(0.0, 1.0)).r * heightExaggeration;
    float topHeight = texture(heightMap, position + vec2(0.0, 1.0)).r * heightExaggeration;
    return vec3(leftHeight - rightHeight, bottomHeight - topHeight, 2.0);
}

float SumElements(mat3 m)
{
    return 
        m[0].x + m[0].y + m[0].z +
        m[1].x + m[1].y + m[1].z +
        m[2].x + m[2].y + m[2].z;
}

vec3 ComputeNormalSobelFilter(
    vec3 displacedPosition, 
    sampler2DRect heightMap, 
    float heightExaggeration)
{
	//
	// Original unoptimized verion
	//
	//vec2 position = displacedPosition.xy;
	//float upperLeft = texture(heightMap, position + vec2(-1.0, 1.0)).r * heightExaggeration;
	//float upperCenter = texture(heightMap, position + vec2(0.0, 1.0)).r * heightExaggeration;
	//float upperRight = texture(heightMap, position + vec2(1.0, 1.0)).r * heightExaggeration;
	//float left = texture(heightMap, position + vec2(-1.0, 0.0)).r * heightExaggeration;
	//float right = texture(heightMap, position + vec2(1.0, 0.0)).r * heightExaggeration;
	//float lowerLeft = texture(heightMap, position + vec2(-1.0, -1.0)).r * heightExaggeration;
	//float lowerCenter = texture(heightMap, position + vec2(0.0, -1.0)).r * heightExaggeration;
	//float lowerRight = texture(heightMap, position + vec2(1.0, -1.0)).r * heightExaggeration;
	//
	//mat3 positions = mat3(
	//    upperLeft, left, lowerLeft,
	//    upperCenter, 0.0, lowerCenter,
	//    upperRight, right, lowerRight);
	//mat3 sobelX = mat3(
	//    -1.0, -2.0, -1.0,
	//     0.0,  0.0,  0.0,
	//     1.0,  2.0,  1.0);
	//mat3 sobelY = mat3(
	//    -1.0, 0.0, 1.0,
	//    -2.0, 0.0, 2.0,
	//    -1.0, 0.0, 1.0);
	//
	//float x = SumElements(matrixCompMult(positions, sobelX));
	//float y = SumElements(matrixCompMult(positions, sobelY));
	//
	//return vec3(-x, y, 1.0);

    vec2 position = displacedPosition.xy;
    float upperLeft = texture(heightMap, position + vec2(-1.0, 1.0)).r * heightExaggeration;
    float upperCenter = texture(heightMap, position + vec2(0.0, 1.0)).r * heightExaggeration;
    float upperRight = texture(heightMap, position + vec2(1.0, 1.0)).r * heightExaggeration;
    float left = texture(heightMap, position + vec2(-1.0, 0.0)).r * heightExaggeration;
    float right = texture(heightMap, position + vec2(1.0, 0.0)).r * heightExaggeration;
    float lowerLeft = texture(heightMap, position + vec2(-1.0, -1.0)).r * heightExaggeration;
    float lowerCenter = texture(heightMap, position + vec2(0.0, -1.0)).r * heightExaggeration;
    float lowerRight = texture(heightMap, position + vec2(1.0, -1.0)).r * heightExaggeration;

    float x = upperRight + (2.0 * right) + lowerRight - upperLeft - (2.0 * left) - lowerLeft;
    float y = lowerLeft + (2.0 * lowerCenter) + lowerRight - upperLeft - (2.0 * upperCenter) - upperRight;

    return vec3(-x, y, 1.0);
}

void main()
{
    vec3 displacedPosition = vec3(position.xy, texture(mg_texture0, position.xy).r * u_heightExaggeration);

    gl_Position = mg_modelViewPerspectiveProjectionMatrix * vec4(displacedPosition, 1.0);

    if (u_normalAlgorithm == 1)       // TerrainNormalsAlgorithm.ThreeSamples
    {
        normalFS = ComputeNormalThreeSamples(displacedPosition, mg_texture0, u_heightExaggeration);
    }
    else if (u_normalAlgorithm == 2)  // TerrainNormalsAlgorithm.FourSamples
    {
        normalFS = ComputeNormalFourSamples(displacedPosition, mg_texture0, u_heightExaggeration);
    }
    else if (u_normalAlgorithm == 3)  // TerrainNormalsAlgorithm.SobelFilter
    {
        normalFS = ComputeNormalSobelFilter(displacedPosition, mg_texture0, u_heightExaggeration);
    }
    else
    {
	    //
        // Even if lighting isn't used, shading algorithms based on terrain slope require the normal.
		//
        normalFS = ComputeNormalThreeSamples(displacedPosition, mg_texture0, u_heightExaggeration);
    }

    positionToLightFS = mg_cameraLightPosition - displacedPosition;
    positionToEyeFS = mg_cameraEye - displacedPosition;

    textureCoordinate = position * u_positionToTextureCoordinate;
    repeatTextureCoordinate = position * u_positionToRepeatTextureCoordinate;
    height = displacedPosition.z;
}