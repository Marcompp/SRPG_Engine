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
   screen's help box used it until they moved (removed in step 7). `GildedStyleBox` (a script
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
5. **Status screen** (done, 2026-10-16). Laid out in HD units and hosted on its
   own `UiLayer`: layer 3 in battle (it opens from the unit list, which is still
   on the old-look layer 2) and layer 1 in the prep screen. Left column: a gilded
   frame around the portrait placeholder (team color, class icon or initial,
   movement badge), the name, class, race, level and EXP, HP and MP meters
   ("18 / 18"). Right: a gilded panel with Cinzel tabs (the current one gold and
   underlined) and the pages: one stat per row with a gold bar (capped stats
   green and pulsing, skill-boosted values gold), items with uses, combat
   numbers and spells between faint gold rules, skills with their source, the
   biography in italics. Detail mode frames the entry in gold and explains it in
   an opaque gilded box. The veil behind is see-through over the battle map and
   opaque in the prep screen (`veil_alpha`). Entry order and texts are kept, so
   the tests only changed for the HP/MP numbers and the bio's dash.
6. **Other battle screens** (done, 2026-10-16). The unit list is a table in a
   gilded panel: small-capital headers (the sort column gold and underlined),
   names in their side's color, units that acted dimmed, the gold band and
   diamond on the selected row. Options is a centered gilded panel: the title in
   engraved capitals, one row per setting with its value at the right, the
   selected row gold with `‹ value ›`. Options has the same `veil_alpha` as the
   status screen (opaque on the level select, which hosts it on its own
   `UiLayer`). With these moved, everything in battle shares BattleUI's one HD
   layer, stacked in the order it's added (HUD windows, dialogue, unit list,
   status, options, fast-forward tag, banner), and BattleUI no longer uses the
   old look. The glossary popups are the status screen's help box (step 5).
7. **Out of battle** (done, 2026-10-16). The level select and the prep screen
   draw on a `UiLayer` of their own (their scene roots only take input). Level
   select: the title in large engraved capitals, a gilded list of 7 rows with the
   band and diamond, the description and hint under it. Prep screen: the
   chapter's name and objective at the top, each list column a gilded panel (one
   panel across when the right column is empty), the gold band on the
   highlighted row of the active column instead of a "> " marker
   (`_selected_rows` records which shown row it is; "..." still marks hidden
   rows), item help in an opaque gilded box, the mount name field gold-edged.
   With these moved, `UiTheme.legacy()` is gone: every screen uses the theme.
8. **World atmosphere** (done, 2026-10-16). `Atmosphere`, a `CanvasLayer` at
   layer 1 (BattleUI moved to 2), added by the battle: one full-screen shader
   reading the screen texture (warm-to-cool grading, a touch more contrast and
   saturation, two slow diagonal light shafts, a vignette, and tilt-shift: a
   two-ring, 17-tap blur that grows toward the top and bottom, since the
   Compatibility renderer can't be relied on for screen mipmaps; kept very
   subtle, at most 0.6 screen pixels in the outer fifth of the screen, since the
   view is top-down), a soft additive
   glow on the cursor's cell, and 22 drifting light motes (`CPUParticles2D`). The
   "Atmosphere" option (On by default) turns all of it off.
9. **Motion:** windows fade and slide 6 px as they open, the cursor pulses;
   timings follow the game speed, and turning atmosphere off skips them.
10. **Wrap-up:** remove the old `StyleBoxFlat` styling, screenshot every screen at
    both scales, run the suite, add a UI section to the README.
