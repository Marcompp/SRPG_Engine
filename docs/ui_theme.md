# UI theme: Gilded Night (design notes)

Plan for the game's UI identity. Nothing is built yet. The look was picked from
mockups comparing six directions (three on the 240x160 pixel grid, three HD-2D):
an **HD-2D presentation**, where the world stays pixel art and the interface,
text and lighting run at screen resolution, in the **Gilded Night** style:
midnight-blue panels edged with fine double gold lines and small filigree
corners, names in engraved capitals (Cinzel), body text in a book serif
(EB Garamond), a glowing gold diamond for the cursor.

## Look

- **Panels:** vertical gradient from navy (18, 20, 50, 95%) to near-black
  (8, 9, 28, 92%); an outer 1 px gold line (214, 178, 94), an inner line 6 px in
  at 30% gold; a filigree corner (curl plus a small diamond) on each corner,
  overhanging the panel by about 9 px; soft drop shadow.
- **Type:** names, labels and tabs in Cinzel (letter-spaced capitals, gold
  243, 220, 154); everything else in EB Garamond (warm white 239, 230, 207;
  secondary text lavender 169, 160, 196). Sizes in 960x640 units: names 30,
  titles 24, body 25, secondary 21, dialogue 28, small capitals 16. The HD layer
  filters textures smoothly (with mipmaps) so text stays clean when the window
  isn't exactly 4x; the world keeps the project's nearest filtering.
- **Selection:** a gold gradient band behind the row, fading at both ends, and a
  rotated gold square with a glow at its left.
- **Bars:** dark track with a thin gold outline; HP fill green to pale gold with
  a glow; stat bars gold.
- **Dialogue:** full-width box, the speaker's name on a separate gold-edged
  plate over its top-left corner, the portrait at 3x behind the box with its
  bottom faded out, a gold arrow when the line is done.
- **World:** warm-to-cool grading, light shafts, vignette, tilt-shift blur at the
  top and bottom of the screen, a glow on the cursor cell, drifting light motes.
  No 3D: the tilted "diorama" camera from the mockups would need the map in 3D
  (tiles as meshes, units as billboards) and is out of scope.

## Technical approach

Today every screen is laid out in 240x160 units (`_place()` in `ui.gd` keeps
windows 3 units from the edge; `status_screen.gd` hardcodes positions such as
`Vector2(86, 17)`), so the thinnest possible line is a whole game pixel.

- **The world doesn't change:** 240x160, integer scaling, `canvas_items` stretch.
- **The UI gets its own layer:** a `CanvasLayer` scaled by 0.25 holding a
  960x640 root `Control` (its size set explicitly, not by a full-rect preset,
  which would size it to the 240x160 viewport). `canvas_items` stretch renders 2D
  at window resolution, so at the 4x window one UI unit is one screen pixel:
  hairlines and text are drawn at full resolution.
- **Fonts are ordinary dynamic fonts.** Godot rasterizes them at the final scale,
  so they come out sharp at 4x and 6x. MSDF was tried and is worse: softer small
  text, a broken tilde on Cinzel's Ñ, stray dots beside some glyphs.
- **Fallback** (not needed, see step 1): draw the world into a 240x160
  `SubViewport` scaled up by 4, and lay the UI out natively at 960x640.

Assumed, to revisit if needed:

- **Letterboxing stays.** Integer scaling keeps map pixels even; filling a 1080p
  screen would mean uneven pixels or a different world renderer.
- **Portraits** aren't in the game yet (see [portraits.md](portraits.md)); until
  they are, the unit card and status screen show a placeholder in the gold frame
  (the class initial, as the status screen does today).
- **Spanish:** check that both fonts cover the locale's accented letters.

## Steps

Each step leaves the game working with the tests passing. Steps 3 to 7 can go in
any order once step 2 exists.

1. **Spike** (done, 2026-10-16). A throwaway script drew the map at 240x160 and a
   0.25-scaled layer on top with two test panels (gradient fill, both gold lines,
   corners, Cinzel and EB Garamond, MSDF and dynamic side by side), screenshotted
   at 960x640 and 1440x960. Results: 1-unit rules are exactly one screen pixel at
   4x; text renders at window resolution at both scales; dynamic fonts beat MSDF;
   both fonts cover Spanish (á ó ú ñ ¡ ¿) and ç. To fix in step 2: setting the
   weight axis through `name_to_tag("weight")` had no visible effect (Cinzel 700
   looked like 500), so the axis tag or the font setup needs checking.
2. **Theme foundation** (done, 2026-10-16). `fonts/` holds Cinzel and EB
   Garamond (variable fonts) with their OFL licences. `scripts/ui_theme.gd`
   (`UiTheme`): palette and font-size constants, `font()` (weight and letter
   spacing in one `FontVariation`: nesting two lost the weight, which was the
   spike's bold bug), `hd()` (the theme for HD screens: body font, gilded panels,
   Label variations NameLabel, TitleLabel, SubLabel, CaptionLabel, the PlatePanel
   and SelectedRow variations) and `legacy()` / `legacy_box()`, the old flat look
   in one place: `ui.gd`, `prep_screen.gd`, `level_select.gd` and the status
   screen's help box use it until they move. `GildedStyleBox` (a script
   `StyleBox`) draws the fill, both lines, a soft shadow and the corner
   flourishes in code, so no corner texture. `GildedBar`, `DiamondCursor`, and
   `UiLayer` (the 0.25-scaled layer, root sized 960x640). Test: `test_ui_theme`.
3. **Battle HUD** (done, 2026-10-16). `BattleUI` holds a `UiLayer` (layer 1)
   for the HUD windows and moved itself to layer 2, so the old-look full-screen
   views (status, unit list, options, dialogue) still cover the HUD until they
   move. The unit window is a card: a face placeholder (team color with the class
   icon or initial, until portraits), side caption, name, class · level · EXP, HP
   and MP bars, then weapon, items, spells, notes and stats in smaller text. The
   terrain window is separate (name, then `DEF +1 · AVO +20`, `No bonus (Flying)`
   or a breakable tile's `HP 5/20`) and sits at the other end of the card's side,
   or alone at the bottom (top when the cursor is near the bottom). The action
   menu is nine row labels with the gold band and `DiamondCursor` on the selected
   one (`menu_text()` returns what's shown). Forecast, spell forecast, trade,
   level-up and objective use the theme; `GildedBanner` is the phase banner and
   end screen (a band fading at both ends between gold rules; a banner's second
   line, e.g. the turn, goes under the title). Tests now read `_terrain_name`,
   `_terrain_bonus`, `_menu_prompt` and `menu_text()`.
4. **Dialogue** (done, 2026-10-16). `DialogueBox` is on BattleUI's HD layer: a
   full-width gilded box, the name on a PlatePanel over its top edge, a gold
   arrow that bobs once the line is done, narration in italics. Portrait slots
   are 192x160 placeholders (side color, gold edge, the speaker's initial),
   tucked behind the box, the listener dimmed; real portraits (96x80, shown at
   2x or 3x) can replace them once units have them. Typing, sounds and
   translation unchanged.
5. **Status screen** (`status_screen.gd`): framed portrait, name block with HP
   and MP bars, Cinzel tabs, two-column stats with gold bars, equipment row, bio;
   glossary help popups in the theme. `_entries` stays (tests read it).
6. **Other battle screens:** unit list, options, glossary popups.
7. **Out of battle:** level select and prep screen, on the same HD layer.
8. **World atmosphere:** one canvas shader on a layer between the world and the
   UI (grading, vignette, tilt-shift, reading the screen texture so the blur is
   smooth), the cursor glow and `CPUParticles2D` motes. An Options toggle turns
   it off.
9. **Motion:** windows fade and slide 6 px as they open, the cursor pulses;
   timings follow the game speed, and turning atmosphere off skips them.
10. **Wrap-up:** remove the old `StyleBoxFlat` styling, screenshot every screen at
    both scales, run the suite, add a UI section to the README.
