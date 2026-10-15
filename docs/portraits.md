# Portraits (design notes)

Design notes, with a working prototype of the pipeline and the dev tool (see
"What exists"). The game doesn't show portraits yet: dialogue and the status
screen still draw placeholders (`scripts/dialogue_box.gd`,
`scripts/status_screen.gd`). The goal: GBA Fire Emblem–style mugshots
**assembled from layered parts and painted from color ramps**, so generic units
get a unique face at runtime and named characters are presets made with the same
parts.

## What exists

- **Art:** `art/portraits/test.ase`, 96x80 (FE's GBA size), converted from the
  first test mugshot (`gitignore/Mugshot Attempt2.ase`): layers renamed to the
  convention below, each outfit in two pieces (`clothes/tunic:back` under the jaw,
  `clothes/tunic` over it), the eyes and brows split into left and right pieces without
  their skin patches, stray colors snapped to keys. Two outfits, two jaws and two ears.
  It's in **indexed mode with the key colors as its palette**, so only key
  colors can be painted. Hidden `_ref` layers hold the unused originals (both
  ears, the second jaw) to trace from. Every export also writes
  `art/portraits/keys.gpl`, the same palette with names ("skin 2"), to load
  into new files (Palette > Load). Its first slot is the transparent one.
- **Exporter** (`tools/portrait_exporter.gd`, run by `tools/export_portraits.gd`
  or the editor): reads `.ase` itself (`tools/ase_file.gd`), checks names and
  colors, writes `portraits/parts/` and its `index.cfg`. Frame 0 only so far.
- **Composer** (`scripts/portraits.gd`): recipes, (role, shade) composition,
  sided roles, offsets with `follows` and spacing, cast shadows and
  shadow/light/mask pieces, random recipes with pools, presets and baked PNGs.
  About 3 ms per portrait once its parts are loaded.
- **Editor** (`tools/portrait_editor.tscn`): run it with
  `godot --path . res://tools/portrait_editor.tscn`. Pick parts, ramps (each eye
  separately too) and offsets; randomize (R); toggle shadows (S); hover the
  preview to see which part and (role, shade) a pixel is; "Export art" re-reads
  the `.ase` files, so you can keep the art program open; save, load and delete
  presets (`data/portrait_presets.cfg`); bake a PNG (`portraits/baked/`).
- **Tests:** the `portraits` suite, which also fails if the exported parts are
  out of date with the art.

Not built yet: head anchors, animation frames, mirroring, race and faction pools,
showing portraits in game.

**Size.** Nothing assumes 96x80. The size is the art's canvas, recorded by the
export (`index.cfg` `[canvas]`) and read as `Portraits.SIZE`; the editor sizes
itself from it. To change it, resize every `.ase` canvas (anchor the parts where
they should stay, the exporter refuses mixed sizes) and export again. Recipes
don't change; offsets are relative.

## Pipeline

Parts are drawn in `.ase` files (the source of truth). An offline tool turns them
into runtime files plus a manifest. The game reads only the exported files.

```
art/portraits/*.ase  --tools/export_portraits.gd-->  portraits/parts/<slot>/<variant>[_<piece>].png
                                                      portraits/parts/index.cfg  (where each part goes)
data/portraits.cfg (stack, roles and keys, slot settings), portrait_ramps.cfg, portrait_presets.cfg
```

The tool reads `.ase` directly (the format is simple: zlib-compressed cels), so
it needs neither Aseprite's CLI nor LibreSprite's.

### Where the parts live: options

| Option | Pros | Cons |
|---|---|---|
| A. One `.ase` per slot, variants as layers, animation as frames | Each part is drawn in context over a reference head; frames are built in; few files | Godot can't load `.ase`; binary, so git diffs say nothing; variant names live in layer names |
| B. One PNG per part | Godot loads them natively; adding a part = adding a file; easy to review | Drawing loses context unless done elsewhere; hundreds of files; offsets and anchors still need a manifest |
| C. One sheet per slot (grid) | One texture per slot; frames fit as rows | Every cell is as big as the biggest part; reordering the grid is painful; still needs a manifest |

**Chosen: draw in A, ship as B.** The exported PNGs are generated, so their
number doesn't matter, and the manifest holds what files can't (anchors, offset
ranges, frames). The `.ase` files move from `gitignore/` to a tracked
`art/portraits/`.

Layer naming (works without layer groups, which LibreSprite lacks):
`slot/variant`, with an optional `:piece` for extra pieces:

| Name | Meaning |
|---|---|
| `eyes/narrow` | The `narrow` variant of the `eyes` slot |
| `hair/spiky:back` | Back piece, drawn behind the head |
| `hair/spiky:shadow` | Hand-drawn shadow (see Shadows) |
| `hat/hood:mask` | Erases what's under it (see Masks) |
| `_ref`, `_bg` (leading `_`) | Ignored: references, backgrounds |

### Exported files

Each part is a PNG trimmed to its pixels, still in key colors (below), so it
stays viewable. The manifest gives its position on the canvas, its slot and its
pieces. The exporter **fails on any pixel that isn't a key color** and names the
layer and position. A near-miss like `#715858` for `#705858` is invisible while
drawing but would come out unpainted.

## Colors

Every pixel is a **(ramp role, shade)** pair, not a color. Parts are drawn in
fixed key colors, one key ramp per role. Each ramp has 4 shades, darkest first,
plus one outline color (`#222034`) that's never recolored.

| Role | Covers |
|---|---|
| `skin` | Face, neck, ears, hands |
| `iris_l`, `iris_r` | Each iris (drawn with one key; the eye's side picks the role) |
| `sclera_l`, `sclera_r` | Each eye's white (black sclerae, glowing eyes...) |
| `hair` | Hair, brows, beard (a separate `facial_hair` role if they should differ) |
| `cloth1`..`cloth3` | Clothing pieces, by part |
| `trim1`, `trim2` | Metal, embroidery, buttons |
| `accent` | Jewelry, feathers, gems, war paint |

The keys used in the test (from the monk):

| Role | Shade 0 | 1 | 2 | 3 |
|---|---|---|---|---|
| skin | `#705858` | `#c87038` | `#f0a058` | `#f8e3bb` |
| iris | `#305098` | `#2068d8` | `#4888f8` | `#98d0e0` |
| sclera | — | — | `#9badb7` | `#f0f8f8` |
| hair | `#584160` | `#787860` | `#a0b068` | `#c0d858` |
| cloth1 | `#485078` | `#586098` | `#6880c0` | `#90a8e0` |
| cloth2 | `#696f96` | `#a0b8d8` | `#d0e0f0` | `#f8f8f8` |
| trim | — | `#c0b888` | `#f8d848` | — |
| cloth3 | — | `#606838` | `#789838` | — |

Ramps to paint with live in `data/portraits.cfg`, by role (`skin`: peach, tan,
brown, dark, ashen...). A recipe picks one per role. The eye roles default to the
shared `iris`/`sclera` pick, so heterochromia is a one-line override.

Composition works on (role, shade) pairs, and the colors are looked up at the
very end. That's what makes shadows and masks work on any palette.

## Shadows and highlights

A shadow has **no color**: each of its pixels darkens whatever is under it by one
shade, within that pixel's own ramp. A hair shadow on the forehead becomes darker
skin; on a brow, darker hair; on an iris, darker iris, whatever ramps were picked.
Rules:

- It only touches pixels that already exist, so it never spills past the head.
- Outlines don't change, and shade 0 stays at 0.
- It only affects parts stacked under its caster (a hat's shadow falls on hair
  and face, never on the hat).

Two kinds:

- **Cast** (automatic): the part's own outline, offset by the light direction
  (the test used 1 right, 2 down). Every hair and hat gets one for free. The
  manifest can turn it off or change the offset per part.
- **Drawn** (`:shadow` piece): any opaque pixel in it is shadow, whatever its
  color. For shapes a cast shadow can't fake, like a hat brim's band.

A `:light` piece does the same thing one shade lighter (rim light, a glint).

An effect piece only moves shades within a ramp, so a shadow can't reach a
darker color than shade 0. If shadows on dark ramps look flat, ramps could get a
fifth, shadow-only shade.

## Masks

A `:mask` piece erases the pixels under it that belong to the slots it names.
Its main use is a hat removing the top of the hair, so each hair doesn't need a
version that fits under each hat. Ears2 in the test is an example of what masks
and stacking replace: hair is painted into the ear's art, which breaks when the
hair changes.

## Stacking

Back to front (`data/portraits.cfg` `[stack]`). A slot can have pieces at more
than one depth:

1. `hair:back`, `cape:back`
2. `head` (face shape), `neck`
3. `clothes:back` (what the chin covers: the collar, the body of the outfit)
4. `jaw`
5. `clothes` (what goes over the chin's level: shawls, high collars' fronts)
6. `nose`, `mouth` (over every jaw)
7. `marks` (scars, freckles, paint), under the eyes
8. `eyes`, then `brows` over them
9. `facial_hair`
10. `hair` (front)
11. `ears`, over the hair (hair is drawn around them, not over them)
12. `hat`, `accessory` (glasses, eyepatch, circlet)

The `.ase` files should keep their layers in this order too, so the art program
previews what the game makes (the exporter doesn't care).

## Offsets

- **Anchors.** Each head variant gives anchor points in the manifest (eye
  line, nose, mouth, ears, hat). Features are placed relative to their anchor,
  so a longer head carries its features down with it.
- **Jitter.** Each slot has a range a recipe can pick from, e.g. eyes `dy -2..+1`
  and `spacing -1..+2`. Spacing moves the two eyes in opposite directions, so
  **each eye is its own part** (`eye_l`, `eye_r`, usually mirrored art). An
  odd-eyed character can use two different variants.
- **Parents.** A slot can follow another one's offset: brows follow their eye,
  facial hair follows the jaw.
- **Features carry no skin patch.** The test's Eyes and Brows layers include a
  rectangle of face around them. Moved, it misaligns with the head's shading.
  Only the feature itself and its shading lines go in the part (the test
  stripped the lightest skin shade from them, and that was enough).

## Animation

Animated slots (eyes, mouth) are drawn as `.ase` frames with names in the
manifest: eyes `open, half, closed`, mouth `closed, half, open`. Every frame of a
part has the same canvas position. Since shadows have to land on each frame, the
composer bakes every combination (3 eyes x 3 mouths = 9 small images per
portrait), and the dialogue box picks frames: blinking on a timer, the mouth
moving while text types.

## Runtime and presets

One composer class (`scripts/portrait.gd`) takes a **recipe** and returns
textures:

```
{"parts": {"head": "oval", "eyes": "narrow", "hair": "spiky", ...},
 "ramps": {"skin": "tan", "hair": "black", "iris": "brown", "iris_r": "green", ...},
 "offsets": {"eyes": [0, -1], "eyes_spacing": 1, "mouth": [0, 1]}}
```

- **Generics:** the recipe is rolled from a seed and saved with the unit. Pools
  come from the unit's race (skin, hair and eye ramps, ears: `docs/races.md`)
  and faction (cloth colors).
- **Named characters:** a recipe in a data file. The offline tool is mainly a
  preview where you pick parts, ramps and offsets and see the result. It can also
  bake a PNG for a character who needs hand-drawn touches, and a baked PNG takes
  priority over the recipe.

Composition is a few thousand pixel lookups per layer at 90x90, so it runs on the
CPU once when a portrait is first needed, then caches. A palette shader is the
alternative if that ever matters.

## Open questions

- **Size on screen.** The art is 96x80; the dialogue box's slot is 44x44. FE
  shows the full mugshot in dialogue and a 32x32 crop in menus, so the box needs
  room, and each crop could be a rect in data.
- **Ramp length.** 4 shades fits the monk. Do any parts want 5?
- **Flipping.** Portraits facing right (dialogue's right slot) by mirroring:
  this needs mirrored offsets, and asymmetric parts (a scar, an eyepatch) stay
  mirrored.
- **Named characters:** recipes only, or mostly baked PNGs with hand edits?
