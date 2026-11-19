# Neo characters — procedural build scripts (v5)

All scripts run inside Blender through the BlenderMCP addon socket:

    python3 bl.py <script.py>

## Build order

| Step | Script | What it does |
|------|--------|--------------|
| 1 | `s0_scene.py`, `s0_lights.py` | Stage, backdrop, lights |
| 2 | `s1_nix.py`, `s2_yoru.py`, `s3_akemi.py` | Base characters (collections, roots, cores) |
| 3 | `p1_nix.py`, `p2_yoru.py`, `p3_akemi.py` | Faces, accessories, scarf, tentacles (their hair is superseded by step 4) |
| 4 | `h1_nix.py`, `h2_yoru.py`, `h3_akemi.py` | **v5 hairstyles** (replace every `*_Hair*` object), ears, ring, flowers, eyes, visor, antenna |
| 5 | `s10_light.py` | Lighting and colour management (Standard / Medium High Contrast) |
| 6 | `s11_present.py` | Presentation camera matched to the target, characters turned to face it, stage |
| 7 | `s12_final.py` | Beauty render, inspection sheet, clay sheet, saves `Neo_Characters.blend` |

`p4_volume.py` (v3/v4 under-volume) is no longer needed: the v5 hair scripts build their own base mass.

## v5 hair system (`lib3.py`)

- `Envelope` — designed hair volume over the head sphere: thickness field + hairline.
  `ellipsoid_thick` gives an off-centre "wig" silhouette.
- `hair_base` — continuous sculpted mass filling the envelope (grooves along the flow from the whorl,
  pointed tips at the lower edge). Guarantees there are no bald spots from any angle.
- `slock` — one sculpted lock: flat leaf section with crisp edges, soft crest, optional crease lines,
  width / thickness profiles, and a `face` bias that shingles side locks toward the viewer.
  Control points are either `(az, el, h)` (height above the envelope) or free `Vector`s.
- In `h1/h2/h3`, `P(X, Y, r)` places a control point from a pixel of the 2x target crop plus its distance
  from the head centre — the front locks were authored directly on the target image.
- `cone_ear`, `flower` — accessory helpers.

## Editing

Every lock is its own object (`<Char>_Hair_<P|S|T>_<Name>_<nn>`: primary / secondary / detail) with a
Subdivision modifier, parented to `<Char>_Root` inside `<Char>_Hair`. Change a lock by editing its line in the
`h*.py` script and re-running it (the script purges and rebuilds only that character's hair), or sculpt the
object directly in Blender.

`cmp5.py` renders one character next to its target crop (`tgt5/`), `clay1.py` renders neutral clay views.
