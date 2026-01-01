## BiomeTextureParams resource for biome rendering properties
##
## Stores the visual parameters for rendering a specific biome type.
## Used by the terrain shader to apply appropriate materials.

class_name BiomeTextureParams extends Resource

## Base color for the biome
@export var albedo_color: Color = Color.WHITE

## Surface roughness (0.0 = smooth, 1.0 = rough)
@export var roughness: float = 0.5

## Metallic property (0.0 = non-metallic, 1.0 = metallic)
@export var metallic: float = 0.0

## Normal map strength for bump mapping
@export var normal_strength: float = 1.0
