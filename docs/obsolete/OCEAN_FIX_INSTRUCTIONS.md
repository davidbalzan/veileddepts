# Ocean Shader Fix - Final Instructions

## Current Status

✅ **Shader fix applied** - The `instance uniform` declarations have been changed to regular `uniform` in `addons/tessarakkt.oceanfft/shaders/SurfaceVisual.gdshader`

✅ **Latest Ocean FFT installed** - Using the latest version from the official repo

✅ **Test scene created** - `scenes/ocean_test.tscn` is ready for testing

❌ **Not rendering yet** - Because Godot needs to compile the shaders in the editor

## Why the Ocean Isn't Showing

The shader source code has been fixed, but:

1. **Custom shaders are compiled by the Godot Editor**, not by command-line runs
2. **Addon classes need to be registered** when the project is first opened in the editor
3. **The `.godot/` cache was cleared**, so everything needs to be rebuilt

## What You Need to Do

### Step 1: Open the Project in Godot Editor

```bash
~/utils/Godot_v4.5.1-stable_linux.x86_64 project.godot
```

Or if you have the alias set up:
```bash
godot project.godot
```

### Step 2: Wait for Initialization

When the editor opens:
- Let it scan and import all assets (progress bar at bottom)
- Let it register addon classes (`Ocean3D`, `QuadTree3D`, etc.)
- Let it compile all shaders (including `SurfaceVisual.gdshader`)
- This may take 30-60 seconds on first open

### Step 3: Test the Ocean Scene

Once the editor is fully loaded:

**Option A: Test in Editor**
1. Open `scenes/ocean_test.tscn` from the FileSystem panel
2. Click the "Play Scene" button (F6) or the play icon at top right
3. You should see:
   - A reference box floating in the air
   - Ocean water below with animated waves
   - No shader errors in the Output panel

**Option B: Test from Command Line**
1. Close the editor
2. Run: `bash test_ocean_scene.sh`
3. The ocean should now render properly

### Step 4: Test in Main Game

If the ocean test scene works:

```bash
bash run_game.sh
```

Then press `3` to switch to External View and see the ocean.

## What You Should See

### ✅ Success Indicators

- **Zero shader errors** in console/output
- **Animated ocean waves** with realistic FFT-based motion
- **Foam on wave crests** (whitecaps)
- **Proper lighting** and reflections
- **Submarine floating** on the water surface

### ❌ If It Still Doesn't Work

If you still don't see the ocean after opening in the editor:

1. **Check the Output panel** (bottom of editor) for errors
2. **Verify the addon is enabled**:
   - Go to Project → Project Settings → Plugins
   - Make sure "Ocean FFT" is checked/enabled
3. **Check ocean_test.tscn**:
   - Make sure OceanRenderer node exists
   - Check that it has the ocean_renderer.gd script attached
4. **Try the main scene**:
   - Open `scenes/main.tscn`
   - Look for the OceanRenderer node
   - Press F5 to run and switch to view 3

## Technical Explanation

### Why Editor is Required

Godot's shader compilation process:

```
Source Code (.gdshader)
    ↓
Editor Detects Changes
    ↓
Compiles to GPU Bytecode
    ↓
Caches Compiled Version (.godot/)
    ↓
Runtime Uses Cached Version
```

**Command-line runs skip the compilation step** and go straight to using cached versions.

### The Fix We Applied

Changed in `addons/tessarakkt.oceanfft/shaders/SurfaceVisual.gdshader` (lines 112-114):

```gdshader
// BEFORE (causing errors):
instance uniform float patch_size = 512.0;
instance uniform float min_lod_morph_distance;
instance uniform float max_lod_morph_distance;

// AFTER (fixed):
uniform float patch_size = 512.0;
uniform float min_lod_morph_distance;
uniform float max_lod_morph_distance;
```

This eliminates the "Too many instances" errors that were flooding the console.

## Next Steps After Ocean Works

Once the ocean is rendering properly:

1. **Merge the branch**:
   ```bash
   git checkout main
   git merge feature/oceanfft-latest
   ```

2. **Add volumetric clouds** (see `ADD_CLOUDS_GUIDE.md`)

3. **Tune ocean parameters** in the editor:
   - Wind speed and direction
   - Wave choppiness
   - Foam coverage
   - Specular highlights

## Files Reference

- **Shader fix**: `addons/tessarakkt.oceanfft/shaders/SurfaceVisual.gdshader`
- **Ocean renderer**: `scripts/rendering/ocean_renderer.gd`
- **Test scene**: `scenes/ocean_test.tscn`
- **Test script**: `test_ocean_scene.sh`
- **Main scene**: `scenes/main.tscn`

---

**TL;DR**: Open `godot project.godot` in the editor, wait for it to load completely, then test the ocean scene. The shader fix is already applied - it just needs to be compiled by the editor.
