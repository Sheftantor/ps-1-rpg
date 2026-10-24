# Enemy portraits

Shown in gun mode's target queue slots (top center, under "TIME STOP"), one per queued shot. The slots draw the 64x64 icon at its native size (no rescaling).

## Portrait standard

- Square 1:1, 1024x1024 source.
- Tight close-up of the head only, turned about 35 degrees so the face points toward the RIGHT edge of the image, camera slightly above eye level, looking slightly down. The head fills about 80% of the frame with a small margin all around.
- No shoulders in view, or only a sliver at the bottom corners.
- Headless enemies: the camera is focused on an "invisible head". Empty background fills the middle of the frame, the collar sits low (its top edge about 60% down), and the tie knot sits just below.
- Background: flat warm gray-beige, solid color about #A9A397, no gradient or vignette.
- Style: ps1 low-poly look, low-resolution textures, flat even lighting, slightly muted colors, no text, no border.
- Process: downscale with high-quality resampling to my icon size, keep the original in the source folder, and set the `portrait` field on the enemy data.

## Adding a portrait in this project

1. Save the 1024x1024 original as `Import/art/portrait/source/<enemy>_portrait.png` (or `.jpg`). That folder has a `.gdignore`, so originals are kept but never imported or shipped.
2. Downscale it to the item icon size (64x64, Lanczos) and import it:

   ```
   godot --headless --path . -s res://scripts/tools/build_portrait_icons.gd
   godot --headless --path . --import
   ```

   This writes `textures/ui/icons/<enemy>_portrait.png` with the same import settings as the item icons (lossless, no mipmaps). It redoes every source, which is harmless.
3. In the enemy's `EnemyStats` resource (`resources/enemies/*.tres`), set `portrait` to that icon and `display_name` to the enemy's name. Nothing else is needed: the HUD reads both from the stats.

An enemy with no portrait shows the gray "?" placeholder.
