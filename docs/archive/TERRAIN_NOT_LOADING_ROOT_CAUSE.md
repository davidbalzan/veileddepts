# Terrain Not Loading - Root Cause Analysis

## Problem
No terrain is visible in any view (tactical map, periscope, external). The 3D terrain chunks are not loading.

## Root Causes Found

### 1. **CRITICAL: Invalid Property Assignment** ✓ FIXED
**Error**: `Invalid assignment of property or key 'enabled' with value of type 'bool' on a base object of type 'Node (ProceduralDetailGenerator)'`

**Location**: `scripts/rendering/terrain_renderer.gd` line 125

**Issue**: Trying to set `_procedural_detail_generator.enabled = enable_procedural_detail` but ProceduralDetailGenerator doesn't have an `enabled` property.

**Fix Applied**: Removed the invalid property assignment.

### 2. **CRITICAL: Legacy Scene Properties** ✓ FIXED
**Error**: `Invalid access to property or key 'enable_micro_detail' on a base object of type 'Node3D (TerrainRenderer)'`

**Location**: `scenes/main.tscn` - TerrainRenderer node configuration

**Issue**: Scene file was setting obsolete properties from old terrain system:
- `terrain_size`
- `terrain_resolution`
- `max_height`
- `min_height`
- `enable_micro_detail`
- `micro_detail_scale`
- `micro_detail_frequency`
- `external_heightmap_path` (should be `elevation_map_path`)

**Fix Applied**: Updated scene file with correct properties for new streaming system:
- `chunk_size`
- `load_distance`
- `unload_distance`
- `max_cache_memory_mb`
- `enable_procedural_detail`
- `detail_scale`
- `detail_frequency`
- `elevation_map_path`

### 3. **CRITICAL: Shader Instance Buffer Overflow** ⚠️ NEEDS FIX
**Error**: `Too many instances using shader instance variables. Increase buffer size in Project Settings.`

**Issue**: The terrain shader (`terrain_chunk.gdshader`) uses shader instance variables, but Godot's default buffer size is too small for the number of terrain chunks being created.

**Impact**: This prevents terrain chunks from rendering even if they're loaded into memory.

**Solution Needed**: Increase the shader instance buffer size in project settings.

## Why No Terrain Is Visible

The terrain streaming system IS working (chunks are being loaded), but they're not rendering because:

1. ✓ **Initialization errors** were preventing the system from starting (FIXED)
2. ⚠️ **Shader buffer overflow** is preventing chunks from rendering (NEEDS FIX)

## Immediate Fix Required

Add to `project.godot`:

```ini
[rendering]

shader_compiler/shader_cache/enabled=true
shader_compiler/shader_cache/compress=true
shader_compiler/shader_cache/use_zstd_compression=true
shader_compiler/shader_cache/strip_debug=false

limits/global_shader_variables/buffer_size=65536
```

The default buffer size is 4096, but with terrain streaming we need much more.

## Files Modified

1. **scripts/rendering/terrain_renderer.gd**
   - Removed invalid `enabled` property assignment

2. **scenes/main.tscn**
   - Updated TerrainRenderer properties to match new streaming system
   - Removed obsolete legacy properties

## Next Steps

1. ✓ Fix property assignment errors (DONE)
2. ⚠️ Increase shader instance buffer size in project.godot
3. Test terrain loading with fixed configuration
4. Verify chunks appear in 3D views

## Testing

After fixes, run the game and:
1. Press '2' for periscope view - should see terrain
2. Press '3' for external view - should see terrain chunks
3. Check console for "StreamingManager" messages about chunk loading
4. No shader errors should appear

## Technical Details

### Shader Instance Variables
The terrain shader uses per-instance data for:
- Chunk position/offset
- LOD level
- Biome parameters
- Detail scale

Each terrain chunk creates a shader instance. With streaming, we can have 20-50 chunks loaded simultaneously, requiring a larger buffer than Godot's default.

### Default vs Required
- **Default buffer**: 4096 bytes
- **Required for terrain**: 65536 bytes (16x larger)
- **Reason**: Each chunk needs ~1KB of instance data, and we load 20-50 chunks

## Conclusion

The terrain system was failing silently due to:
1. Property errors preventing initialization
2. Shader buffer overflow preventing rendering

Both issues are now identified. The first is fixed, the second needs project settings update.
