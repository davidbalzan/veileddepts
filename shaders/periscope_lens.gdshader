shader_type canvas_item;

// Periscope lens effect shader
// Applies distortion, chromatic aberration, and vignette
// Requirement 5.4: Apply lens effects to periscope view

// Distortion parameters
uniform float distortion_strength : hint_range(0.0, 1.0) = 0.15;

// Chromatic aberration parameters
uniform float chromatic_aberration : hint_range(0.0, 0.1) = 0.01;

// Vignette parameters
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.4;
uniform float vignette_radius : hint_range(0.0, 2.0) = 0.8;

// Screen texture
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;


// Barrel distortion function
vec2 apply_distortion(vec2 uv, float strength) {
	// Center UV coordinates
	vec2 centered = uv - 0.5;
	
	// Calculate distance from center
	float dist = length(centered);
	
	// Apply barrel distortion
	float distortion_factor = 1.0 + strength * dist * dist;
	vec2 distorted = centered * distortion_factor;
	
	// Return to UV space
	return distorted + 0.5;
}


// Vignette function
float apply_vignette(vec2 uv, float strength, float radius) {
	// Calculate distance from center
	vec2 centered = uv - 0.5;
	float dist = length(centered);
	
	// Apply smooth vignette falloff
	float vignette = smoothstep(radius, radius - 0.3, dist);
	
	// Mix with strength
	return mix(1.0 - strength, 1.0, vignette);
}


void fragment() {
	// Get UV coordinates
	vec2 uv = SCREEN_UV;
	
	// Apply barrel distortion
	vec2 distorted_uv = apply_distortion(uv, distortion_strength);
	
	// Check if distorted UV is out of bounds
	if (distorted_uv.x < 0.0 || distorted_uv.x > 1.0 || 
	    distorted_uv.y < 0.0 || distorted_uv.y > 1.0) {
		// Black border for out-of-bounds areas
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
		return;
	}
	
	// Apply chromatic aberration
	// Sample red channel with positive offset
	vec2 red_uv = distorted_uv + vec2(chromatic_aberration, 0.0);
	float red = texture(screen_texture, red_uv).r;
	
	// Sample green channel without offset
	float green = texture(screen_texture, distorted_uv).g;
	
	// Sample blue channel with negative offset
	vec2 blue_uv = distorted_uv - vec2(chromatic_aberration, 0.0);
	float blue = texture(screen_texture, blue_uv).b;
	
	// Combine channels
	vec3 color = vec3(red, green, blue);
	
	// Apply vignette
	float vignette = apply_vignette(uv, vignette_strength, vignette_radius);
	color *= vignette;
	
	// Output final color
	COLOR = vec4(color, 1.0);
}
