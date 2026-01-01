# Critical: Open in Godot Editor

## The Problem

The shader errors are back because:
1. Godot cached the compiled shader with instance uniforms
2. Command-line runs use the cached version
3. We need the editor to recompile the shader with our fix

## Solution: Open in Editor

```bash
~/utils/Godot_v4.5.1-stable_linux.x86_64 project.godot
```

Or simply:
```bash
godot project.godot
```

**What will happen:**
1. Editor will detect shader changes
2. Recompile SurfaceVisual.gdshader with our fix
3. Cache the new compiled version
4. Ocean will render properly
5. No more shader errors

## After Opening in Editor

1. **Let it load completely** - Wait for all shaders to compile
2. **Run the scene** - Press F5 or click Play
3. **Check ocean** - Switch to External View (press 3)
4. **Verify no errors** - Check Output panel at bottom

## Then Add Clouds

Once the ocean works, we can add clouds from the example.

The example has:
- Volumetric clouds
- Sky shader
- Atmospheric scattering
- Day/night cycle

## Why This Happens

Godot's shader compilation:
- **Editor**: Compiles shaders and caches them
- **Command-line**: Uses cached compiled shaders
- **Our fix**: Changed shader source code
- **Problem**: Cache still has old version
- **Solution**: Editor recompiles on next load

## Alternative: Force Recompile

If you can't open the editor, try:
```bash
# Delete shader cache
rm -rf .godot/shader_cache/

# Delete all cache
rm -rf .godot/

# Run game (will recompile but might still have issues)
bash run_game.sh
```

But **opening in editor is the proper solution**.

## What You'll See

**Before (command-line with cache):**
- Hundreds of "Too many instances" errors
- Ocean initializes but doesn't render
- Shader using old instance uniforms

**After (editor recompile):**
- Zero shader errors
- Ocean renders with waves
- Shader using our fixed uniforms

---

**Next Step**: Open `godot4 project.godot` and let it compile!
